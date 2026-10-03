from rest_framework import serializers

from .models import Payment, PaymentAccount


class PaymentAccountSerializer(serializers.ModelSerializer):
    """
    Patient ko clinic ka active public receiving account return karega.

    PIN, OTP, password ya secret information API mein return nahi hogi.
    """

    clinic_name = serializers.CharField(
        source="clinic.name",
        read_only=True,
    )

    account_type_display = serializers.CharField(
        source="get_account_type_display",
        read_only=True,
    )

    class Meta:
        model = PaymentAccount

        fields = (
            "id",
            "clinic",
            "clinic_name",
            "account_type",
            "account_type_display",
            "account_title",
            "account_number",
            "bank_name",
            "iban",
            "instructions",
        )

        read_only_fields = (
            "id",
            "clinic_name",
            "account_type_display",
        )


class PaymentSerializer(serializers.ModelSerializer):
    """
    Payment submission, payment history aur printable receipt data.

    Payment amount Flutter app se accept nahi hogi.
    Backend selected doctor ki original consultation fee use karega.
    """

    # Permanent appointment/receipt reference.
    appointment_reference = serializers.CharField(
        source="appointment.appointment_reference",
        read_only=True,
    )

    patient_name = serializers.SerializerMethodField()
    doctor_name = serializers.SerializerMethodField()
    clinic_name = serializers.SerializerMethodField()
    verified_by_name = serializers.SerializerMethodField()

    # Receipt ke liye appointment date aur time.
    appointment_date = serializers.DateField(
        source="appointment.appointment_date",
        read_only=True,
    )

    appointment_time = serializers.TimeField(
        source="appointment.appointment_time",
        read_only=True,
        allow_null=True,
    )

    # Flutter ko clinic-specific payment accounts filter karne ke liye.
    clinic_id = serializers.IntegerField(
        source="appointment.doctor_clinic.clinic_id",
        read_only=True,
    )

    payment_method_display = serializers.CharField(
        source="get_payment_method_display",
        read_only=True,
    )

    status_display = serializers.CharField(
        source="get_status_display",
        read_only=True,
    )

    class Meta:
        model = Payment

        fields = (
            "id",
            "appointment",
            "appointment_reference",
            "patient_name",
            "doctor_name",
            "clinic_id",
            "clinic_name",
            "appointment_date",
            "appointment_time",
            "payment_account",
            "payment_method",
            "payment_method_display",
            "amount",
            "transaction_reference",
            "payment_proof",
            "status",
            "status_display",
            "paid_at",
            "verified_at",
            "verified_by_name",
            "rejection_reason",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "appointment_reference",
            "patient_name",
            "doctor_name",
            "clinic_id",
            "clinic_name",
            "appointment_date",
            "appointment_time",
            "payment_method_display",
            "amount",
            "status",
            "status_display",
            "paid_at",
            "verified_at",
            "verified_by_name",
            "rejection_reason",
            "created_at",
            "updated_at",
        )

    def get_patient_name(self, obj):
        """
        Patient ka full name return karega.
        Full name na ho to username return hoga.
        """

        patient = obj.appointment.patient

        return (
            patient.get_full_name()
            or patient.username
        )

    def get_doctor_name(self, obj):
        """
        Appointment ke selected doctor ka name return karega.
        """

        doctor = obj.appointment.doctor_clinic.doctor

        # Doctor model mein full_name property/field available ho.
        if getattr(doctor, "full_name", None):
            return doctor.full_name

        doctor_user = doctor.user

        return (
            doctor_user.get_full_name()
            or doctor_user.username
        )

    def get_clinic_name(self, obj):
        """
        Appointment wali clinic ka name return karega.
        """

        return (
            obj.appointment
            .doctor_clinic
            .clinic
            .name
        )

    def get_verified_by_name(self, obj):
        """
        Payment verify karne wale admin/staff ka readable name.
        """

        if not obj.verified_by:
            return ""

        return (
            obj.verified_by.get_full_name()
            or obj.verified_by.username
        )

    def validate_appointment(self, appointment):
        """
        Patient ko sirf apni valid appointment ki payment allow karega.
        """

        request = self.context.get("request")

        if (
            request is None
            or not request.user.is_authenticated
        ):
            raise serializers.ValidationError(
                "Login required hai."
            )

        # Patient kisi doosre patient ki payment submit nahi kar sakta.
        if appointment.patient_id != request.user.id:
            raise serializers.ValidationError(
                "Aap sirf apni appointment ki payment "
                "kar sakte hain."
            )

        # OneToOne payment ki wajah se aik appointment ki aik payment.
        if hasattr(appointment, "payment"):
            raise serializers.ValidationError(
                "Is appointment ki payment pehle se "
                "submit ho chuki hai."
            )

        # Cancelled ya no-show appointment ki payment allowed nahi.
        if appointment.status in (
            "cancelled",
            "no_show",
        ):
            raise serializers.ValidationError(
                "Cancelled ya no-show appointment ki "
                "payment submit nahi ho sakti."
            )

        return appointment

    def validate_payment_proof(self, file):
        """
        Payment proof sirf JPG/PNG aur maximum 5 MB hoga.
        """

        maximum_size = 5 * 1024 * 1024

        if file.size > maximum_size:
            raise serializers.ValidationError(
                "Payment screenshot ka size 5 MB se "
                "zyada nahi ho sakta."
            )

        allowed_content_types = (
            "image/jpeg",
            "image/png",
        )

        content_type = getattr(
            file,
            "content_type",
            "",
        )

        if (
            content_type
            and content_type not in allowed_content_types
        ):
            raise serializers.ValidationError(
                "Sirf JPG, JPEG aur PNG payment "
                "screenshots allowed hain."
            )

        return file

    def validate(self, attrs):
        """
        Payment method, clinic account, transaction reference
        aur payment proof validate karega.
        """

        appointment = attrs.get("appointment")
        payment_method = attrs.get("payment_method")
        payment_account = attrs.get("payment_account")

        transaction_reference = str(
            attrs.get(
                "transaction_reference",
                "",
            )
        ).strip()

        payment_proof = attrs.get("payment_proof")

        if appointment is None:
            raise serializers.ValidationError(
                {
                    "appointment": (
                        "Appointment select karna zaroori hai."
                    )
                }
            )

        # Cash payment clinic par receive hogi.
        if payment_method == Payment.PaymentMethod.CASH:
            attrs["payment_account"] = None
            attrs["transaction_reference"] = ""
            attrs["payment_proof"] = None

            return attrs

        # Digital payment ke liye receiving account required hai.
        if not payment_account:
            raise serializers.ValidationError(
                {
                    "payment_account": (
                        "Selected clinic ka receiving "
                        "account select karein."
                    )
                }
            )

        if not payment_account.is_active:
            raise serializers.ValidationError(
                {
                    "payment_account": (
                        "Yeh payment account active nahi hai."
                    )
                }
            )

        appointment_clinic_id = (
            appointment.doctor_clinic.clinic_id
        )

        # Account appointment wali clinic ka hona chahiye.
        if (
            payment_account.clinic_id
            != appointment_clinic_id
        ):
            raise serializers.ValidationError(
                {
                    "payment_account": (
                        "Selected account appointment wali "
                        "clinic ka nahi hai."
                    )
                }
            )

        # Selected account type payment method se match kare.
        if (
            payment_account.account_type
            != payment_method
        ):
            raise serializers.ValidationError(
                {
                    "payment_account": (
                        "Selected account payment method se "
                        "match nahi karta."
                    )
                }
            )

        if not transaction_reference:
            raise serializers.ValidationError(
                {
                    "transaction_reference": (
                        "Transaction ID enter karna "
                        "zaroori hai."
                    )
                }
            )

        # Digital payment ke liye receipt screenshot required hai.
        if not payment_proof:
            raise serializers.ValidationError(
                {
                    "payment_proof": (
                        "Payment receipt ka screenshot "
                        "upload karna zaroori hai."
                    )
                }
            )

        attrs["transaction_reference"] = (
            transaction_reference
        )

        return attrs

    def create(self, validated_data):
        """
        Doctor ki consultation fee automatically payment amount hogi.
        """

        appointment = validated_data["appointment"]

        consultation_fee = (
            appointment
            .doctor_clinic
            .doctor
            .consultation_fee
        )

        payment_method = validated_data[
            "payment_method"
        ]

        # Cash clinic par receive hone ke baad verify hogi.
        if (
            payment_method
            == Payment.PaymentMethod.CASH
        ):
            payment_status = (
                Payment.PaymentStatus.PENDING
            )

        # Digital payment proof staff/admin verify karega.
        else:
            payment_status = (
                Payment.PaymentStatus.SUBMITTED
            )

        return Payment.objects.create(
            amount=consultation_fee,
            status=payment_status,
            **validated_data,
        )