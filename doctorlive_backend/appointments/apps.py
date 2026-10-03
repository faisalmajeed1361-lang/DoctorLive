from django.apps import AppConfig


class AppointmentsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "appointments"

    def ready(self):
        """
        Load appointment signals when Django starts.
        """
        import appointments.signals  # noqa: F401