from django.utils import timezone
from django.db.models import Q
from rest_framework import generics, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import IsDoctor, IsDoctorOrPatient, IsPatient
from payments.models import Payment
from .models import (
    Consultation,
    ConsultationSession,
    MedicalDocument,
    Prescription,
)
from .serializers import (
    ConsultationSerializer,
    ConsultationSessionSerializer,
    MedicalDocumentSerializer,
    PrescriptionSerializer,
)

class ConsultationListCreateView(generics.ListCreateAPIView):
    """
    Patient apni consultations dekh sakta hai.
    Doctor apne patients ki consultations dekh/create kar sakta hai.
    """

    serializer_class = ConsultationSerializer
    permission_classes = [IsAuthenticated, IsDoctorOrPatient]

    def get_queryset(self):
        user = self.request.user

        queryset = Consultation.objects.select_related(
            "appointment",
            "appointment__patient",
            "appointment__doctor_clinic",
            "appointment__doctor_clinic__doctor",
            "appointment__doctor_clinic__doctor__user",
            "appointment__doctor_clinic__clinic",
            "created_by",
        ).prefetch_related(
            "prescription__medicines"
        )

        if user.is_superuser:
            return queryset

        return queryset.filter(
            Q(appointment__patient=user)
            | Q(
                appointment__doctor_clinic__doctor__user=user
            )
        ).distinct()

    def perform_create(self, serializer):
        """
        Patient consultation report create nahi kar sakta.
        """
        appointment = serializer.validated_data["appointment"]
        doctor_user = appointment.doctor_clinic.doctor.user

        if (
            not self.request.user.is_superuser
            and doctor_user != self.request.user
        ):
            raise PermissionDenied(
                "Sirf appointment wala doctor consultation bana sakta hai."
            )

        serializer.save(created_by=self.request.user)


class ConsultationDetailView(generics.RetrieveAPIView):
    """
    Consultation ki complete detail.
    """

    serializer_class = ConsultationSerializer
    permission_classes = [IsAuthenticated, IsDoctorOrPatient]

    def get_queryset(self):
        user = self.request.user

        queryset = Consultation.objects.select_related(
            "appointment",
            "appointment__patient",
            "appointment__doctor_clinic",
            "appointment__doctor_clinic__doctor",
            "appointment__doctor_clinic__doctor__user",
            "appointment__doctor_clinic__clinic",
            "created_by",
        ).prefetch_related(
            "prescription__medicines"
        )

        if user.is_superuser:
            return queryset

        return queryset.filter(
            Q(appointment__patient=user)
            | Q(
                appointment__doctor_clinic__doctor__user=user
            )
        ).distinct()


class PrescriptionListCreateView(generics.ListCreateAPIView):
    """
    Doctor prescription create karega.
    Patient apni prescriptions dekh sakta hai.
    """

    serializer_class = PrescriptionSerializer
    permission_classes = [IsAuthenticated, IsDoctorOrPatient]

    def get_queryset(self):
        user = self.request.user

        queryset = Prescription.objects.select_related(
            "consultation",
            "consultation__appointment",
            "consultation__appointment__patient",
            "consultation__appointment__doctor_clinic",
            "consultation__appointment__doctor_clinic__doctor",
            "consultation__appointment__doctor_clinic__doctor__specialty",
            "consultation__appointment__doctor_clinic__doctor__user",
            "consultation__appointment__doctor_clinic__clinic",
        ).prefetch_related("medicines")

        if user.is_superuser:
            return queryset

        return queryset.filter(
    Q(consultation__appointment__patient=user)
    | Q(
        consultation__appointment__doctor_clinic__doctor__user=user
    )
).distinct()

