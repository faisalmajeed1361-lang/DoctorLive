from django.contrib import admin
from django.utils import timezone

from .models import Payment, PaymentAccount


@admin.register(PaymentAccount)
class PaymentAccountAdmin(admin.ModelAdmin):
    """
    Clinic ke Bank/JazzCash/Easypaisa receiving accounts.
    """

    list_display = (
        "clinic",
        "account_type",
        "account_title",
        "masked_account_number",
        "is_active",
    )

    list_filter = (
        "account_type",
        "is_active",
        "clinic",
    )

    search_fields = (
        "clinic__name",
        "account_title",
        "account_number",
        "bank_name",
        "iban",
    )

    @admin.display(description="Account Number")
    def masked_account_number(self, obj):
        """
        Admin list mein complete account number hide karega.

        Example:
        03001234567 ko *******4567 show karega.
        """
        number = obj.account_number or ""

        if len(number) <= 4:
            return number

        return f"{'*' * (len(number) - 4)}{number[-4:]}"


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    """
    Patient payments verify/reject karne ki admin configuration.
    """

    list_display = (
        "id",
        "patient_name",
        "doctor_name",
        "payment_method",
        "amount",
        "status",
        "transaction_reference",
        "created_at",
    )

    list_filter = (
        "status",
        "payment_method",
        "created_at",
    )

    search_fields = (
        "appointment__patient__username",
        "appointment__patient__first_name",
        "appointment__patient__last_name",
        "appointment__doctor_clinic__doctor__user__first_name",
        "appointment__doctor_clinic__doctor__user__last_name",
        "transaction_reference",
    )

    readonly_fields = (
        "created_at",
        "updated_at",
        "verified_at",
        "verified_by",
    )

    actions = (
        "verify_selected_payments",
        "reject_selected_payments",
    )

    @admin.display(description="Patient")
    def patient_name(self, obj):
        patient = obj.appointment.patient
        return patient.get_full_name() or patient.username

    @admin.display(description="Doctor")
    def doctor_name(self, obj):
        doctor_user = obj.appointment.doctor_clinic.doctor.user
        return doctor_user.get_full_name() or doctor_user.username

    @admin.action(description="Verify selected payments")
    def verify_selected_payments(self, request, queryset):
        """
        Selected payments verify karega.

        Har payment par save() use ho raha hai taake payment
        notification signal bhi execute ho.
        """
        updated_count = 0

        for payment in queryset:
            payment.status = Payment.PaymentStatus.VERIFIED
            payment.verified_by = request.user
            payment.verified_at = timezone.now()
            payment.paid_at = timezone.now()
            payment.rejection_reason = ""

            # save() payment notification signal trigger karega.
            payment.save()

            updated_count += 1

        self.message_user(
            request,
            f"{updated_count} payment(s) successfully verified.",
        )

    @admin.action(description="Reject selected payments")
    def reject_selected_payments(self, request, queryset):
        """
        Selected payments reject karega.

        Admin bulk action mein default rejection reason use hoga.
        Detailed reason payment edit page se add kiya ja sakta hai.
        """
        updated_count = 0

        for payment in queryset:
            # Verified payment ko accidentally reject nahi karenge.
            if payment.status == Payment.PaymentStatus.VERIFIED:
                continue

            payment.status = Payment.PaymentStatus.REJECTED
            payment.verified_by = request.user
            payment.verified_at = timezone.now()
            payment.paid_at = None

            if not payment.rejection_reason:
                payment.rejection_reason = (
                    "Payment details could not be verified."
                )

            # save() rejection notification signal trigger karega.
            payment.save()

            updated_count += 1

        self.message_user(
            request,
            f"{updated_count} payment(s) rejected.",
        )