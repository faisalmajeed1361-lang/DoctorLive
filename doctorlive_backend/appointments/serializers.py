from django.db import transaction
from django.utils import timezone
from rest_framework import serializers

from notifications.models import Notification

from .models import Appointment, DoctorAvailabilitySlot


class AppointmentSerializer(serializers.ModelSerializer):
    """
    Appointment booking, validation aur complete details serializer.
    """

    # Permanent appointment reference.
    appointment_reference = serializers.CharField(
        read_only=True,
    )

    patient_name = serializers.SerializerMethodField()

    doctor_name = serializers.CharField(
        source="doctor_clinic.doctor.full_name",
        read_only=True,
    )

    specialty = serializers.CharField(
        source="doctor_clinic.doctor.specialty.name",
        read_only=True,
    )

    clinic_id = serializers.IntegerField(
        source="doctor_clinic.clinic_id",
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

    clinic_address = serializers.CharField(
        source="doctor_clinic.clinic.complete_address",
        read_only=True,
    )

    consultation_fee = serializers.DecimalField(
        source="doctor_clinic.doctor.consultation_fee",
        max_digits=10,
        decimal_places=2,
        read_only=True,
    )

    status_display = serializers.CharField(
        source="get_status_display",
        read_only=True,
    )

    consultation_mode_display = serializers.CharField(
        source="get_consultation_mode_display",
        read_only=True,
    )

    estimated_waiting_minutes = serializers.IntegerField(
        read_only=True,
    )

    class Meta:
        model = Appointment
        doctor_clinic_id = serializers.IntegerField(
    source="doctor_clinic.pk",
    read_only=True,
    )
        fields = (
            "id",
            "appointment_reference",
            "patient_name",
            "doctor_clinic",
            "doctor_name",
            "specialty",
            "clinic_id",
            "doctor_clinic_id",
            "clinic_name",
            "clinic_city",
            "clinic_address",
            "consultation_fee",
            "appointment_date",
            "appointment_time",
            "token_number",
            "consultation_mode",
            "consultation_mode_display",
            "status",
            "status_display",
            "symptoms_summary",
            "video_meeting_link",
            "cancellation_reason",
            "estimated_waiting_minutes",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "appointment_reference",
            "patient_name",
            "clinic_id",
            "token_number",
            "status",
            "video_meeting_link",
            "cancellation_reason",
            "estimated_waiting_minutes",
            "created_at",
            "updated_at",
        )

    def get_patient_name(self, obj):
        """
        Patient ka full name return karega.
        Full name available na ho to username return hoga.
        """

        return (
            obj.patient.get_full_name()
            or obj.patient.username
        )

    def validate_appointment_date(self, value):
        """
        Past date par appointment booking allow nahi karega.
        """

        if value < timezone.localdate():
            raise serializers.ValidationError(
                "Appointment date cannot be in the past."
            )

        return value

    def validate(self, attrs):
        """
        Doctor, clinic, consultation mode aur duplicate booking
        validate karega.
        """

        doctor_clinic = attrs["doctor_clinic"]
        doctor = doctor_clinic.doctor
        clinic = doctor_clinic.clinic

        mode = attrs.get(
            "consultation_mode",
            Appointment.ConsultationMode.IN_PERSON,
        )

        appointment_date = attrs["appointment_date"]
        appointment_time = attrs.get("appointment_time")

        # Doctor ka selected clinic assignment active hona chahiye.
        if not doctor_clinic.is_active:
            raise serializers.ValidationError(
                "Doctor is not active at this clinic."
            )

        # Doctor verified aur active hona chahiye.
        if not doctor.is_active or not doctor.is_verified:
            raise serializers.ValidationError(
                "This doctor is currently unavailable."
            )

        # Clinic verified aur active honi chahiye.
        if not clinic.is_active or not clinic.is_verified:
            raise serializers.ValidationError(
                "This clinic is currently unavailable."
            )

        # Video consultation sirf enabled doctor ke liye hogi.
        if (
            mode == Appointment.ConsultationMode.VIDEO
            and not doctor.offers_video_consultation
        ):
            raise serializers.ValidationError({
                "consultation_mode": (
                    "This doctor does not offer video consultation."
                )
            })

        # Audio consultation sirf enabled doctor ke liye hogi.
        if (
            mode == Appointment.ConsultationMode.AUDIO
            and not doctor.offers_audio_consultation
        ):
            raise serializers.ValidationError({
                "consultation_mode": (
                    "This doctor does not offer audio consultation."
                )
            })

        request = self.context.get("request")

        if request and request.user.is_authenticated:
            # Patient aik doctor ke saath aik hi date par multiple
            # active appointments create nahi kar sakta.
            duplicate_exists = Appointment.objects.filter(
                patient=request.user,
                doctor_clinic=doctor_clinic,
                appointment_date=appointment_date,
                status__in=[
                    Appointment.AppointmentStatus.BOOKED,
                    Appointment.AppointmentStatus.CHECKED_IN,
                    Appointment.AppointmentStatus.IN_CONSULTATION,
                ],
            ).exists()

            if duplicate_exists:
                raise serializers.ValidationError(
                    "You already have an active appointment "
                    "with this doctor on this date."
                )

        # Agar selected date/time ka slot mojood hai aur pehle se
        # booked hai to booking submit nahi hogi.
        if appointment_time is not None:
            slot = DoctorAvailabilitySlot.objects.filter(
                doctor_clinic=doctor_clinic,
                slot_date=appointment_date,
                start_time=appointment_time,
                is_active=True,
            ).first()

            if slot and slot.appointment_id is not None:
                raise serializers.ValidationError({
                    "appointment_time": (
                        "Selected appointment slot has already "
                        "been booked."
                    )
                })

        return attrs

    @transaction.atomic
    def create(self, validated_data):
        """
        Appointment create karega, selected slot lock karega aur
        patient/doctor notifications generate karega.
        """

        request = self.context["request"]

        doctor_clinic = validated_data["doctor_clinic"]
        appointment_date = validated_data["appointment_date"]
        appointment_time = validated_data.get(
            "appointment_time"
        )

        matching_slot = None

        # Slot row ko transaction lock mein read karenge.
        # Is se same waqt par aane wali do requests aik slot
        # reserve nahi kar sakti.
        if appointment_time is not None:
            matching_slot = (
                DoctorAvailabilitySlot.objects
                .select_for_update()
                .filter(
                    doctor_clinic=doctor_clinic,
                    slot_date=appointment_date,
                    start_time=appointment_time,
                    is_active=True,
                )
                .first()
            )

            if (
                matching_slot
                and matching_slot.appointment_id is not None
            ):
                raise serializers.ValidationError({
                    "appointment_time": (
                        "Selected appointment slot has already "
                        "been booked."
                    )
                })

        # Appointment model patient aur token automatically handle karega.
        appointment = Appointment.objects.create(
            patient=request.user,
            **validated_data,
        )

        # Matching slot available ho to new appointment ke saath
        # permanently link kar dein.
        if matching_slot is not None:
            matching_slot.appointment = appointment
            matching_slot.full_clean()

            matching_slot.save(
                update_fields=[
                    "appointment",
                    "updated_at",
                ]
            )

        patient_name = (
            request.user.get_full_name()
            or request.user.username
        )

        doctor = appointment.doctor_clinic.doctor
        doctor_user = doctor.user

        date_text = appointment.appointment_date.strftime(
            "%d/%m/%Y"
        )

        time_text = (
            appointment.appointment_time.strftime("%H:%M")
            if appointment.appointment_time
            else "Not selected"
        )

        # Patient ko booking confirmation notification milegi.
        Notification.objects.create(
            user=request.user,
            notification_type=(
                Notification.NotificationType.APPOINTMENT_BOOKED
            ),
            title="Appointment Booked",
            message=(
                f"Your appointment with Dr. "
                f"{doctor.full_name} is booked for "
                f"{date_text} at {time_text}. "
                f"Reference: "
                f"{appointment.appointment_reference}. "
                f"Token number: "
                f"{appointment.token_number}."
            ),
            appointment=appointment,
        )

        # Selected doctor ko new appointment notification milegi.
        Notification.objects.create(
            user=doctor_user,
            notification_type=(
                Notification.NotificationType.APPOINTMENT_BOOKED
            ),
            title="New Appointment Received",
            message=(
                f"{patient_name} booked an appointment "
                f"for {date_text} at {time_text}. "
                f"Reference: "
                f"{appointment.appointment_reference}. "
                f"Token number: "
                f"{appointment.token_number}."
            ),
            appointment=appointment,
        )

        return appointment


class DoctorAvailabilitySlotSerializer(
    serializers.ModelSerializer
):
    """
    Doctor ke available appointment slots ka serializer.
    """

    doctor_name = serializers.SerializerMethodField()
    clinic_name = serializers.SerializerMethodField()
    is_booked = serializers.BooleanField(read_only=True)
    is_available = serializers.BooleanField(read_only=True)

    class Meta:
        model = DoctorAvailabilitySlot

        fields = (
            "id",
            "doctor_clinic",
            "doctor_name",
            "clinic_name",
            "slot_date",
            "start_time",
            "end_time",
            "is_active",
            "is_booked",
            "is_available",
            "created_at",
        )

        read_only_fields = (
            "is_booked",
            "is_available",
            "created_at",
        )

    def get_doctor_name(self, obj):
        """
        Doctor ka full name ya username return karega.
        """

        doctor_user = obj.doctor_clinic.doctor.user

        return (
            doctor_user.get_full_name()
            or doctor_user.username
        )

    def get_clinic_name(self, obj):
        """
        Slot wali clinic ka name return karega.
        """

        return obj.doctor_clinic.clinic.name

    def validate(self, attrs):
        """
        Slot ownership, past date aur timing validate karega.
        """

        request = self.context["request"]

        doctor_clinic = attrs["doctor_clinic"]
        slot_date = attrs["slot_date"]
        start_time = attrs["start_time"]
        end_time = attrs["end_time"]

        doctor_user = doctor_clinic.doctor.user

        # Sirf related doctor ya superuser slot create kar sakta hai.
        if (
            not request.user.is_superuser
            and request.user != doctor_user
        ):
            raise serializers.ValidationError(
                "Only the relevant doctor can create this slot."
            )

        # Past date ka slot create nahi hoga.
        if slot_date < timezone.localdate():
            raise serializers.ValidationError({
                "slot_date": (
                    "Past date slot cannot be created."
                )
            })

        # End time start time ke baad honi chahiye.
        if end_time <= start_time:
            raise serializers.ValidationError({
                "end_time": (
                    "End time must be after start time."
                )
            })

        # Same doctor/clinic/date/time ka duplicate slot nahi hoga.
        duplicate_slot = DoctorAvailabilitySlot.objects.filter(
            doctor_clinic=doctor_clinic,
            slot_date=slot_date,
            start_time=start_time,
        )

        if self.instance:
            duplicate_slot = duplicate_slot.exclude(
                pk=self.instance.pk
            )

        if duplicate_slot.exists():
            raise serializers.ValidationError({
                "start_time": (
                    "This appointment slot already exists."
                )
            })

        return attrs