class PrescriptionDetailView(generics.RetrieveAPIView):
    """
    Aik prescription aur uski medicines ki detail.
    """

    serializer_class = PrescriptionSerializer
    permission_classes = [IsAuthenticated, IsDoctorOrPatient]

    def get_queryset(self):
        user = self.request.user

        queryset = Prescription.objects.select_related(
            "consultation",
            "consultation__appointment",
            "consultation__appointment__patient",
            "consultation__appointment__doctor_clinic",
            "consultation__appointment__doctor_clinic__doctor",
            "consultation__appointment__doctor_clinic__doctor__specialty",
            "consultation__appointment__doctor_clinic__doctor__user",
            "consultation__appointment__doctor_clinic__clinic",
        ).prefetch_related("medicines")

        if user.is_superuser:
            return queryset

        return queryset.filter(
    Q(consultation__appointment__patient=user)
    | Q(
        consultation__appointment__doctor_clinic__doctor__user=user
    )
).distinct()

class ConsultationSessionListCreateView(
    generics.ListCreateAPIView
):
    """
    Doctor session create karega.
    Doctor aur patient apne sessions dekh sakte hain.
    """

    serializer_class = ConsultationSessionSerializer
    permission_classes = [IsAuthenticated, IsDoctorOrPatient]

    def get_queryset(self):
        user = self.request.user

        queryset = ConsultationSession.objects.select_related(
            "appointment",
            "appointment__patient",
            "appointment__doctor_clinic",
            "appointment__doctor_clinic__doctor",
            "appointment__doctor_clinic__doctor__user",
            "appointment__doctor_clinic__clinic",
        )

        if not user.is_superuser:
            queryset = queryset.filter(
                Q(appointment__patient=user)
                | Q(appointment__doctor_clinic__doctor__user=user)
            ).distinct()

        # Flutter can request one appointment's session directly with:
        # /api/consultations/sessions/?appointment=<appointment_id>
        appointment_id = self.request.query_params.get("appointment")
        if appointment_id:
            queryset = queryset.filter(appointment_id=appointment_id)

        return queryset


