from rest_framework import serializers

from .models import (
    Clinic,
    DoctorClinic,
    DoctorProfile,
    LiveDoctorStatus,
    Specialty,
)


class SpecialtySerializer(serializers.ModelSerializer):
    """
    Doctor specialty ka API response.
    """

    class Meta:
        model = Specialty

        fields = (
            "id",
            "name",
            "description",
        )


class ClinicSerializer(serializers.ModelSerializer):
    """
    Verified clinic ki information.
    """

    class Meta:
        model = Clinic

        fields = (
            "id",
            "name",
            "city",
            "area",
            "complete_address",
            "phone_number",
            "email",
            "is_verified",
        )


class LiveDoctorStatusSerializer(serializers.ModelSerializer):
    """
    Doctor ki current availability aur token status.
    """

    status_display = serializers.CharField(
        source="get_status_display",
        read_only=True,
    )

    is_status_stale = serializers.BooleanField(
        read_only=True,
    )

    class Meta:
        model = LiveDoctorStatus

        fields = (
            "status",
            "status_display",
            "current_token",
            "expected_return_at",
            "status_note",
            "updated_at",
            "is_status_stale",
        )


class DoctorClinicSerializer(serializers.ModelSerializer):
    """
    Doctor ka clinic, schedule aur live status.
    """

    clinic = ClinicSerializer(
        read_only=True,
    )

    live_status = LiveDoctorStatusSerializer(
        read_only=True,
    )

    class Meta:
        model = DoctorClinic

        fields = (
            "id",
            "clinic",
            "room_number",
            "start_time",
            "end_time",
            "average_consultation_minutes",
            "live_status",
        )


class DoctorProfileSerializer(serializers.ModelSerializer):
    """
    Mobile app par show hone wali complete doctor profile.
    """

    specialty = SpecialtySerializer(
        read_only=True,
    )

    clinic_assignments = DoctorClinicSerializer(
        many=True,
        read_only=True,
    )

    class Meta:
        model = DoctorProfile

        fields = (
            "id",
            "full_name",
            "pmdc_registration_number",
            "qualification",
            "specialty",
            "experience_years",
            "consultation_fee",
            "languages",
            "bio",
            "profile_image",
            "offers_video_consultation",
            "offers_audio_consultation",
            "is_verified",
            "clinic_assignments",
        )

class LiveDoctorStatusSerializer(serializers.ModelSerializer):
    """
    Doctor-clinic ka live status patient ko display karega aur
    authorized doctor/clinic staff ko update karne dega.
    """

    doctor_name = serializers.CharField(
        source="doctor_clinic.doctor.full_name",
        read_only=True,
    )

    clinic_name = serializers.CharField(
        source="doctor_clinic.clinic.name",
        read_only=True,
    )

    clinic_city = serializers.CharField(
        source="doctor_clinic.clinic.city",
        read_only=True,
    )

    status_display = serializers.CharField(
        source="get_status_display",
        read_only=True,
    )

    is_status_stale = serializers.BooleanField(
        read_only=True,
    )

    updated_by_name = serializers.SerializerMethodField()

    class Meta:
        model = LiveDoctorStatus

        fields = (
            "id",
            "doctor_clinic",
            "doctor_name",
            "clinic_name",
            "clinic_city",
            "status",
            "status_display",
            "current_token",
            "expected_return_at",
            "status_note",
            "updated_by_name",
            "is_status_stale",
            "updated_at",
        )

        read_only_fields = (
            "id",
            "doctor_clinic",
            "doctor_name",
            "clinic_name",
            "clinic_city",
            "status_display",
            "updated_by_name",
            "is_status_stale",
            "updated_at",
        )

    def get_updated_by_name(self, obj):
        """
        Status update karne wale user ka readable name.
        """
        if not obj.updated_by:
            return ""

        return (
            obj.updated_by.get_full_name()
            or obj.updated_by.username
        )

    def validate_current_token(self, value):
        """
        Current token negative nahi ho sakta.
        """
        if value < 0:
            raise serializers.ValidationError(
                "Current token zero se kam nahi ho sakta."
            )

        return value

    def validate(self, attrs):
        """
        Status aur expected return time ka relation validate karega.
        """
        status_value = attrs.get(
            "status",
            getattr(
                self.instance,
                "status",
                LiveDoctorStatus.Status.OFF_DUTY,
            ),
        )

        expected_return_at = attrs.get(
            "expected_return_at",
            getattr(
                self.instance,
                "expected_return_at",
                None,
            ),
        )

        statuses_with_return_time = {
            LiveDoctorStatus.Status.BUSY,
            LiveDoctorStatus.Status.OPERATION,
            LiveDoctorStatus.Status.EMERGENCY,
            LiveDoctorStatus.Status.BREAK,
        }

        if (
            expected_return_at
            and status_value not in statuses_with_return_time
        ):
            raise serializers.ValidationError({
                "expected_return_at": (
                    "Expected return time sirf Busy, Operation, "
                    "Emergency ya Break status ke liye set karein."
                )
            })

        # Available ya off-duty hone par purana return time clear hoga.
        if status_value in {
            LiveDoctorStatus.Status.AVAILABLE,
            LiveDoctorStatus.Status.CONSULTING,
            LiveDoctorStatus.Status.OFF_DUTY,
            LiveDoctorStatus.Status.VIDEO_ONLY,
        }:
            attrs["expected_return_at"] = None

        # Status note ko safely trim karega.
        if "status_note" in attrs:
            attrs["status_note"] = (
                attrs["status_note"] or ""
            ).strip()

        return attrs