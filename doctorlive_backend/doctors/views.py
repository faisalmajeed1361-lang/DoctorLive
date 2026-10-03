from rest_framework import generics, permissions
from .models import (
    ClinicStaff,
    DoctorClinic,
    LiveDoctorStatus,
)
from .models import Clinic, DoctorProfile, LiveDoctorStatus, Specialty
from .serializers import (
    ClinicSerializer,
    DoctorProfileSerializer,
    SpecialtySerializer,
)
from django.db import transaction

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from .serializers import LiveDoctorStatusSerializer

class SpecialtyListView(generics.ListAPIView):
    """
    Tamam active specialties return karega.
    """

    permission_classes = [permissions.AllowAny]
    serializer_class = SpecialtySerializer

    queryset = Specialty.objects.filter(
        is_active=True
    ).order_by("name")


class ClinicListView(generics.ListAPIView):
    """
    Verified clinics return karega.

    Optional filter:
    /api/doctors/clinics/?city=Khanpur
    """

    permission_classes = [permissions.AllowAny]
    serializer_class = ClinicSerializer

    def get_queryset(self):
        queryset = Clinic.objects.filter(
            is_verified=True,
            is_active=True,
        )

        city = self.request.query_params.get(
            "city"
        )

        if city:
            queryset = queryset.filter(
                city__iexact=city
            )

        return queryset.order_by(
            "city",
            "area",
            "name",
        )


class DoctorListView(generics.ListAPIView):
    """
    Verified doctors ki list.

    Available filters:
    city, specialty, available, video
    """

    permission_classes = [permissions.AllowAny]
    serializer_class = DoctorProfileSerializer

    def get_queryset(self):
        queryset = (
            DoctorProfile.objects
            .filter(
                is_verified=True,
                is_active=True,
            )
            .select_related(
                "specialty",
            )
            .prefetch_related(
                "clinic_assignments__clinic",
                "clinic_assignments__live_status",
            )
        )

        city = self.request.query_params.get(
            "city"
        )

        specialty = self.request.query_params.get(
            "specialty"
        )

        available = self.request.query_params.get(
            "available"
        )

        video = self.request.query_params.get(
            "video"
        )

        search = self.request.query_params.get(
            "search"
        )

        if city:
            queryset = queryset.filter(
                clinic_assignments__clinic__city__iexact=city,
                clinic_assignments__clinic__is_verified=True,
            )

        if specialty:
            # Specialty ID ya specialty name dono accept honge
            if specialty.isdigit():
                queryset = queryset.filter(
                    specialty_id=int(specialty)
                )
            else:
                queryset = queryset.filter(
                    specialty__name__icontains=specialty
                )

        if available == "true":
            queryset = queryset.filter(
                clinic_assignments__live_status__status__in=[
                    LiveDoctorStatus.Status.AVAILABLE,
                    LiveDoctorStatus.Status.CONSULTING,
                    LiveDoctorStatus.Status.VIDEO_ONLY,
                ]
            )

        if video == "true":
            queryset = queryset.filter(
                offers_video_consultation=True
            )

        if search:
            queryset = queryset.filter(
                full_name__icontains=search
            )

        return queryset.distinct().order_by(
            "full_name"
        )


class DoctorDetailView(generics.RetrieveAPIView):
    """
    Selected doctor ki complete profile.
    """

    permission_classes = [permissions.AllowAny]
    serializer_class = DoctorProfileSerializer

    queryset = (
        DoctorProfile.objects
        .filter(
            is_verified=True,
            is_active=True,
        )
        .select_related(
            "specialty",
        )
        .prefetch_related(
            "clinic_assignments__clinic",
            "clinic_assignments__live_status",
        )
    )

def can_manage_live_status(user, doctor_clinic):
    """
    Check karega ke user selected doctor-clinic ka live status
    manage kar sakta hai ya nahi.

    Allowed users:
    1. Superuser/admin
    2. Relevant doctor
    3. Selected clinic ka active staff member
    """

    if user.is_superuser:
        return True

    # Selected doctor apna live status manage kar sakta hai.
    if doctor_clinic.doctor.user_id == user.id:
        return True

    # Active clinic staff bhi status/token update kar sakta hai.
    return ClinicStaff.objects.filter(
        user=user,
        clinic=doctor_clinic.clinic,
        is_active=True,
    ).exists()


