from django.utils import timezone

from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from appointments.models import Appointment
from consultations.models import (
    Consultation,
    ConsultationSession,
    MedicalDocument,
    Prescription,
)
from core.permissions import IsDoctor, IsPatient
from notifications.models import Notification
from payments.models import Payment


class PatientDashboardView(APIView):
    """
    Return dashboard summary for the logged-in patient.
    """

    permission_classes = [
        IsAuthenticated,
        IsPatient,
    ]

    def get(self, request):
        user = request.user
        today = timezone.localdate()

        appointments = Appointment.objects.filter(
            patient=user,
        )

        upcoming_appointments = appointments.filter(
            appointment_date__gte=today,
        ).exclude(
            status__in=["cancelled", "completed"],
        )

        recent_appointments = appointments.select_related(
            "doctor_clinic",
            "doctor_clinic__doctor",
            "doctor_clinic__doctor__user",
            "doctor_clinic__clinic",
        ).order_by(
            "-appointment_date",
            "-appointment_time",
        )[:5]

        recent_data = []

        for appointment in recent_appointments:
            doctor_user = appointment.doctor_clinic.doctor.user

            doctor_name = (
                doctor_user.get_full_name()
                or doctor_user.username
            )

            recent_data.append({
                "id": appointment.id,
                "doctor_name": doctor_name,
                "clinic_name": (
                    appointment.doctor_clinic.clinic.name
                ),
                "appointment_date": (
                    appointment.appointment_date
                ),
                "appointment_time": (
                    appointment.appointment_time
                ),
                "consultation_mode": (
                    appointment.consultation_mode
                ),
                "token_number": appointment.token_number,
                "status": appointment.status,
            })

        verified_payments = Payment.objects.filter(
            appointment__patient=user,
            status=Payment.PaymentStatus.VERIFIED,
        ).count()

        pending_payments = Payment.objects.filter(
            appointment__patient=user,
            status__in=[
                Payment.PaymentStatus.PENDING,
                Payment.PaymentStatus.SUBMITTED,
            ],
        ).count()

        total_prescriptions = Prescription.objects.filter(
            consultation__appointment__patient=user,
        ).count()

        total_medical_documents = MedicalDocument.objects.filter(
            patient=user,
        ).count()

        unread_notifications = Notification.objects.filter(
            user=user,
            is_read=False,
        ).count()

        statistics = {
            "total_appointments": appointments.count(),

            "upcoming_appointments": (
                upcoming_appointments.count()
            ),

            "completed_appointments": appointments.filter(
                status="completed",
            ).count(),

            "cancelled_appointments": appointments.filter(
                status="cancelled",
            ).count(),

            "verified_payments": verified_payments,

            "pending_payments": pending_payments,

            "prescriptions": total_prescriptions,

            "medical_documents": total_medical_documents,

            "unread_notifications": unread_notifications,
        }

        return Response({
            "success": True,
            "user": {
                "id": user.id,
                "username": user.username,
                "full_name": user.get_full_name(),
                "email": user.email,
            },
            "statistics": statistics,
            "recent_appointments": recent_data,
        })


class DoctorDashboardView(APIView):
    """
    Return dashboard summary for the logged-in verified doctor.
    """

    permission_classes = [
        IsAuthenticated,
        IsDoctor,
    ]

    def get(self, request):
        user = request.user
        today = timezone.localdate()

        appointments = Appointment.objects.filter(
            doctor_clinic__doctor__user=user,
        )

        today_appointments = appointments.filter(
            appointment_date=today,
        )

        upcoming_appointments = appointments.filter(
            appointment_date__gte=today,
        ).exclude(
            status__in=["cancelled", "completed"],
        )

        upcoming_patient_appointments = (
            appointments
            .filter(appointment_date__gte=today)
            .exclude(status="cancelled")
            .select_related(
                "patient",
                "doctor_clinic",
                "doctor_clinic__clinic",
            )
            .order_by(
                "appointment_date",
                "appointment_time",
            )[:10]
        )

        appointment_data = []

        for appointment in upcoming_patient_appointments:
            patient = appointment.patient

            patient_name = (
                patient.get_full_name()
                or patient.username
            )

            appointment_data.append({
                "id": appointment.id,
                "patient_name": patient_name,
                "clinic_name": (
                    appointment.doctor_clinic.clinic.name
                ),
                "appointment_date": (
                    appointment.appointment_date
                ),
                "appointment_time": (
                    appointment.appointment_time
                ),
                "consultation_mode": (
                    appointment.consultation_mode
                ),
                "token_number": appointment.token_number,
                "status": appointment.status,
            })

        total_consultations = Consultation.objects.filter(
            appointment__doctor_clinic__doctor__user=user,
        ).count()

        total_prescriptions = Prescription.objects.filter(
            consultation__appointment__doctor_clinic__doctor__user=user,
        ).count()

        active_sessions = ConsultationSession.objects.filter(
            appointment__doctor_clinic__doctor__user=user,
            status=ConsultationSession.SessionStatus.ACTIVE,
        ).count()

        unread_notifications = Notification.objects.filter(
            user=user,
            is_read=False,
        ).count()

        statistics = {
            "total_appointments": appointments.count(),

            "today_appointments": today_appointments.count(),

            "upcoming_appointments": (
                upcoming_appointments.count()
            ),

            "completed_appointments": appointments.filter(
                status="completed",
            ).count(),

            "cancelled_appointments": appointments.filter(
                status="cancelled",
            ).count(),

            "consultations_completed": total_consultations,

            "prescriptions_created": total_prescriptions,

            "active_sessions": active_sessions,

            "unread_notifications": unread_notifications,
        }

        return Response({
            "success": True,
            "doctor": {
                "id": user.id,
                "username": user.username,
                "full_name": user.get_full_name(),
                "email": user.email,
            },
            "statistics": statistics,
            "upcoming_patient_appointments": appointment_data,
        })