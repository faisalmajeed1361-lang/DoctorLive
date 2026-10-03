from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models
from django.utils import timezone
from django.core.exceptions import ValidationError

class Specialty(models.Model):
    """
    Doctor ki medical specialty store karega.

    Examples:
    General Physician, Cardiologist, Dermatologist,
    Pediatrician, Gynecologist.
    """

    name = models.CharField(
        max_length=100,
        unique=True,
    )

    description = models.TextField(
        blank=True,
    )

    is_active = models.BooleanField(
        default=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        verbose_name_plural = "Specialties"
        ordering = ["name"]

    def __str__(self):
        return self.name


class Clinic(models.Model):
    """
    Hospital ya private clinic ki basic information.
    """

    name = models.CharField(
        max_length=200,
    )

    city = models.CharField(
        max_length=100,
        db_index=True,
    )

    area = models.CharField(
        max_length=150,
        db_index=True,
    )

    complete_address = models.TextField()

    phone_number = models.CharField(
        max_length=20,
    )

    email = models.EmailField(
        blank=True,
    )

    # Sirf admin-verified clinics patient ko show honge
    is_verified = models.BooleanField(
        default=False,
    )

    is_active = models.BooleanField(
        default=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        ordering = ["city", "area", "name"]

    def __str__(self):
        return f"{self.name} - {self.city}"


class DoctorProfile(models.Model):
    """
    Doctor ki professional information.

    Login information Django User model mein hogi,
    jabke medical information is model mein store hogi.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="doctor_profile",
    )

    specialty = models.ForeignKey(
        Specialty,
        on_delete=models.PROTECT,
        related_name="doctors",
    )

    full_name = models.CharField(
        max_length=150,
    )

    pmdc_registration_number = models.CharField(
        max_length=100,
        unique=True,
    )

    qualification = models.CharField(
        max_length=250,
    )

    experience_years = models.PositiveSmallIntegerField(
        default=0,
    )

    consultation_fee = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
    )

    languages = models.CharField(
        max_length=200,
        default="Urdu",
        help_text="Example: Urdu, English, Punjabi",
    )

    bio = models.TextField(
        blank=True,
    )

    profile_image = models.ImageField(
        upload_to="doctor_images/",
        blank=True,
        null=True,
    )

    offers_video_consultation = models.BooleanField(
        default=False,
    )

    offers_audio_consultation = models.BooleanField(
        default=False,
    )

    # Admin doctor ki details verify karega
    is_verified = models.BooleanField(
        default=False,
    )

    is_active = models.BooleanField(
        default=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = ["full_name"]

    def __str__(self):
        return f"Dr. {self.full_name}"


class DoctorClinic(models.Model):
    """
    Ek doctor multiple clinics/hospitals mein kaam kar sakta hai.
    Ye model doctor ko clinic ke saath connect karega.
    """

    doctor = models.ForeignKey(
        DoctorProfile,
        on_delete=models.CASCADE,
        related_name="clinic_assignments",
    )

    clinic = models.ForeignKey(
        Clinic,
        on_delete=models.CASCADE,
        related_name="doctor_assignments",
    )

    room_number = models.CharField(
        max_length=30,
        blank=True,
    )

    start_time = models.TimeField(
        null=True,
        blank=True,
    )

    end_time = models.TimeField(
        null=True,
        blank=True,
    )

    # Average duration waiting-time calculate karne mein use hogi
    average_consultation_minutes = models.PositiveSmallIntegerField(
        default=10,
    )

    is_active = models.BooleanField(
        default=True,
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["doctor", "clinic"],
                name="unique_doctor_clinic",
            )
        ]

    def __str__(self):
        return f"{self.doctor.full_name} at {self.clinic.name}"


class LiveDoctorStatus(models.Model):
    """
    Doctor ki clinic mein current live availability.

    Doctor ya receptionist status update karega.
    Patient ko status ke saath last update time bhi nazar aayega.
    """

    class Status(models.TextChoices):
        AVAILABLE = "available", "Available Now"
        CONSULTING = "consulting", "Consulting Patients"
        BUSY = "busy", "Temporarily Busy"
        OPERATION = "operation", "In Operation"
        EMERGENCY = "emergency", "Handling Emergency"
        BREAK = "break", "On Break"
        OFF_DUTY = "off_duty", "Off Duty"
        VIDEO_ONLY = "video_only", "Video Consultation Only"

    doctor_clinic = models.OneToOneField(
        DoctorClinic,
        on_delete=models.CASCADE,
        related_name="live_status",
    )

    status = models.CharField(
        max_length=30,
        choices=Status.choices,
        default=Status.OFF_DUTY,
    )

    current_token = models.PositiveIntegerField(
        default=0,
    )

    expected_return_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    status_note = models.CharField(
        max_length=250,
        blank=True,
    )

    # Kis doctor/receptionist ne status update kiya
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="doctor_status_updates",
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    @property
    def is_status_stale(self):
        """
        Agar status 30 minutes se update nahi hua,
        to patient ko live verified status nahi dikhana chahiye.
        """

        difference = timezone.now() - self.updated_at
        return difference.total_seconds() > 1800

    def __str__(self):
        return (
            f"{self.doctor_clinic.doctor.full_name} - "
            f"{self.get_status_display()}"
        )

class ClinicStaff(models.Model):
    """
    Receptionist ya clinic staff ko specific clinic ke saath connect karega.

    Is assignment ke baghair receptionist kisi doctor ka
    live status ya token update nahi kar sakega.
    """

    class StaffRole(models.TextChoices):
        RECEPTIONIST = "receptionist", "Receptionist"
        MANAGER = "manager", "Clinic Manager"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="clinic_staff_assignments",
    )

    clinic = models.ForeignKey(
        Clinic,
        on_delete=models.CASCADE,
        related_name="staff_assignments",
    )

    staff_role = models.CharField(
        max_length=20,
        choices=StaffRole.choices,
        default=StaffRole.RECEPTIONIST,
    )

    is_active = models.BooleanField(
        default=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=[
                    "user",
                    "clinic",
                ],
                name="unique_user_clinic_staff",
            )
        ]

        ordering = [
            "clinic__name",
            "user__username",
        ]

    def __str__(self):
        return (
            f"{self.user.username} - "
            f"{self.get_staff_role_display()} at "
            f"{self.clinic.name}"
        )

