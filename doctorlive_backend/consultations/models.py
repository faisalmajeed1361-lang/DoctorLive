from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
import uuid
from appointments.models import Appointment
from django.core.validators import FileExtensionValidator


class Consultation(models.Model):
    """
    Doctor aur patient ki completed medical consultation.

    Har appointment ki sirf aik consultation report hogi.
    """

    appointment = models.OneToOneField(
        Appointment,
        on_delete=models.CASCADE,
        related_name="consultation",
    )

    # Doctor ka diagnosis.
    diagnosis = models.TextField()

    # Patient ki reported symptoms.
    symptoms = models.TextField(blank=True)

    # Doctor ki private/medical observations.
    clinical_notes = models.TextField(blank=True)

    # Tests jo doctor recommend kare.
    recommended_tests = models.TextField(blank=True)

    # Patient ko general instructions.
    medical_advice = models.TextField(blank=True)

    follow_up_required = models.BooleanField(default=False)
    follow_up_date = models.DateField(null=True, blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="created_consultations",
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def clean(self):
        """
        Follow-up required ho to date bhi required hogi.
        """
        super().clean()

        if self.follow_up_required and not self.follow_up_date:
            raise ValidationError({
                "follow_up_date": (
                    "Follow-up required ho to follow-up date select karein."
                )
            })

    def __str__(self):
        return (
            f"Consultation #{self.id} - "
            f"Appointment #{self.appointment_id}"
        )


class Prescription(models.Model):
    """
    Consultation ki digital prescription.
    """

    consultation = models.OneToOneField(
        Consultation,
        on_delete=models.CASCADE,
        related_name="prescription",
    )

    additional_instructions = models.TextField(blank=True)

    issued_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Prescription #{self.id}"


class PrescriptionMedicine(models.Model):
    """
    Prescription mein doctor ki likhi hui medicine.
    """

    prescription = models.ForeignKey(
        Prescription,
        on_delete=models.CASCADE,
        related_name="medicines",
    )

    medicine_name = models.CharField(max_length=200)

    # Example: 500 mg
    dosage = models.CharField(max_length=100)

    # Example: din mein 2 dafa
    frequency = models.CharField(max_length=150)

    # Example: 5 days
    duration = models.CharField(max_length=100)

    # Example: khane ke baad
    instructions = models.CharField(
        max_length=250,
        blank=True,
    )

    def __str__(self):
        return (
            f"{self.medicine_name} - "
            f"{self.dosage} - {self.frequency}"
        )

class ConsultationSession(models.Model):
    """
    Video ya audio online consultation session.

    Har appointment ka sirf aik online session hoga.
    """

    class SessionType(models.TextChoices):
        VIDEO = "video", "Video Consultation"
        AUDIO = "audio", "Audio Consultation"

    class SessionStatus(models.TextChoices):
        SCHEDULED = "scheduled", "Scheduled"
        WAITING = "waiting", "Patient Waiting"
        ACTIVE = "active", "Consultation Active"
        ENDED = "ended", "Consultation Ended"
        CANCELLED = "cancelled", "Cancelled"

    appointment = models.OneToOneField(
        Appointment,
        on_delete=models.CASCADE,
        related_name="consultation_session",
    )

    session_type = models.CharField(
        max_length=10,
        choices=SessionType.choices,
    )

    # Random room ID link ko guess karna mushkil banata hai.
    room_id = models.UUIDField(
        default=uuid.uuid4,
        unique=True,
        editable=False,
    )

    meeting_url = models.URLField(
        max_length=500,
        blank=True,
    )

    status = models.CharField(
        max_length=20,
        choices=SessionStatus.choices,
        default=SessionStatus.SCHEDULED,
    )

    doctor_joined_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    patient_joined_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    started_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    ended_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        """
        Meeting URL automatically generate hogi.
        """
        if not self.meeting_url:
            self.meeting_url = (
                f"https://meet.jit.si/DoctorLive-{self.room_id}"
            )

        super().save(*args, **kwargs)

    def clean(self):
        """
        Sirf video/audio appointments ke sessions ban sakte hain.
        """
        super().clean()

        allowed_modes = ["video", "audio"]

        if self.appointment.consultation_mode not in allowed_modes:
            raise ValidationError({
                "appointment": (
                    "Clinic visit appointment ke liye online "
                    "consultation room create nahi ho sakta."
                )
            })

        if self.session_type != self.appointment.consultation_mode:
            raise ValidationError({
                "session_type": (
                    "Session type appointment mode se match nahi karta."
                )
            })

    def __str__(self):
        return (
            f"{self.get_session_type_display()} - "
            f"Appointment #{self.appointment_id}"
        )

def validate_medical_file_size(file):
    """
    Medical document ka maximum size 10 MB rakhega.
    """
    maximum_size = 10 * 1024 * 1024

    if file.size > maximum_size:
        raise ValidationError(
            "Medical document ka size 10 MB se zyada nahi ho sakta."
        )


def medical_document_upload_path(instance, filename):
    """
    Har patient ke documents separate folder mein save honge.
    """
    return f"medical_documents/patient_{instance.patient_id}/{filename}"


class MedicalDocument(models.Model):
    """
    Patient ki medical report, scan, X-ray ya previous prescription.
    """

    class DocumentType(models.TextChoices):
        LAB_REPORT = "lab_report", "Lab Report"
        XRAY = "xray", "X-Ray"
        SCAN = "scan", "CT/MRI/Ultrasound Scan"
        PRESCRIPTION = "prescription", "Previous Prescription"
        DISCHARGE_SUMMARY = (
            "discharge_summary",
            "Discharge Summary",
        )
        OTHER = "other", "Other Document"

    patient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="medical_documents",
    )

    # Document ko appointment ke saath link karna optional hai.
    appointment = models.ForeignKey(
        Appointment,
        on_delete=models.SET_NULL,
        related_name="medical_documents",
        null=True,
        blank=True,
    )

    document_type = models.CharField(
        max_length=30,
        choices=DocumentType.choices,
    )

    title = models.CharField(max_length=200)

    file = models.FileField(
        upload_to=medical_document_upload_path,
        validators=[
            FileExtensionValidator(
                allowed_extensions=[
                    "pdf",
                    "jpg",
                    "jpeg",
                    "png",
                ]
            ),
            validate_medical_file_size,
        ],
    )

    notes = models.TextField(blank=True)

    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="uploaded_medical_documents",
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def clean(self):
        """
        Linked appointment isi patient ki honi chahiye.
        """
        super().clean()

        if (
            self.appointment
            and self.appointment.patient_id != self.patient_id
        ):
            raise ValidationError({
                "appointment": (
                    "Selected appointment is patient ki nahi hai."
                )
            })

    def __str__(self):
        return f"{self.patient.username} - {self.title}"