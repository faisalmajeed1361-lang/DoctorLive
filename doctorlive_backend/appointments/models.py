from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models, transaction
from django.db.models import Max

from doctors.models import DoctorClinic


class Appointment(models.Model):
    """
    Patient ka doctor ke saath clinic, video ya audio appointment.
    """

    class ConsultationMode(models.TextChoices):
        IN_PERSON = "in_person", "Clinic Visit"
        VIDEO = "video", "Video Consultation"
        AUDIO = "audio", "Audio Consultation"

    class AppointmentStatus(models.TextChoices):
        BOOKED = "booked", "Booked"
        CHECKED_IN = "checked_in", "Checked In"
        IN_CONSULTATION = "in_consultation", "In Consultation"
        COMPLETED = "completed", "Completed"
        CANCELLED = "cancelled", "Cancelled"
        NO_SHOW = "no_show", "No Show"
    @property
    def appointment_reference(self):
     """Database primary key se stable aur globally unique display reference."""
     if self.pk is None:
        return "DL-APT-PENDING"
     return f"DL-APT-{self.pk:06d}"
    
    # Appointment book karne wala patient
    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="doctor_appointments",
    )

    # Doctor kis clinic mein patient ko check karega
    doctor_clinic = models.ForeignKey(
        DoctorClinic,
        on_delete=models.PROTECT,
        related_name="appointments",
    )

    appointment_date = models.DateField(
        db_index=True,
    )

    appointment_time = models.TimeField(
        null=True,
        blank=True,
    )

    # System automatically token number generate karega
    token_number = models.PositiveIntegerField(
        editable=False,
    )

    consultation_mode = models.CharField(
        max_length=20,
        choices=ConsultationMode.choices,
        default=ConsultationMode.IN_PERSON,
    )

    status = models.CharField(
        max_length=30,
        choices=AppointmentStatus.choices,
        default=AppointmentStatus.BOOKED,
    )

    symptoms_summary = models.TextField(
        blank=True,
        help_text="Patient apni problem short form mein likhega.",
    )

    # Online consultation ke liye meeting link
    video_meeting_link = models.URLField(
        blank=True,
    )

    cancellation_reason = models.TextField(
        blank=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = [
            "appointment_date",
            "token_number",
        ]

        constraints = [
            models.UniqueConstraint(
                fields=[
                    "doctor_clinic",
                    "appointment_date",
                    "token_number",
                ],
                name="unique_daily_doctor_token",
            )
        ]

    def clean(self):
        """
        Video/audio appointment sirf tab allow hogi jab doctor
        ne apni profile mein woh service enable ki ho.
        """

        doctor = self.doctor_clinic.doctor

        if (
            self.consultation_mode == self.ConsultationMode.VIDEO
            and not doctor.offers_video_consultation
        ):
            raise ValidationError(
                {
                    "consultation_mode": (
                        "This doctor does not offer video consultation."
                    )
                }
            )

        if (
            self.consultation_mode == self.ConsultationMode.AUDIO
            and not doctor.offers_audio_consultation
        ):
            raise ValidationError(
                {
                    "consultation_mode": (
                        "This doctor does not offer audio consultation."
                    )
                }
            )

    def save(self, *args, **kwargs):
        """
        Har doctor-clinic ke liye daily automatic token number.

        Example:
        First patient  = Token 1
        Second patient = Token 2
        Third patient  = Token 3
        """

        self.full_clean()

        if not self.token_number:
            with transaction.atomic():
                last_token = (
                    Appointment.objects.select_for_update()
                    .filter(
                        doctor_clinic=self.doctor_clinic,
                        appointment_date=self.appointment_date,
                    )
                    .aggregate(
                        maximum_token=Max("token_number")
                    )["maximum_token"]
                    or 0
                )

                self.token_number = last_token + 1

                return super().save(*args, **kwargs)

        return super().save(*args, **kwargs)
    @property
    def appointment_reference(self):
        """
        Appointment ka permanent aur unique public reference.

        Token number sirf daily queue ke liye hai.
        Payment, receipt aur notification mein yeh reference use hoga.

        Example:
        DL-20260926-000125
        """

        # Appointment database mein save na hui ho to primary key nahi hogi.
        if self.pk is None:
            return "DL-APT-PENDING"

        date_text = self.appointment_date.strftime("%Y%m%d")

        return (
            f"DL-{date_text}-"
            f"{self.pk:06d}"
        )
    @property
    def estimated_waiting_minutes(self):
        """
        Current token aur doctor ke average consultation time
        se patient ka estimated waiting time calculate hoga.
        """

        try:
            current_token = (
                self.doctor_clinic.live_status.current_token
            )
        except DoctorClinic.live_status.RelatedObjectDoesNotExist:
            current_token = 0

        remaining_patients = max(
            self.token_number - current_token - 1,
            0,
        )

        return (
            remaining_patients
            * self.doctor_clinic.average_consultation_minutes
        )

    def __str__(self):
        return (
            f"Token {self.token_number} - "
            f"{self.patient.username} with "
            f"Dr. {self.doctor_clinic.doctor.full_name}"
        )

class DoctorAvailabilitySlot(models.Model):
    """
    Doctor ka bookable appointment time slot.

    Example:
    Dr. Ahmed
    25-09-2026
    10:00 AM se 10:20 AM
    """

    doctor_clinic = models.ForeignKey(
        "doctors.DoctorClinic",
        on_delete=models.CASCADE,
        related_name="availability_slots",
    )

    slot_date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()

    # Appointment book hone par is field mein appointment save hogi.
    appointment = models.OneToOneField(
        Appointment,
        on_delete=models.SET_NULL,
        related_name="booked_slot",
        null=True,
        blank=True,
    )

    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = [
            "slot_date",
            "start_time",
        ]

        constraints = [
            models.UniqueConstraint(
                fields=[
                    "doctor_clinic",
                    "slot_date",
                    "start_time",
                ],
                name="unique_doctor_clinic_time_slot",
            )
        ]

    @property
    def is_booked(self):
        """
        Slot appointment ke saath linked ho to booked hai.
        """
        return self.appointment_id is not None

    @property
    def is_available(self):
        """
        Patient ko slot tab available dikhega jab active aur unbooked ho.
        """
        return self.is_active and not self.is_booked

    def clean(self):
        """
        Invalid slot timings aur mismatched appointments rokega.
        """
        super().clean()

        if self.end_time <= self.start_time:
            raise ValidationError({
                "end_time": (
                    "Slot end time, start time se baad honi chahiye."
                )
            })

        if self.appointment:
            if (
                self.appointment.doctor_clinic_id
                != self.doctor_clinic_id
            ):
                raise ValidationError({
                    "appointment": (
                        "Appointment aur slot ka doctor/clinic "
                        "same hona chahiye."
                    )
                })

            if self.appointment.appointment_date != self.slot_date:
                raise ValidationError({
                    "appointment": (
                        "Appointment date aur slot date same honi chahiye."
                    )
                })

            if self.appointment.appointment_time != self.start_time:
                raise ValidationError({
                    "appointment": (
                        "Appointment time aur slot start time "
                        "same honi chahiye."
                    )
                })

    def __str__(self):
        status = "Booked" if self.is_booked else "Available"

        return (
            f"{self.doctor_clinic} - "
            f"{self.slot_date} {self.start_time} - {status}"
        )