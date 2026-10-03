from rest_framework import serializers

from .models import (
    Consultation,
    ConsultationSession,
    MedicalDocument,
    Prescription,
    PrescriptionMedicine,
)


class PrescriptionMedicineSerializer(serializers.ModelSerializer):
    """
    Serializes one medicine included in a prescription.
    """

    class Meta:
        model = PrescriptionMedicine
        fields = (
            "id",
            "medicine_name",
            "dosage",
            "frequency",
            "duration",
            "instructions",
        )


class PrescriptionSerializer(serializers.ModelSerializer):
    """
    Creates and returns a complete digital prescription.
    """

    medicines = PrescriptionMedicineSerializer(
        many=True,
    )

    patient_name = serializers.SerializerMethodField()
    patient_id = serializers.SerializerMethodField()
    doctor_name = serializers.SerializerMethodField()
    doctor_qualification = serializers.SerializerMethodField()
    doctor_specialty = serializers.SerializerMethodField()
    clinic_name = serializers.SerializerMethodField()
    appointment_date = serializers.SerializerMethodField()
    diagnosis = serializers.CharField(
        source="consultation.diagnosis",
        read_only=True,
    )
    medical_advice = serializers.CharField(
        source="consultation.medical_advice",
        read_only=True,
    )
    follow_up_required = serializers.BooleanField(
        source="consultation.follow_up_required",
        read_only=True,
    )
    follow_up_date = serializers.DateField(
        source="consultation.follow_up_date",
        read_only=True,
    )

    class Meta:
        model = Prescription
        fields = (
            "id",
            "consultation",
            "patient_name",
            "patient_id",
            "doctor_name",
            "doctor_qualification",
            "doctor_specialty",
            "clinic_name",
            "appointment_date",
            "diagnosis",
            "medical_advice",
            "follow_up_required",
            "follow_up_date",
            "additional_instructions",
            "medicines",
            "issued_at",
        )

        read_only_fields = ("issued_at",)

    def get_patient_name(self, obj):
        patient = obj.consultation.appointment.patient
        return patient.get_full_name() or patient.username

    def get_patient_id(self, obj):
        return obj.consultation.appointment.patient_id

    def get_doctor_name(self, obj):
        doctor_user = (
            obj.consultation
            .appointment
            .doctor_clinic
            .doctor
            .user
        )

        return doctor_user.get_full_name() or doctor_user.username

    def get_doctor_qualification(self, obj):
        """
        Returns the qualification saved on DoctorProfile, for example:
        "MBBS, FCPS Cardiology".
        """
        doctor = obj.consultation.appointment.doctor_clinic.doctor
        qualification = getattr(doctor, "qualification", "")
        return qualification or "Qualification not provided"

    def get_doctor_specialty(self, obj):
        specialty = (
            obj.consultation
            .appointment
            .doctor_clinic
            .doctor
            .specialty
        )
        return specialty.name if specialty else "Medical Specialist"

    def get_clinic_name(self, obj):
        return (
            obj.consultation
            .appointment
            .doctor_clinic
            .clinic
            .name
        )

    def get_appointment_date(self, obj):
        return obj.consultation.appointment.appointment_date

    def validate_consultation(self, consultation):
        """
        Only the assigned appointment doctor can create a prescription.
        """
        request = self.context.get("request")
        appointment_doctor = (
            consultation.appointment.doctor_clinic.doctor.user
        )

        if request is None or not request.user.is_authenticated:
            raise serializers.ValidationError(
                "Authentication is required."
            )

        if not request.user.is_superuser and appointment_doctor != request.user:
            raise serializers.ValidationError(
                "Only the assigned doctor can create this prescription."
            )

        if hasattr(consultation, "prescription"):
            raise serializers.ValidationError(
                "A prescription already exists for this consultation."
            )

        return consultation

    def validate_medicines(self, medicines):
        if not medicines:
            raise serializers.ValidationError(
                "Add at least one medicine."
            )

        return medicines

    def create(self, validated_data):
        """
        Creates the prescription and all medicines in one request.
        """
        medicines_data = validated_data.pop("medicines")

        prescription = Prescription.objects.create(
            **validated_data
        )

        for medicine_data in medicines_data:
            PrescriptionMedicine.objects.create(
                prescription=prescription,
                **medicine_data,
            )

        return prescription


