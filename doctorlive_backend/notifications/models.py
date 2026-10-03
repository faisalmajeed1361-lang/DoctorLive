from django.conf import settings
from django.db import models

from appointments.models import Appointment


class Notification(models.Model):
    """
    Patient, doctor aur clinic staff ki in-app notification.
    """

    class NotificationType(models.TextChoices):
        APPOINTMENT_BOOKED = (
            "appointment_booked",
            "Appointment Booked",
        )
        APPOINTMENT_REMINDER = (
            "appointment_reminder",
            "Appointment Reminder",
        )
        # New payment notification choices.
        PAYMENT_SUBMITTED = (
        "payment_submitted",
        "Payment Submitted",
        )
        PAYMENT_VERIFIED = (
            "payment_verified",
            "Payment Verified",
        )
        PAYMENT_REJECTED = (
            "payment_rejected",
            "Payment Rejected",
        )
        DOCTOR_UNAVAILABLE = (
            "doctor_unavailable",
            "Doctor Unavailable",
        )
        PRESCRIPTION_READY = (
            "prescription_ready",
            "Prescription Ready",
        )
        GENERAL = "general", "General"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications",
    )

    notification_type = models.CharField(
        max_length=30,
        choices=NotificationType.choices,
        default=NotificationType.GENERAL,
    )

    title = models.CharField(max_length=200)
    message = models.TextField()

    appointment = models.ForeignKey(
        Appointment,
        on_delete=models.CASCADE,
        related_name="notifications",
        null=True,
        blank=True,
    )

    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.user.username} - {self.title}"


class AppointmentReminder(models.Model):
    """
    Appointment se pehle automatically send hone wala reminder.
    """

    class ReminderType(models.TextChoices):
        BEFORE_24_HOURS = "24_hours", "24 Hours Before"
        BEFORE_2_HOURS = "2_hours", "2 Hours Before"
        BEFORE_30_MINUTES = "30_minutes", "30 Minutes Before"
        CUSTOM = "custom", "Custom Reminder"

    class ReminderChannel(models.TextChoices):
        IN_APP = "in_app", "In-App"
        EMAIL = "email", "Email"
        SMS = "sms", "SMS"
        WHATSAPP = "whatsapp", "WhatsApp"

    class ReminderStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        SENT = "sent", "Sent"
        FAILED = "failed", "Failed"
        CANCELLED = "cancelled", "Cancelled"

    appointment = models.ForeignKey(
        Appointment,
        on_delete=models.CASCADE,
        related_name="reminders",
    )

    reminder_type = models.CharField(
        max_length=20,
        choices=ReminderType.choices,
    )

    channel = models.CharField(
        max_length=20,
        choices=ReminderChannel.choices,
        default=ReminderChannel.IN_APP,
    )

    # Reminder kis date/time par send hoga.
    scheduled_for = models.DateTimeField()

    status = models.CharField(
        max_length=20,
        choices=ReminderStatus.choices,
        default=ReminderStatus.PENDING,
    )

    sent_at = models.DateTimeField(null=True, blank=True)

    # Reminder fail hone ki wajah.
    error_message = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["scheduled_for"]

        constraints = [
            models.UniqueConstraint(
                fields=[
                    "appointment",
                    "reminder_type",
                    "channel",
                ],
                name="unique_appointment_reminder_channel",
            )
        ]

    def __str__(self):
        return (
            f"Appointment #{self.appointment_id} - "
            f"{self.get_reminder_type_display()} - "
            f"{self.get_channel_display()}"
        )