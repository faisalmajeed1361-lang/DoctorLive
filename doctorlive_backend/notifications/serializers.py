from rest_framework import serializers

from .models import AppointmentReminder, Notification


class NotificationSerializer(serializers.ModelSerializer):
    """
    Serialize an in-app notification belonging to a user.
    """

    notification_type_display = serializers.CharField(
        source="get_notification_type_display",
        read_only=True,
    )

    appointment_reference = serializers.SerializerMethodField()

    class Meta:
        model = Notification

        fields = (
            "id",
            "notification_type",
            "notification_type_display",
            "title",
            "message",
            "appointment",
            "appointment_reference",
            "is_read",
            "read_at",
            "created_at",
        )

        read_only_fields = (
            "id",
            "notification_type",
            "notification_type_display",
            "title",
            "message",
            "appointment",
            "appointment_reference",
            "is_read",
            "read_at",
            "created_at",
        )

    def get_appointment_reference(self, obj):
        """
        Return the permanent appointment reference when available.
        """
        if not obj.appointment:
            return None

        return getattr(
            obj.appointment,
            "appointment_reference",
            f"Appointment #{obj.appointment_id}",
        )


class AppointmentReminderSerializer(
    serializers.ModelSerializer,
):
    """
    Serialize a patient's appointment reminder.
    """

    patient_name = serializers.SerializerMethodField()
    doctor_name = serializers.SerializerMethodField()
    clinic_name = serializers.SerializerMethodField()

    appointment_reference = serializers.SerializerMethodField()

    appointment_date = serializers.DateField(
        source="appointment.appointment_date",
        read_only=True,
    )

    appointment_time = serializers.TimeField(
        source="appointment.appointment_time",
        read_only=True,
        allow_null=True,
    )

    reminder_type_display = serializers.CharField(
        source="get_reminder_type_display",
        read_only=True,
    )

    channel_display = serializers.CharField(
        source="get_channel_display",
        read_only=True,
    )

    status_display = serializers.CharField(
        source="get_status_display",
        read_only=True,
    )

    class Meta:
        model = AppointmentReminder

        fields = (
            "id",
            "appointment",
            "appointment_reference",
            "patient_name",
            "doctor_name",
            "clinic_name",
            "appointment_date",
            "appointment_time",
            "reminder_type",
            "reminder_type_display",
            "channel",
            "channel_display",
            "scheduled_for",
            "status",
            "status_display",
            "sent_at",
            "error_message",
            "created_at",
            "updated_at",
        )

        read_only_fields = fields

    def get_appointment_reference(self, obj):
        """
        Return the permanent appointment reference when available.
        """
        return getattr(
            obj.appointment,
            "appointment_reference",
            f"Appointment #{obj.appointment_id}",
        )

    def get_patient_name(self, obj):
        """
        Return the patient's full name or username.
        """
        patient = obj.appointment.patient

        return (
            patient.get_full_name()
            or patient.username
        )

    def get_doctor_name(self, obj):
        """
        Return the selected doctor's name.
        """
        doctor = (
            obj.appointment
            .doctor_clinic
            .doctor
        )

        return doctor.full_name

    def get_clinic_name(self, obj):
        """
        Return the selected clinic name.
        """
        return (
            obj.appointment
            .doctor_clinic
            .clinic
            .name
        )