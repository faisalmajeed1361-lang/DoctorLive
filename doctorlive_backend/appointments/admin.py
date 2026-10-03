from django.contrib import admin
from .models import Appointment, DoctorAvailabilitySlot
from .models import Appointment


@admin.register(Appointment)
class AppointmentAdmin(admin.ModelAdmin):
    """
    Patient appointments ko admin panel se manage karega.
    """

    list_display = (
        "id",
        "token_number",
        "patient_name",
        "doctor_name",
        "clinic_name",
        "appointment_date",
        "appointment_time",
        "consultation_mode",
        "status",
        "waiting_minutes",
    )

    # Appointment list ke right side par filters
    list_filter = (
        "status",
        "consultation_mode",
        "appointment_date",
        "doctor_clinic__clinic__city",
        "doctor_clinic__doctor__specialty",
    )

    # Patient, doctor aur clinic se search
    search_fields = (
        "patient__username",
        "patient__first_name",
        "patient__last_name",
        "doctor_clinic__doctor__full_name",
        "doctor_clinic__clinic__name",
        "symptoms_summary",
    )

    # Large dropdowns ko searchable banata hai
    autocomplete_fields = (
        "patient",
        "doctor_clinic",
    )

    # Ye fields system automatically manage karega
    readonly_fields = (
        "token_number",
        "estimated_waiting_time",
        "created_at",
        "updated_at",
    )

    # Appointment edit page ka professional layout
    fieldsets = (
        (
            "Patient and Doctor",
            {
                "fields": (
                    "patient",
                    "doctor_clinic",
                )
            },
        ),
        (
            "Appointment Information",
            {
                "fields": (
                    "appointment_date",
                    "appointment_time",
                    "token_number",
                    "consultation_mode",
                    "status",
                )
            },
        ),
        (
            "Medical Information",
            {
                "fields": (
                    "symptoms_summary",
                )
            },
        ),
        (
            "Online Consultation",
            {
                "fields": (
                    "video_meeting_link",
                )
            },
        ),
        (
            "Cancellation",
            {
                "fields": (
                    "cancellation_reason",
                )
            },
        ),
        (
            "System Information",
            {
                "fields": (
                    "estimated_waiting_time",
                    "created_at",
                    "updated_at",
                )
            },
        ),
    )

    date_hierarchy = "appointment_date"

    ordering = (
        "-appointment_date",
        "token_number",
    )

    @admin.display(description="Patient")
    def patient_name(self, obj):
        full_name = obj.patient.get_full_name()

        if full_name:
            return full_name

        return obj.patient.username

    @admin.display(description="Doctor")
    def doctor_name(self, obj):
        return f"Dr. {obj.doctor_clinic.doctor.full_name}"

    @admin.display(description="Clinic")
    def clinic_name(self, obj):
        return obj.doctor_clinic.clinic.name

    @admin.display(description="Waiting Time")
    def waiting_minutes(self, obj):
        return f"{obj.estimated_waiting_minutes} minutes"

    @admin.display(description="Estimated Waiting Time")
    def estimated_waiting_time(self, obj):
        return f"{obj.estimated_waiting_minutes} minutes"

@admin.register(DoctorAvailabilitySlot)
class DoctorAvailabilitySlotAdmin(admin.ModelAdmin):
    """
    Doctor appointment time slots manage کرے گا۔
    """

    list_display = (
        "id",
        "doctor_clinic",
        "slot_date",
        "start_time",
        "end_time",
        "slot_status",
        "is_active",
    )

    list_filter = (
        "slot_date",
        "is_active",
        "doctor_clinic__clinic",
    )

    search_fields = (
        "doctor_clinic__doctor__user__username",
        "doctor_clinic__doctor__user__first_name",
        "doctor_clinic__doctor__user__last_name",
        "doctor_clinic__clinic__name",
    )

    @admin.display(description="Status")
    def slot_status(self, obj):
        return "Booked" if obj.is_booked else "Available"