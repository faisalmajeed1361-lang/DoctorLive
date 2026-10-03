from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.db import models

from appointments.models import Appointment
from doctors.models import Clinic


class PaymentAccount(models.Model):
    """
    Clinic ke payment receiving accounts.

    Important:
    Yahan sirf public receiving information hogi.
    PIN, OTP, password ya secret key kabhi store nahi hogi.
    """

    class AccountType(models.TextChoices):
        BANK_TRANSFER = "bank_transfer", "Bank Transfer"
        JAZZCASH = "jazzcash", "JazzCash"
        EASYPAISA = "easypaisa", "Easypaisa"

    clinic = models.ForeignKey(
        Clinic,
        on_delete=models.CASCADE,
        related_name="payment_accounts",
    )

    account_type = models.CharField(
        max_length=30,
        choices=AccountType.choices,
    )

    account_title = models.CharField(max_length=150)
    account_number = models.CharField(max_length=50)

    # Sirf bank account ke liye zaroori ho sakte hain.
    bank_name = models.CharField(max_length=150, blank=True)
    iban = models.CharField(max_length=50, blank=True)

    instructions = models.TextField(
        blank=True,
        help_text="Patient ke liye payment instructions.",
    )

    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["clinic", "account_type", "account_title"]

    def __str__(self):
        # Admin list mein complete account number expose nahi kar rahe.
        return f"{self.clinic.name} - {self.get_account_type_display()}"


class Payment(models.Model):
    """
    Appointment ki payment information.

    Har appointment ki filhal aik payment record hoga.
    """

    class PaymentMethod(models.TextChoices):
        CASH = "cash", "Cash at Clinic"
        BANK_TRANSFER = "bank_transfer", "Bank Transfer"
        JAZZCASH = "jazzcash", "JazzCash"
        EASYPAISA = "easypaisa", "Easypaisa"

    class PaymentStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        SUBMITTED = "submitted", "Submitted for Verification"
        VERIFIED = "verified", "Verified / Paid"
        REJECTED = "rejected", "Rejected"
        REFUNDED = "refunded", "Refunded"

    appointment = models.OneToOneField(
        Appointment,
        on_delete=models.CASCADE,
        related_name="payment",
    )

    payment_account = models.ForeignKey(
        PaymentAccount,
        on_delete=models.PROTECT,
        related_name="payments",
        null=True,
        blank=True,
        help_text="Cash payment mein account select karna zaroori nahi.",
    )

    payment_method = models.CharField(
        max_length=30,
        choices=PaymentMethod.choices,
    )

    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(1)],
    )

    transaction_reference = models.CharField(
        max_length=100,
        blank=True,
        help_text="Bank/JazzCash/Easypaisa transaction ID.",
    )

    payment_proof = models.ImageField(
        upload_to="payment_proofs/%Y/%m/",
        null=True,
        blank=True,
        help_text="Payment receipt ka screenshot.",
    )

    status = models.CharField(
        max_length=20,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING,
    )

    paid_at = models.DateTimeField(null=True, blank=True)

    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="verified_payments",
        null=True,
        blank=True,
    )

    verified_at = models.DateTimeField(null=True, blank=True)

    rejection_reason = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def clean(self):
        """
        Galat clinic account ya incomplete digital payment rokta hai.
        """
        super().clean()

        if self.payment_method == self.PaymentMethod.CASH:
            return

        if not self.payment_account:
            raise ValidationError({
                "payment_account": "Online payment ke liye account select karein."
            })

        appointment_clinic_id = (
            self.appointment.doctor_clinic.clinic_id
        )

        if self.payment_account.clinic_id != appointment_clinic_id:
            raise ValidationError({
                "payment_account": "Yeh account appointment wali clinic ka nahi hai."
            })

        if self.payment_account.account_type != self.payment_method:
            raise ValidationError({
                "payment_account": "Selected account payment method se match nahi karta."
            })

        if not self.transaction_reference:
            raise ValidationError({
                "transaction_reference": "Transaction ID enter karna zaroori hai."
            })

    @property
    def is_paid(self):
        return self.status == self.PaymentStatus.VERIFIED

    def __str__(self):
        return (
            f"Appointment #{self.appointment_id} - "
            f"{self.get_payment_method_display()} - "
            f"{self.get_status_display()}"
        )