class ConsultationSerializer(serializers.ModelSerializer):
    """
    Doctor consultation report serializer.
    """

    patient_name = serializers.SerializerMethodField()
    doctor_name = serializers.SerializerMethodField()
    created_by_name = serializers.SerializerMethodField()

    prescription = PrescriptionSerializer(
        read_only=True,
    )

    class Meta:
        model = Consultation
        fields = (
            "id",
            "appointment",
            "patient_name",
            "doctor_name",
            "diagnosis",
            "symptoms",
            "clinical_notes",
            "recommended_tests",
            "medical_advice",
            "follow_up_required",
            "follow_up_date",
            "created_by",
            "created_by_name",
            "prescription",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "created_by",
            "created_at",
            "updated_at",
        )

    def get_patient_name(self, obj):
        patient = obj.appointment.patient
        return patient.get_full_name() or patient.username

    def get_doctor_name(self, obj):
        doctor_user = obj.appointment.doctor_clinic.doctor.user
        return doctor_user.get_full_name() or doctor_user.username

    def get_created_by_name(self, obj):
        user = obj.created_by
        return user.get_full_name() or user.username

    def validate_appointment(self, appointment):
        """
        Doctor sirf apni appointment ki consultation bana sakta hai.
        """
        request = self.context.get("request")
        appointment_doctor = appointment.doctor_clinic.doctor.user

        if request is None or not request.user.is_authenticated:
            raise serializers.ValidationError(
                "Authentication is required."
            )

        if not request.user.is_superuser and appointment_doctor != request.user:
            raise serializers.ValidationError(
                "Only the assigned doctor can create this consultation."
            )

        if hasattr(appointment, "consultation"):
            raise serializers.ValidationError(
                "A consultation already exists for this appointment."
            )

        return appointment

    def validate(self, attrs):
        """
        Follow-up selected ho to date required hai.
        """
        follow_up_required = attrs.get(
            "follow_up_required",
            False,
        )

        follow_up_date = attrs.get("follow_up_date")

        if follow_up_required and not follow_up_date:
            raise serializers.ValidationError({
                "follow_up_date": (
                    "Select a follow-up date when follow-up is required."
                )
            })

        return attrs

class ConsultationSessionSerializer(serializers.ModelSerializer):
    """
    Video/audio consultation session serializer.
    """

    patient_name = serializers.SerializerMethodField()
    doctor_name = serializers.SerializerMethodField()
    session_type_display = serializers.CharField(
        source="get_session_type_display",
        read_only=True,
    )
    status_display = serializers.CharField(
        source="get_status_display",
        read_only=True,
    )

    class Meta:
        model = ConsultationSession
        fields = (
            "id",
            "appointment",
            "patient_name",
            "doctor_name",
            "session_type",
            "session_type_display",
            "room_id",
            "meeting_url",
            "status",
            "status_display",
            "doctor_joined_at",
            "patient_joined_at",
            "started_at",
            "ended_at",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "room_id",
            "meeting_url",
            "status",
            "doctor_joined_at",
            "patient_joined_at",
            "started_at",
            "ended_at",
            "created_at",
            "updated_at",
        )

    def get_patient_name(self, obj):
        patient = obj.appointment.patient
        return patient.get_full_name() or patient.username

    def get_doctor_name(self, obj):
        doctor_user = obj.appointment.doctor_clinic.doctor.user
        return doctor_user.get_full_name() or doctor_user.username

    def validate(self, attrs):
        request = self.context.get("request")
        appointment = attrs["appointment"]
        session_type = attrs["session_type"]

        doctor_user = appointment.doctor_clinic.doctor.user

        if request is None or not request.user.is_authenticated:
            raise serializers.ValidationError(
                "Authentication is required."
            )

        if not request.user.is_superuser and request.user != doctor_user:
            raise serializers.ValidationError(
                "Only the assigned doctor can create this session."
            )

        if appointment.consultation_mode not in ("video", "audio"):
            raise serializers.ValidationError(
                "An online session cannot be created for a clinic visit."
            )

        if session_type != appointment.consultation_mode:
            raise serializers.ValidationError({
                "session_type": (
                    "Session type does not match the appointment mode."
                )
            })

        if hasattr(appointment, "consultation_session"):
            raise serializers.ValidationError(
                "A session already exists for this appointment."
            )

        return attrs

class MedicalDocumentSerializer(serializers.ModelSerializer):
    """
    Patient medical document upload aur display serializer.
    """

    patient_name = serializers.SerializerMethodField()

    document_type_display = serializers.CharField(
        source="get_document_type_display",
        read_only=True,
    )

    class Meta:
        model = MedicalDocument
        fields = (
            "id",
            "patient",
            "patient_name",
            "appointment",
            "document_type",
            "document_type_display",
            "title",
            "file",
            "notes",
            "uploaded_by",
            "created_at",
        )

        read_only_fields = (
            "patient",
            "uploaded_by",
            "created_at",
        )

    def get_patient_name(self, obj):
        return (
            obj.patient.get_full_name()
            or obj.patient.username
        )

    def validate_appointment(self, appointment):
        """
        User sirf apni appointment ke saath document attach karega.
        """
        request = self.context.get("request")

        if request is None or not request.user.is_authenticated:
            raise serializers.ValidationError(
                "Authentication is required."
            )

        if appointment and appointment.patient != request.user:
            raise serializers.ValidationError(
                "You can attach a document only to your own appointment."
            )

        return appointment
