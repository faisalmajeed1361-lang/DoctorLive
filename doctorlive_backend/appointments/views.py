from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import IsPatient
from notifications.models import Notification
from .models import Appointment, DoctorAvailabilitySlot
from .serializers import AppointmentSerializer, DoctorAvailabilitySlotSerializer


class AppointmentListCreateView(
    generics.ListCreateAPIView
):
    """
    GET: Patient ki appointments
    POST: New appointment booking
    """

    permission_classes = [permissions.IsAuthenticated]

    serializer_class = AppointmentSerializer

    def get_queryset(self):
        user = self.request.user

        queryset = Appointment.objects.select_related(
            "patient",
            "doctor_clinic__doctor__specialty",
            "doctor_clinic__clinic",
        )

        # Admin tamam appointments dekh sakta hai
        if user.is_staff:
            return queryset

        # Doctor ko apni appointments nazar aayengi
        if hasattr(user, "doctor_profile"):
            return queryset.filter(
                doctor_clinic__doctor__user=user
            )

        # Patient ko sirf apni appointments nazar aayengi
        return queryset.filter(
            patient=user
        )


class AppointmentDetailView(
    generics.RetrieveAPIView
):
    """
    Single appointment ki details.
    """

    permission_classes = [
        permissions.IsAuthenticated,
    ]

    serializer_class = AppointmentSerializer

    def get_queryset(self):
        user = self.request.user

        queryset = Appointment.objects.select_related(
            "patient",
            "doctor_clinic__doctor__specialty",
            "doctor_clinic__clinic",
        )

        if user.is_staff:
            return queryset

        if hasattr(user, "doctor_profile"):
            return queryset.filter(
                doctor_clinic__doctor__user=user
            )

        return queryset.filter(
            patient=user
        )


