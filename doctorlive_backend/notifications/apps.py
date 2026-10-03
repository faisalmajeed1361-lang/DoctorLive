from django.apps import AppConfig


class NotificationsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "notifications"

    def ready(self):
        """
        Django start hone par notification signals load karega.
        """
        import notifications.signals  # noqa: F401