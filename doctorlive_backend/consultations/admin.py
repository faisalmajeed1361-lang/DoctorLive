from django.contrib import admin

from .models import (
    Consultation,
    ConsultationSession,
    MedicalDocument,
    Prescription,
    PrescriptionMedicine,
)


class PrescriptionMedicineInline(admin.TabularInline):
    """
    Prescription ke andar multiple medicines add karne ke liye.
    """

    model = PrescriptionMedicine
    extra = 1

    fields = (
        "medicine_name",
        "dosage",
        "frequency",
        "duration",
        "instructions",
    )


@admin.register(Consultation)
class ConsultationAdmin(admin.ModelAdmin):
    """
    Doctor consultation reports ki admin configuration.
    """

    list_display = (
        "id",
        "patient_name",
        "doctor_name",
        "appointment",
        "short_diagnosis",
        "follow_up_required",
        "follow_up_date",
        "created_at",
    )

    list_filter = (
        "follow_up_required",
        "created_at",
        "follow_up_date",
    )

    search_fields = (
        "appointment__patient__username",
        "appointment__patient__first_name",
        "appointment__patient__last_name",
        "appointment__doctor_clinic__doctor__user__first_name",
        "appointment__doctor_clinic__doctor__user__last_name",
        "diagnosis",
        "symptoms",
    )

    readonly_fields = (
        "created_at",
        "updated_at",
    )

    def patient_name(self, obj):
        patient = obj.appointment.patient
        return patient.get_full_name() or patient.username

    patient_name.short_description = "Patient"

    def doctor_name(self, obj):
        doctor_user = obj.appointment.doctor_clinic.doctor.user
        return doctor_user.get_full_name() or doctor_user.username

    doctor_name.short_description = "Doctor"

    def short_diagnosis(self, obj):
        """
        Admin list mein diagnosis ka short text show karega.
        """
        if len(obj.diagnosis) > 50:
            return f"{obj.diagnosis[:50]}..."

        return obj.diagnosis

    short_diagnosis.short_description = "Diagnosis"


@admin.register(Prescription)
class PrescriptionAdmin(admin.ModelAdmin):
    """
    Prescription ke saath medicines isi page par add hongi.
    """

    list_display = (
        "id",
        "patient_name",
        "doctor_name",
        "consultation",
        "issued_at",
    )

    search_fields = (
        "consultation__appointment__patient__username",
        "consultation__appointment__patient__first_name",
        "consultation__appointment__patient__last_name",
        "consultation__appointment__doctor_clinic__doctor__user__first_name",
        "consultation__appointment__doctor_clinic__doctor__user__last_name",
    )

    readonly_fields = ("issued_at",)

    inlines = [PrescriptionMedicineInline]

    def patient_name(self, obj):
        patient = obj.consultation.appointment.patient
        return patient.get_full_name() or patient.username

    patient_name.short_description = "Patient"

    def doctor_name(self, obj):
        doctor_user = (
            obj.consultation
            .appointment
            .doctor_clinic
            .doctor
            .user
        )

        return doctor_user.get_full_name() or doctor_user.username

    doctor_name.short_description = "Doctor"


@admin.register(PrescriptionMedicine)
class PrescriptionMedicineAdmin(admin.ModelAdmin):
    """
    Tamam prescribed medicines ki separate list.
    """

    list_display = (
        "medicine_name",
        "dosage",
        "frequency",
        "duration",
        "patient_name",
    )

    search_fields = (
        "medicine_name",
        "prescription__consultation__appointment__patient__username",
    )

    def patient_name(self, obj):
        patient = (
            obj.prescription
            .consultation
            .appointment
            .patient
        )

        return patient.get_full_name() or patient.username

    patient_name.short_description = "Patient"

@admin.register(ConsultationSession)
class ConsultationSessionAdmin(admin.ModelAdmin):
    """
    Online video/audio consultation sessions.
    """

    list_display = (
        "id",
        "appointment",
        "session_type",
        "status",
        "doctor_joined_at",
        "patient_joined_at",
        "created_at",
    )

    list_filter = (
        "session_type",
        "status",
        "created_at",
    )

    search_fields = (
        "appointment__patient__username",
        "appointment__doctor_clinic__doctor__user__username",
        "room_id",
    )

    readonly_fields = (
        "room_id",
        "meeting_url",
        "created_at",
        "updated_at",
    )

@admin.register(MedicalDocument)
class MedicalDocumentAdmin(admin.ModelAdmin):
    """
    Patient medical reports ki admin configuration.
    """

    list_display = (
        "id",
        "patient",
        "document_type",
        "title",
        "appointment",
        "uploaded_by",
        "created_at",
    )

    list_filter = (
        "document_type",
        "created_at",
    )

    search_fields = (
        "patient__username",
        "patient__first_name",
        "patient__last_name",
        "title",
        "notes",
    )

    readonly_fields = (
        "created_at",
    )