class CancelAppointmentView(APIView):
    """
    Patient apni booked appointment cancel kar sakta hai.
    """

    permission_classes = [permissions.IsAuthenticated, IsPatient]

    def post(self, request, pk):
        try:
            appointment = Appointment.objects.get(
                pk=pk,
                patient=request.user,
            )

        except Appointment.DoesNotExist:
            return Response(
                {
                    "error": "Appointment not found."
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if appointment.status not in [
            Appointment.AppointmentStatus.BOOKED,
            Appointment.AppointmentStatus.CHECKED_IN,
        ]:
            return Response(
                {
                    "error": (
                        "This appointment cannot be cancelled."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        appointment.status = (
            Appointment.AppointmentStatus.CANCELLED
        )

        appointment.cancellation_reason = (
            request.data.get(
                "cancellation_reason",
                "Cancelled by patient.",
            )
        )

        appointment.save(
            update_fields=[
                "status",
                "cancellation_reason",
                "updated_at",
            ]
        )

        return Response(
            {
                "message": (
                    "Appointment cancelled successfully."
                ),
                "appointment": AppointmentSerializer(
                    appointment
                ).data,
            },
            status=status.HTTP_200_OK,
        )

class DoctorAvailabilitySlotListCreateView(
    generics.ListCreateAPIView
):
    """
    GET:
    Patients available slots دیکھ سکتے ہیں۔

    POST:
    Doctor اپنا نیا slot create کر سکتا ہے۔
    """

    serializer_class = DoctorAvailabilitySlotSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = DoctorAvailabilitySlot.objects.select_related(
            "doctor_clinic",
            "doctor_clinic__doctor",
            "doctor_clinic__doctor__user",
            "doctor_clinic__clinic",
            "appointment",
        ).filter(
            is_active=True,
            slot_date__gte=timezone.localdate(),
        )

        doctor_clinic = self.request.query_params.get(
            "doctor_clinic"
        )
        slot_date = self.request.query_params.get("date")
        available = self.request.query_params.get("available")

        if doctor_clinic:
            queryset = queryset.filter(
                doctor_clinic_id=doctor_clinic
            )

        if slot_date:
            queryset = queryset.filter(slot_date=slot_date)

        if available and available.lower() == "true":
            queryset = queryset.filter(appointment__isnull=True)

        return queryset


class BookDoctorSlotView(APIView):
    """
    Patient selected available slot book کرے گا۔

    Database locking double booking روکتی ہے۔
    """

    permission_classes = [permissions.IsAuthenticated, IsPatient]

    @transaction.atomic
    def post(self, request, pk):
        try:
            slot = (
                DoctorAvailabilitySlot.objects
                .select_for_update()
                .select_related(
                    "doctor_clinic",
                    "doctor_clinic__doctor",
                    "doctor_clinic__clinic",
                )
                .get(pk=pk)
            )
        except DoctorAvailabilitySlot.DoesNotExist:
            return Response(
                {"detail": "Doctor slot نہیں ملا۔"},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not slot.is_active:
            return Response(
                {"detail": "یہ slot active نہیں ہے۔"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if slot.appointment_id:
            return Response(
                {"detail": "یہ slot پہلے ہی book ہو چکا ہے۔"},
                status=status.HTTP_409_CONFLICT,
            )

        if slot.slot_date < timezone.localdate():
            return Response(
                {"detail": "Past slot book نہیں ہو سکتا۔"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        consultation_mode = request.data.get(
            "consultation_mode",
            "in_person",
        )

        allowed_modes = ("in_person", "video", "audio")

        if consultation_mode not in allowed_modes:
            return Response(
                {
                    "consultation_mode": (
                        "Mode in_person, video یا audio ہونا چاہیے۔"
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        symptoms = request.data.get(
            "symptoms_summary",
            request.data.get("symptoms", ""),
        ).strip()

        # Appointment model token number automatically generate کرے گا۔
        appointment = Appointment.objects.create(
            patient=request.user,
            doctor_clinic=slot.doctor_clinic,
            appointment_date=slot.slot_date,
            appointment_time=slot.start_time,
            consultation_mode=consultation_mode,
            symptoms_summary=symptoms,
        )

        patient_name = (
            request.user.get_full_name() or request.user.username
        )
        doctor = slot.doctor_clinic.doctor
        date_text = appointment.appointment_date.strftime("%d/%m/%Y")
        time_text = appointment.appointment_time.strftime("%H:%M")

        # Slot booking par patient ko confirmation notification dega.
        Notification.objects.create(
            user=request.user,
            notification_type=(
                Notification.NotificationType.APPOINTMENT_BOOKED
            ),
            title="Appointment Booked",
            message=(
                f"Your appointment with Dr. {doctor.full_name} "
                f"is booked for {date_text} at {time_text}. "
                f"Token number: {appointment.token_number}."
            ),
            appointment=appointment,
        )

        # Slot booking par doctor ko new appointment notification dega.
        Notification.objects.create(
            user=doctor.user,
            notification_type=(
                Notification.NotificationType.APPOINTMENT_BOOKED
            ),
            title="New Appointment Received",
            message=(
                f"{patient_name} booked an appointment for "
                f"{date_text} at {time_text}. "
                f"Token number: {appointment.token_number}."
            ),
            appointment=appointment,
        )

        slot.appointment = appointment
        slot.save(
            update_fields=[
                "appointment",
                "updated_at",
            ]
        )

        return Response(
            {
                "message": "Appointment slot successfully booked.",
                "appointment": {
                    "id": appointment.id,
                    "token_number": appointment.token_number,
                    "doctor": str(slot.doctor_clinic.doctor),
                    "clinic": slot.doctor_clinic.clinic.name,
                    "appointment_date": appointment.appointment_date,
                    "appointment_time": appointment.appointment_time,
                    "consultation_mode": (
                        appointment.consultation_mode
                    ),
                    "status": appointment.status,
                },
            },
            status=status.HTTP_201_CREATED,
        )

class AppointmentRescheduleView(APIView):
    """
    Patient apni appointment ko same doctor ke new available
    slot par reschedule kar sakta hai.
    """

    permission_classes = [permissions.IsAuthenticated, IsPatient]

    @transaction.atomic
    def post(self, request, pk):
        try:
            appointment = (
                Appointment.objects
                .select_for_update()
                .select_related(
                    "patient",
                    "doctor_clinic",
                    "doctor_clinic__doctor",
                    "doctor_clinic__doctor__user",
                    "doctor_clinic__clinic",
                )
                .get(pk=pk)
            )
        except Appointment.DoesNotExist:
            return Response(
                {"detail": "Appointment nahi mili."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Only patient or superuser can reschedule.
        if (
            not request.user.is_superuser
            and appointment.patient != request.user
        ):
            return Response(
                {
                    "detail": (
                        "Aap sirf apni appointment reschedule "
                        "kar sakte hain."
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        if appointment.status in ("cancelled", "completed"):
            return Response(
                {
                    "detail": (
                        "Cancelled ya completed appointment "
                        "reschedule nahi ho sakti."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        new_slot_id = request.data.get("new_slot_id")

        if not new_slot_id:
            return Response(
                {"new_slot_id": "New slot ID required hai."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            new_slot = (
                DoctorAvailabilitySlot.objects
                .select_for_update()
                .select_related("doctor_clinic")
                .get(pk=new_slot_id)
            )
        except DoctorAvailabilitySlot.DoesNotExist:
            return Response(
                {"detail": "Selected slot nahi mila."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not new_slot.is_active:
            return Response(
                {"detail": "Selected slot active nahi hai."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if new_slot.appointment_id:
            return Response(
                {"detail": "Selected slot already booked hai."},
                status=status.HTTP_409_CONFLICT,
            )

        if new_slot.slot_date < timezone.localdate():
            return Response(
                {"detail": "Past slot select nahi kar sakte."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Rescheduling only with the same doctor and clinic.
        if (
            new_slot.doctor_clinic_id
            != appointment.doctor_clinic_id
        ):
            return Response(
                {
                    "detail": (
                        "Reschedule ke liye same doctor aur clinic "
                        "ka slot select karo."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        old_slot = (
            DoctorAvailabilitySlot.objects
            .select_for_update()
            .filter(appointment=appointment)
            .first()
        )

        # Release old booked slot.
        if old_slot:
            old_slot.appointment = None
            old_slot.save(
                update_fields=[
                    "appointment",
                    "updated_at",
                ]
            )

        # Update appointment date and time.
        appointment.appointment_date = new_slot.slot_date
        appointment.appointment_time = new_slot.start_time
        appointment.status = "booked"

        appointment.save(
            update_fields=[
                "appointment_date",
                "appointment_time",
                "status",
                "updated_at",
            ]
        )

        # Book the new slot.
        new_slot.appointment = appointment
        new_slot.save(
            update_fields=[
                "appointment",
                "updated_at",
            ]
        )

        return Response(
            {
                "message": "Appointment successfully rescheduled.",
                "appointment": {
                    "id": appointment.id,
                    "token_number": appointment.token_number,
                    "appointment_date": (
                        appointment.appointment_date
                    ),
                    "appointment_time": (
                        appointment.appointment_time
                    ),
                    "status": appointment.status,
                    "new_slot_id": new_slot.id,
                },
            },
            status=status.HTTP_200_OK,
        )

# Add this import near the top of appointments/views.py:
# from django.db import transaction


class DoctorAppointmentStatusView(APIView):
    """
    Doctor apni appointment ko controlled workflow mein update karega.

    Valid flow:
    booked -> checked_in -> in_consultation -> completed
    booked/checked_in -> no_show
    """

    permission_classes = [permissions.IsAuthenticated]

    # Sirf ye status transitions doctor perform kar sakta hai.
    allowed_transitions = {
        Appointment.AppointmentStatus.BOOKED: {
            Appointment.AppointmentStatus.CHECKED_IN,
            Appointment.AppointmentStatus.NO_SHOW,
        },
        Appointment.AppointmentStatus.CHECKED_IN: {
            Appointment.AppointmentStatus.IN_CONSULTATION,
            Appointment.AppointmentStatus.NO_SHOW,
        },
        Appointment.AppointmentStatus.IN_CONSULTATION: {
            Appointment.AppointmentStatus.COMPLETED,
        },
    }

    @transaction.atomic
    def post(self, request, pk):
        """Selected appointment ka status safely update karega."""

        # Patient ko doctor-only action use karne se rokega.
        if (
            not request.user.is_superuser
            and not hasattr(request.user, "doctor_profile")
        ):
            return Response(
                {"detail": "Only doctors can update appointment status."},
                status=status.HTTP_403_FORBIDDEN,
            )

        queryset = (
            Appointment.objects
            .select_for_update()
            .select_related(
                "patient",
                "doctor_clinic__doctor__user",
                "doctor_clinic__clinic",
            )
        )

        # Normal doctor ko sirf apni appointment access milegi.
        if not request.user.is_superuser:
            queryset = queryset.filter(
                doctor_clinic__doctor__user=request.user,
            )

        try:
            appointment = queryset.get(pk=pk)
        except Appointment.DoesNotExist:
            return Response(
                {"detail": "Appointment not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        requested_status = str(
            request.data.get("status", "")
        ).strip().lower()

        if not requested_status:
            return Response(
                {"status": "New appointment status is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        valid_next_statuses = self.allowed_transitions.get(
            appointment.status,
            set(),
        )

        if requested_status not in valid_next_statuses:
            return Response(
                {
                    "detail": (
                        f"Status cannot change from "
                        f"{appointment.status} to {requested_status}."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        appointment.status = requested_status
        appointment.save(update_fields=["status", "updated_at"])

        return Response(
            {
                "message": "Appointment status updated successfully.",
                "appointment": AppointmentSerializer(appointment).data,
            },
            status=status.HTTP_200_OK,
        )
