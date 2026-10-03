from django.contrib import admin

from .models import AppointmentReminder, Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    """
    In-app notifications admin panel.
    """

    list_display = (
        "id",
        "user",
        "notification_type",
        "title",
        "is_read",
        "created_at",
    )

    list_filter = (
        "notification_type",
        "is_read",
        "created_at",
    )

    search_fields = (
        "user__username",
        "user__first_name",
        "user__last_name",
        "title",
        "message",
    )

    readonly_fields = (
        "created_at",
        "read_at",
    )


@admin.register(AppointmentReminder)
class AppointmentReminderAdmin(admin.ModelAdmin):
    """
    Appointment reminder scheduling aur status.
    """

    list_display = (
        "id",
        "appointment",
        "reminder_type",
        "channel",
        "scheduled_for",
        "status",
        "sent_at",
    )

    list_filter = (
        "reminder_type",
        "channel",
        "status",
        "scheduled_for",
    )

    search_fields = (
        "appointment__patient__username",
        "appointment__doctor_clinic__doctor__user__username",
    )

    readonly_fields = (
        "sent_at",
        "created_at",
        "updated_at",
    )