from django.contrib import admin

from .models import (
    Clinic,
    ClinicStaff,
    DoctorClinic,
    DoctorProfile,
    LiveDoctorStatus,
    Specialty,
)


@admin.register(Specialty)
class SpecialtyAdmin(admin.ModelAdmin):
    """
    Medical specialties ko admin panel se manage karega.
    """

    list_display = (
        "id",
        "name",
        "is_active",
        "created_at",
    )

    list_filter = (
        "is_active",
    )

    search_fields = (
        "name",
        "description",
    )

    ordering = (
        "name",
    )


@admin.register(Clinic)
class ClinicAdmin(admin.ModelAdmin):
    """
    Hospitals aur clinics ko manage karega.
    """

    list_display = (
        "id",
        "name",
        "city",
        "area",
        "phone_number",
        "is_verified",
        "is_active",
    )

    list_filter = (
        "city",
        "is_verified",
        "is_active",
    )

    search_fields = (
        "name",
        "city",
        "area",
        "phone_number",
    )

    list_editable = (
        "is_verified",
        "is_active",
    )

    ordering = (
        "city",
        "area",
        "name",
    )


class DoctorClinicInline(admin.TabularInline):
    """
    Doctor profile ke andar hi uske clinics add karne ki facility.
    """

    model = DoctorClinic
    extra = 1

    fields = (
        "clinic",
        "room_number",
        "start_time",
        "end_time",
        "average_consultation_minutes",
        "is_active",
    )

    autocomplete_fields = (
        "clinic",
    )


@admin.register(DoctorProfile)
class DoctorProfileAdmin(admin.ModelAdmin):
    """
    Doctor ki professional details aur verification manage karega.
    """

    list_display = (
        "id",
        "doctor_name",
        "specialty",
        "pmdc_registration_number",
        "experience_years",
        "consultation_fee",
        "offers_video_consultation",
        "is_verified",
        "is_active",
    )

    list_filter = (
        "specialty",
        "offers_video_consultation",
        "offers_audio_consultation",
        "is_verified",
        "is_active",
    )

    search_fields = (
        "full_name",
        "pmdc_registration_number",
        "qualification",
        "user__username",
        "user__email",
    )

    autocomplete_fields = (
        "user",
        "specialty",
    )

    list_editable = (
        "is_verified",
        "is_active",
    )

    inlines = (
        DoctorClinicInline,
    )

    ordering = (
        "full_name",
    )

    @admin.display(description="Doctor")
    def doctor_name(self, obj):
        return f"Dr. {obj.full_name}"


@admin.register(DoctorClinic)
class DoctorClinicAdmin(admin.ModelAdmin):
    """
    Doctor aur clinic ke connection aur schedule ko manage karega.
    """

    list_display = (
        "id",
        "doctor",
        "clinic",
        "room_number",
        "start_time",
        "end_time",
        "average_consultation_minutes",
        "is_active",
    )

    list_filter = (
        "clinic__city",
        "clinic",
        "is_active",
    )

    search_fields = (
        "doctor__full_name",
        "clinic__name",
        "clinic__city",
        "room_number",
    )

    autocomplete_fields = (
        "doctor",
        "clinic",
    )


@admin.register(LiveDoctorStatus)
class LiveDoctorStatusAdmin(admin.ModelAdmin):
    """
    Doctor ka live status aur current token manage karega.
    """

    list_display = (
        "id",
        "doctor_name",
        "clinic_name",
        "status",
        "current_token",
        "expected_return_at",
        "updated_at",
        "stale_status",
    )

    list_filter = (
        "status",
        "updated_at",
    )

    search_fields = (
        "doctor_clinic__doctor__full_name",
        "doctor_clinic__clinic__name",
        "doctor_clinic__clinic__city",
    )

    autocomplete_fields = (
        "doctor_clinic",
        "updated_by",
    )

    readonly_fields = (
        "updated_at",
    )

    @admin.display(description="Doctor")
    def doctor_name(self, obj):
        return f"Dr. {obj.doctor_clinic.doctor.full_name}"

    @admin.display(description="Clinic")
    def clinic_name(self, obj):
        return obj.doctor_clinic.clinic.name

    @admin.display(
        description="Status Stale",
        boolean=True,
    )
    def stale_status(self, obj):
        return obj.is_status_stale

@admin.register(ClinicStaff)
class ClinicStaffAdmin(admin.ModelAdmin):
    """
    Receptionist aur clinic manager assignments manage karega.
    """

    list_display = (
        "id",
        "user",
        "clinic",
        "staff_role",
        "is_active",
        "created_at",
    )

    list_filter = (
        "staff_role",
        "clinic__city",
        "clinic",
        "is_active",
    )

    search_fields = (
        "user__username",
        "user__first_name",
        "user__last_name",
        "clinic__name",
        "clinic__city",
    )

    autocomplete_fields = (
        "user",
        "clinic",
    )

    list_editable = (
        "is_active",
    )