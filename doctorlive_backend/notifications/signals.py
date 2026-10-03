from datetime import datetime, timedelta
from consultations.models import Prescription
from payments.models import Payment
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone

from appointments.models import Appointment

from .models import AppointmentReminder, Notification


@receiver(post_save, sender=Appointment)
def create_appointment_reminders(
    sender,
    instance,
    created,
    **kwargs,
):
    """
    Appointment create/update hone par reminders schedule karega.
    """

    appointment_datetime = datetime.combine(
        instance.appointment_date,
        instance.appointment_time,
    )

    appointment_datetime = timezone.make_aware(
        appointment_datetime,
        timezone.get_current_timezone(),
    )

    # Cancelled appointment ke pending reminders cancel karein.
    if instance.status == "cancelled":
        AppointmentReminder.objects.filter(
            appointment=instance,
            status=AppointmentReminder.ReminderStatus.PENDING,
        ).update(
            status=AppointmentReminder.ReminderStatus.CANCELLED
        )
        return

    # Appointment create hone par patient ko notification milegi.
    if created:
        doctor_user = instance.doctor_clinic.doctor.user
        doctor_name = (
            doctor_user.get_full_name()
            or doctor_user.username
        )

        Notification.objects.create(
            user=instance.patient,
            notification_type=(
                Notification.NotificationType.APPOINTMENT_BOOKED
            ),
            title="Appointment Booked",
            message=(
                f"Aap ki appointment Dr. {doctor_name} ke saath "
                f"{instance.appointment_date} ko "
                f"{instance.appointment_time} par book ho gayi hai. "
                f"Token number: {instance.token_number}."
            ),
            appointment=instance,
        )

    reminder_times = [
        (
            AppointmentReminder.ReminderType.BEFORE_24_HOURS,
            appointment_datetime - timedelta(hours=24),
        ),
        (
            AppointmentReminder.ReminderType.BEFORE_2_HOURS,
            appointment_datetime - timedelta(hours=2),
        ),
        (
            AppointmentReminder.ReminderType.BEFORE_30_MINUTES,
            appointment_datetime - timedelta(minutes=30),
        ),
    ]

    current_time = timezone.now()

    for reminder_type, scheduled_for in reminder_times:
        # Sirf future reminders create/update honge.
        if scheduled_for > current_time:
            AppointmentReminder.objects.update_or_create(
                appointment=instance,
                reminder_type=reminder_type,
                channel=AppointmentReminder.ReminderChannel.IN_APP,
                defaults={
                    "scheduled_for": scheduled_for,
                    "status": (
                        AppointmentReminder.ReminderStatus.PENDING
                    ),
                    "sent_at": None,
                    "error_message": "",
                },
            )
        else:
            # Appointment time change hone par expired pending
            # reminder remove kar diya jayega.
            AppointmentReminder.objects.filter(
                appointment=instance,
                reminder_type=reminder_type,
                channel=AppointmentReminder.ReminderChannel.IN_APP,
                status=AppointmentReminder.ReminderStatus.PENDING,
            ).delete()

@receiver(post_save, sender=Payment)
def create_payment_status_notification(
    sender,
    instance,
    created,
    **kwargs,
):
    """
    Payment verified/rejected hone par patient ko notification.
    """

    appointment = instance.appointment
    patient = appointment.patient

    if instance.status == Payment.PaymentStatus.VERIFIED:
        Notification.objects.get_or_create(
            user=patient,
            appointment=appointment,
            notification_type=(
                Notification.NotificationType.PAYMENT_VERIFIED
            ),
            defaults={
                "title": "Payment Verified",
                "message": (
                    f"Aap ki Rs. {instance.amount} payment "
                    f"successfully verify ho gayi hai. "
                    f"Appointment token: {appointment.token_number}."
                ),
            },
        )

    elif instance.status == Payment.PaymentStatus.REJECTED:
        Notification.objects.get_or_create(
            user=patient,
            appointment=appointment,
            notification_type=(
                Notification.NotificationType.PAYMENT_REJECTED
            ),
            defaults={
                "title": "Payment Rejected",
                "message": (
                    "Aap ki payment verify nahi ho saki. "
                    f"Reason: {instance.rejection_reason or 'Not provided'}"
                ),
            },
        )


@receiver(post_save, sender=Prescription)
def create_prescription_ready_notification(
    sender,
    instance,
    created,
    **kwargs,
):
    """
    Doctor prescription create kare to patient ko notification.
    """

    if not created:
        return

    appointment = instance.consultation.appointment
    patient = appointment.patient
    doctor_user = appointment.doctor_clinic.doctor.user

    doctor_name = (
        doctor_user.get_full_name()
        or doctor_user.username
    )

    Notification.objects.get_or_create(
        user=patient,
        appointment=appointment,
        notification_type=(
            Notification.NotificationType.PRESCRIPTION_READY
        ),
        defaults={
            "title": "Prescription Ready",
            "message": (
                f"Dr. {doctor_name} ne aap ki digital "
                "prescription upload kar di hai."
            ),
        },
    )