class ConsultationSessionJoinView(APIView):
    """
    Patient ya doctor online consultation join karega.

    Online consultation join karne se pehle payment verified
    hona zaroori hai.
    """

    permission_classes = [IsAuthenticated, IsDoctorOrPatient]

    def post(self, request, pk):
        try:
            session = ConsultationSession.objects.select_related(
                "appointment",
                "appointment__patient",
                "appointment__doctor_clinic__doctor__user",
            ).get(pk=pk)
        except ConsultationSession.DoesNotExist:
            return Response(
                {"detail": "Consultation session was not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        appointment = session.appointment
        patient_user = appointment.patient
        doctor_user = appointment.doctor_clinic.doctor.user

        if (
            not request.user.is_superuser
            and request.user not in (patient_user, doctor_user)
        ):
            return Response(
                {"detail": "You do not have permission to join this session."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Verified payment check.
        if not request.user.is_superuser:
            payment_verified = Payment.objects.filter(
                appointment=appointment,
                status=Payment.PaymentStatus.VERIFIED,
            ).exists()

            if not payment_verified:
                return Response(
                    {
                        "detail": (
                            "Payment must be verified before joining "
                            "the online consultation."
                        )
                    },
                    status=status.HTTP_402_PAYMENT_REQUIRED,
                )

        if session.status in (
            ConsultationSession.SessionStatus.ENDED,
            ConsultationSession.SessionStatus.CANCELLED,
        ):
            return Response(
                {"detail": "This consultation session is already closed."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        current_time = timezone.now()

        if request.user == patient_user:
            session.patient_joined_at = current_time

        if request.user == doctor_user or request.user.is_superuser:
            session.doctor_joined_at = current_time

        # Dono join kar chuke hon to session active ho jayega.
        if session.patient_joined_at and session.doctor_joined_at:
            session.status = ConsultationSession.SessionStatus.ACTIVE

            if not session.started_at:
                session.started_at = current_time
        else:
            session.status = ConsultationSession.SessionStatus.WAITING

        session.save(
            update_fields=[
                "patient_joined_at",
                "doctor_joined_at",
                "status",
                "started_at",
                "updated_at",
            ]
        )

        return Response(
            {
                "message": "Consultation session joined successfully.",
                "session": ConsultationSessionSerializer(session).data,
            },
            status=status.HTTP_200_OK,
        )


class ConsultationSessionEndView(APIView):
    """
    Sirf doctor online consultation end kar sakta hai.
    """

    permission_classes = [IsAuthenticated, IsDoctor]

    def post(self, request, pk):
        try:
            session = ConsultationSession.objects.select_related(
                "appointment__doctor_clinic__doctor__user"
            ).get(pk=pk)
        except ConsultationSession.DoesNotExist:
            return Response(
                {"detail": "Consultation session was not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        doctor_user = (
            session.appointment.doctor_clinic.doctor.user
        )

        if (
            not request.user.is_superuser
            and request.user != doctor_user
        ):
            return Response(
                {"detail": "Only the assigned doctor can end this session."},
                status=status.HTTP_403_FORBIDDEN,
            )

        if session.status == ConsultationSession.SessionStatus.ENDED:
            return Response(
                {"detail": "This session has already ended."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        session.status = ConsultationSession.SessionStatus.ENDED
        session.ended_at = timezone.now()
        session.save(
            update_fields=[
                "status",
                "ended_at",
                "updated_at",
            ]
        )

        return Response(
            {
                "message": "Consultation session ended successfully.",
                "session": ConsultationSessionSerializer(session).data,
            },
            status=status.HTTP_200_OK,
        )

class MedicalDocumentListCreateView(
    generics.ListCreateAPIView
):
    """
    Patient document upload karega.

    Patient apne documents dekh sakta hai.
    Doctor sirf apni linked appointments ke documents dekh sakta hai.
    """

    serializer_class = MedicalDocumentSerializer
    permission_classes = [IsAuthenticated, IsDoctorOrPatient]

    def get_permissions(self):
        if self.request.method == "POST":
            return [IsAuthenticated(), IsPatient()]
        return [IsAuthenticated(), IsDoctorOrPatient()]

    parser_classes = [
        MultiPartParser,
        FormParser,
        JSONParser,
    ]

    def get_queryset(self):
        user = self.request.user

        queryset = MedicalDocument.objects.select_related(
            "patient",
            "appointment",
            "appointment__doctor_clinic",
            "appointment__doctor_clinic__doctor",
            "appointment__doctor_clinic__doctor__user",
            "uploaded_by",
        )

        if user.is_superuser:
            return queryset

        return queryset.filter(
            Q(patient=user)
            | Q(
                appointment__doctor_clinic__doctor__user=user
            )
        ).distinct()

    def perform_create(self, serializer):
        """
        Patient aur uploader automatically logged-in user honge.
        """
        serializer.save(
            patient=self.request.user,
            uploaded_by=self.request.user,
        )


class MedicalDocumentDetailView(
    generics.RetrieveDestroyAPIView
):
    """
    Patient document detail dekh/delete kar sakta hai.

    Assigned doctor document dekh sakta hai lekin delete nahi.
    """

    serializer_class = MedicalDocumentSerializer
    permission_classes = [IsAuthenticated, IsDoctorOrPatient]

    def get_queryset(self):
        user = self.request.user

        queryset = MedicalDocument.objects.select_related(
            "patient",
            "appointment",
            "appointment__doctor_clinic",
            "appointment__doctor_clinic__doctor",
            "appointment__doctor_clinic__doctor__user",
            "uploaded_by",
        )

        if user.is_superuser:
            return queryset

        return queryset.filter(
            Q(patient=user)
            | Q(
                appointment__doctor_clinic__doctor__user=user
            )
        ).distinct()

    def perform_destroy(self, instance):
        """
        Sirf document ka patient ya superuser delete kar sakta hai.
        """
        if (
            not self.request.user.is_superuser
            and instance.patient != self.request.user
        ):
            raise PermissionDenied(
                "Doctor patient ka medical document delete nahi kar sakta."
            )

        instance.delete()