class LiveDoctorStatusDetailView(APIView):
    """
    GET:
    Patient, doctor aur authenticated user live status dekh sakte hain.

    PATCH:
    Relevant doctor, clinic staff ya admin live status update kar sakta hai.

    URL:
    /api/doctors/live-status/<doctor_clinic_id>/
    """

    permission_classes = [IsAuthenticated]

    def get_doctor_clinic(self, doctor_clinic_id):
        """
        Doctor-clinic relation complete related data ke saath load karega.
        """
        try:
            return DoctorClinic.objects.select_related(
                "doctor",
                "doctor__user",
                "clinic",
            ).get(
                pk=doctor_clinic_id,
                is_active=True,
            )
        except DoctorClinic.DoesNotExist:
            return None

    def get(self, request, doctor_clinic_id):
        doctor_clinic = self.get_doctor_clinic(
            doctor_clinic_id
        )

        if doctor_clinic is None:
            return Response(
                {
                    "detail": (
                        "Active doctor-clinic record nahi mila."
                    )
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        # Status record na ho to default off-duty record create hoga.
        live_status, _ = LiveDoctorStatus.objects.get_or_create(
            doctor_clinic=doctor_clinic,
            defaults={
                "status": LiveDoctorStatus.Status.OFF_DUTY,
                "current_token": 0,
            },
        )

        serializer = LiveDoctorStatusSerializer(
            live_status,
            context={"request": request},
        )

        return Response(
            serializer.data,
            status=status.HTTP_200_OK,
        )

    def patch(self, request, doctor_clinic_id):
        doctor_clinic = self.get_doctor_clinic(
            doctor_clinic_id
        )

        if doctor_clinic is None:
            return Response(
                {
                    "detail": (
                        "Active doctor-clinic record nahi mila."
                    )
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if not can_manage_live_status(
            request.user,
            doctor_clinic,
        ):
            return Response(
                {
                    "detail": (
                        "Aap is doctor ka live status update "
                        "nahi kar sakte."
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        live_status, _ = LiveDoctorStatus.objects.get_or_create(
            doctor_clinic=doctor_clinic,
            defaults={
                "status": LiveDoctorStatus.Status.OFF_DUTY,
                "current_token": 0,
            },
        )

        serializer = LiveDoctorStatusSerializer(
            live_status,
            data=request.data,
            partial=True,
            context={"request": request},
        )

        serializer.is_valid(raise_exception=True)

        serializer.save(
            updated_by=request.user,
        )

        return Response(
            {
                "message": "Doctor live status updated successfully.",
                "live_status": serializer.data,
            },
            status=status.HTTP_200_OK,
        )


class LiveDoctorNextTokenView(APIView):
    """
    Relevant doctor, clinic staff ya admin current token ko
    next token par move karega.

    POST:
    /api/doctors/live-status/<doctor_clinic_id>/next-token/
    """

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, doctor_clinic_id):
        try:
            doctor_clinic = DoctorClinic.objects.select_related(
                "doctor",
                "doctor__user",
                "clinic",
            ).get(
                pk=doctor_clinic_id,
                is_active=True,
            )
        except DoctorClinic.DoesNotExist:
            return Response(
                {
                    "detail": (
                        "Active doctor-clinic record nahi mila."
                    )
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if not can_manage_live_status(
            request.user,
            doctor_clinic,
        ):
            return Response(
                {
                    "detail": (
                        "Aap is doctor ka token update "
                        "nahi kar sakte."
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        live_status, _ = LiveDoctorStatus.objects.get_or_create(
            doctor_clinic=doctor_clinic,
            defaults={
                "status": LiveDoctorStatus.Status.CONSULTING,
                "current_token": 0,
                "updated_by": request.user,
            },
        )

        # Concurrent requests mein duplicate token update rokega.
        live_status = LiveDoctorStatus.objects.select_for_update().get(
            pk=live_status.pk
        )

        live_status.current_token += 1
        live_status.status = (
            LiveDoctorStatus.Status.CONSULTING
        )
        live_status.updated_by = request.user

        live_status.save(
            update_fields=[
                "current_token",
                "status",
                "updated_by",
                "updated_at",
            ]
        )

        serializer = LiveDoctorStatusSerializer(
            live_status,
            context={"request": request},
        )

        return Response(
            {
                "message": (
                    f"Current token {live_status.current_token} "
                    "kar diya gaya hai."
                ),
                "live_status": serializer.data,
            },
            status=status.HTTP_200_OK,
        )


class LiveDoctorResetQueueView(APIView):
    """
    New clinic shift/day ke liye current token zero karega.

    POST:
    /api/doctors/live-status/<doctor_clinic_id>/reset-queue/
    """

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, doctor_clinic_id):
        try:
            doctor_clinic = DoctorClinic.objects.select_related(
                "doctor",
                "doctor__user",
                "clinic",
            ).get(
                pk=doctor_clinic_id,
                is_active=True,
            )
        except DoctorClinic.DoesNotExist:
            return Response(
                {
                    "detail": (
                        "Active doctor-clinic record nahi mila."
                    )
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if not can_manage_live_status(
            request.user,
            doctor_clinic,
        ):
            return Response(
                {
                    "detail": (
                        "Aap is doctor ki queue reset "
                        "nahi kar sakte."
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        live_status, _ = LiveDoctorStatus.objects.get_or_create(
            doctor_clinic=doctor_clinic
        )

        live_status = LiveDoctorStatus.objects.select_for_update().get(
            pk=live_status.pk
        )

        live_status.current_token = 0
        live_status.status = (
            LiveDoctorStatus.Status.AVAILABLE
        )
        live_status.expected_return_at = None
        live_status.status_note = ""
        live_status.updated_by = request.user

        live_status.save(
            update_fields=[
                "current_token",
                "status",
                "expected_return_at",
                "status_note",
                "updated_by",
                "updated_at",
            ]
        )

        serializer = LiveDoctorStatusSerializer(
            live_status,
            context={"request": request},
        )

        return Response(
            {
                "message": "Doctor queue reset successfully.",
                "live_status": serializer.data,
            },
            status=status.HTTP_200_OK,
        )
class MyLiveDoctorStatusView(APIView):
    """
    Logged-in doctor ka active clinic live status return karega.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        doctor_clinic = (
            DoctorClinic.objects
            .select_related(
                "doctor",
                "doctor__user",
                "clinic",
            )
            .filter(
                doctor__user=request.user,
                is_active=True,
            )
            .first()
        )

        if doctor_clinic is None:
            return Response(
                {
                    "detail": (
                        "Logged-in user ka active doctor clinic "
                        "record nahi mila."
                    )
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        live_status, _ = LiveDoctorStatus.objects.get_or_create(
            doctor_clinic=doctor_clinic,
        )

        serializer = LiveDoctorStatusSerializer(
            live_status,
            context={"request": request},
        )

        return Response(
            serializer.data,
            status=status.HTTP_200_OK,
        )