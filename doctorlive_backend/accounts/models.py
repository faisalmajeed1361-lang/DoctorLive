from django.conf import settings
from django.db import models


class UserProfile(models.Model):
    """
    DoctorLive ke har user ki additional information store karega.

    Django ka built-in User model username, email aur password rakhega.
    Ye profile user ka role, phone number aur city store karegi.
    """

    # Application mein available user roles
    class Role(models.TextChoices):
        PATIENT = "patient", "Patient"
        DOCTOR = "doctor", "Doctor"
        RECEPTIONIST = "receptionist", "Receptionist"

    # Har Django user ki sirf ek profile hogi
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="profile",
    )

    # User application mein kis role se kaam karega
    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.PATIENT,
    )

    phone_number = models.CharField(
        max_length=20,
        blank=True,
    )

    city = models.CharField(
        max_length=100,
        blank=True,
    )

    address = models.TextField(
        blank=True,
    )

    profile_image = models.ImageField(
        upload_to="profile_images/",
        blank=True,
        null=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    def __str__(self):
        return f"{self.user.username} - {self.get_role_display()}"