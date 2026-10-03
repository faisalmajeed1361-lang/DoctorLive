from django.core.management.base import BaseCommand
from django.utils import timezone

from notifications.models import (
    AppointmentReminder,
    Notification,
)


class Command(BaseCommand):
    """
    Due in-app appointment reminders send karta hai.
    """

    help = "Send all due DoctorLive appointment reminders."

    def handle(self, *args, **options):
        current_time = timezone.now()

        due_reminders = AppointmentReminder.objects.filter(
            status=AppointmentReminder.ReminderStatus.PENDING,
            channel=AppointmentReminder.ReminderChannel.IN_APP,
            scheduled_for__lte=current_time,
        ).select_related(
            "appointment",
            "appointment__patient",
            "appointment__doctor_clinic",
            "appointment__doctor_clinic__doctor",
            "appointment__doctor_clinic__doctor__user",
            "appointment__doctor_clinic__clinic",
        )

        sent_count = 0
        failed_count = 0

        for reminder in due_reminders:
            try:
                appointment = reminder.appointment
                doctor_user = appointment.doctor_clinic.doctor.user

                doctor_name = (
                    doctor_user.get_full_name()
                    or doctor_user.username
                )

                clinic_name = appointment.doctor_clinic.clinic.name

                title = (
                    "Appointment Reminder - "
                    f"{reminder.get_reminder_type_display()}"
                )

                Notification.objects.get_or_create(
                    user=appointment.patient,
                    appointment=appointment,
                    notification_type=(
                        Notification.NotificationType
                        .APPOINTMENT_REMINDER
                    ),
                    title=title,
                    defaults={
                        "message": (
                            f"Aap ki appointment Dr. {doctor_name} "
                            f"ke saath {clinic_name} mein "
                            f"{appointment.appointment_date} ko "
                            f"{appointment.appointment_time} par hai. "
                            f"Token number: "
                            f"{appointment.token_number}."
                        )
                    },
                )

                reminder.status = (
                    AppointmentReminder.ReminderStatus.SENT
                )
                reminder.sent_at = current_time
                reminder.error_message = ""

                reminder.save(
                    update_fields=[
                        "status",
                        "sent_at",
                        "error_message",
                        "updated_at",
                    ]
                )

                sent_count += 1

            except Exception as error:
                reminder.status = (
                    AppointmentReminder.ReminderStatus.FAILED
                )
                reminder.error_message = str(error)

                reminder.save(
                    update_fields=[
                        "status",
                        "error_message",
                        "updated_at",
                    ]
                )

                failed_count += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Reminders sent: {sent_count}, failed: {failed_count}"
            )
        )