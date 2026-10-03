from django.utils import timezone

from rest_framework import generics, status
from rest_framework.parsers import (
    FormParser,
    JSONParser,
    MultiPartParser,
)
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from doctors.models import ClinicStaff
from notifications.models import Notification

from .models import Payment, PaymentAccount
from .serializers import (
    PaymentAccountSerializer,
    PaymentSerializer,
)


def payment_queryset():
    """
    Payment screens ke liye related database records preload karega.
    Is se unnecessary database queries kam hongi.
    """

    return Payment.objects.select_related(
        "appointment",
        "appointment__patient",
        "appointment__doctor_clinic",
        "appointment__doctor_clinic__doctor",
        "appointment__doctor_clinic__doctor__user",
        "appointment__doctor_clinic__clinic",
        "payment_account",
        "verified_by",
    )


def can_review_payment(user, payment):
    """
    Superuser ya payment wali clinic ka active staff member
    payment verify/reject kar sakta hai.
    """

    if user.is_superuser:
        return True

    clinic = (
        payment
        .appointment
        .doctor_clinic
        .clinic
    )

    return ClinicStaff.objects.filter(
        user=user,
        clinic=clinic,
        is_active=True,
    ).exists()


def create_payment_notification(
    payment,
    notification_type,
    title,
    message,
):
    """
    Payment status change par patient notification create karega.
    """

    Notification.objects.create(
        user=payment.appointment.patient,
        notification_type=notification_type,
        title=title,
        message=message,
        appointment=payment.appointment,
    )


class PaymentAccountListView(generics.ListAPIView):
    """
    Active receiving accounts return karega.

    Flutter selected appointment ka clinic ID send karega:

    /api/payments/accounts/?clinic=1
    """

    serializer_class = PaymentAccountSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = PaymentAccount.objects.filter(
            is_active=True,
        ).select_related(
            "clinic",
        )

        clinic_id = self.request.query_params.get(
            "clinic"
        )

        # Patient screen par sirf selected clinic ke
        # accounts return honge.
        if clinic_id:
            queryset = queryset.filter(
                clinic_id=clinic_id,
            )

        return queryset


class PaymentListCreateView(
    generics.ListCreateAPIView
):
    """
    GET:
    Logged-in patient ki payment history return karega.

    POST:
    Cash ya online payment record create karega.
    """

    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated]

    parser_classes = (
        MultiPartParser,
        FormParser,
        JSONParser,
    )

    def get_queryset(self):
        """
        Patient sirf apni payments dekh sakta hai.
        """

        return payment_queryset().filter(
            appointment__patient=self.request.user,
        )

    def perform_create(self, serializer):
        """
        Payment save hone ke baad patient ko notification dega.
        """

        payment = serializer.save()

        if (
            payment.payment_method
            == Payment.PaymentMethod.CASH
        ):
            title = "Pay at Clinic"

            message = (
                f"Cash payment for "
                f"{payment.appointment.appointment_reference} "
                f"will be collected at the clinic. "
                f"Amount: Rs. {payment.amount}."
            )

        else:
            title = "Payment Submitted"

            message = (
                f"Payment for "
                f"{payment.appointment.appointment_reference} "
                f"has been submitted and is awaiting "
                f"clinic verification."
            )

        create_payment_notification(
            payment=payment,
            notification_type=(
                Notification
                .NotificationType
                .PAYMENT_SUBMITTED
            ),
            title=title,
            message=message,
        )


class PaymentDetailView(generics.RetrieveAPIView):
    """
    Patient apni selected payment ki detail aur receipt
    dekh sakta hai.
    """

    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return payment_queryset().filter(
            appointment__patient=self.request.user,
        )


class AdminPaymentListView(generics.ListAPIView):
    """
    Superuser ko tamam payments milengi.

    Clinic staff ko sirf un clinics ki payments milengi
    jahan woh active staff member hai.

    Optional filter:

    /api/payments/admin/?status=submitted
    """

    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user

        queryset = payment_queryset()

        if not user.is_superuser:
            clinic_ids = ClinicStaff.objects.filter(
                user=user,
                is_active=True,
            ).values_list(
                "clinic_id",
                flat=True,
            )

            queryset = queryset.filter(
                appointment__doctor_clinic__clinic_id__in=(
                    clinic_ids
                )
            )

        payment_status = (
            self.request.query_params.get("status")
        )

        valid_statuses = {
            choice[0]
            for choice in Payment.PaymentStatus.choices
        }

        if (
            payment_status
            and payment_status in valid_statuses
        ):
            queryset = queryset.filter(
                status=payment_status,
            )

        return queryset


class PaymentVerifyView(APIView):
    """
    Superuser ya related clinic staff payment verify karega.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            payment = payment_queryset().get(
                pk=pk,
            )

        except Payment.DoesNotExist:
            return Response(
                {
                    "detail": "Payment nahi mili.",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if not can_review_payment(
            request.user,
            payment,
        ):
            return Response(
                {
                    "detail": (
                        "Aap is clinic ki payment verify "
                        "nahi kar sakte."
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        # Cancelled ya no-show appointment ki payment verify
        # nahi honi chahiye.
        if payment.appointment.status in (
            "cancelled",
            "no_show",
        ):
            return Response(
                {
                    "detail": (
                        "Cancelled ya no-show appointment "
                        "ki payment verify nahi ho sakti."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if (
            payment.status
            == Payment.PaymentStatus.VERIFIED
        ):
            return Response(
                {
                    "detail": (
                        "Payment pehle se verified hai."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if (
            payment.status
            == Payment.PaymentStatus.REFUNDED
        ):
            return Response(
                {
                    "detail": (
                        "Refunded payment verify nahi "
                        "ho sakti."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        current_time = timezone.now()

        payment.status = (
            Payment.PaymentStatus.VERIFIED
        )

        payment.verified_by = request.user
        payment.verified_at = current_time
        payment.paid_at = current_time
        payment.rejection_reason = ""

        payment.save(
            update_fields=(
                "status",
                "verified_by",
                "verified_at",
                "paid_at",
                "rejection_reason",
                "updated_at",
            )
        )

        create_payment_notification(
            payment=payment,
            notification_type=(
                Notification
                .NotificationType
                .PAYMENT_VERIFIED
            ),
            title="Payment Verified",
            message=(
                f"Payment for "
                f"{payment.appointment.appointment_reference} "
                f"has been verified successfully. "
                f"Amount: Rs. {payment.amount}."
            ),
        )

        serializer = PaymentSerializer(
            payment,
            context={
                "request": request,
            },
        )

        return Response(
            {
                "message": (
                    "Payment successfully verified."
                ),
                "payment": serializer.data,
            },
            status=status.HTTP_200_OK,
        )


class PaymentRejectView(APIView):
    """
    Superuser ya related clinic staff invalid payment reject karega.

    Reject karte waqt reason required hai.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            payment = payment_queryset().get(
                pk=pk,
            )

        except Payment.DoesNotExist:
            return Response(
                {
                    "detail": "Payment nahi mili.",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if not can_review_payment(
            request.user,
            payment,
        ):
            return Response(
                {
                    "detail": (
                        "Aap is clinic ki payment reject "
                        "nahi kar sakte."
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        reason = str(
            request.data.get(
                "reason",
                "",
            )
        ).strip()

        if not reason:
            return Response(
                {
                    "reason": (
                        "Payment reject karne ka reason "
                        "zaroori hai."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if (
            payment.status
            == Payment.PaymentStatus.VERIFIED
        ):
            return Response(
                {
                    "detail": (
                        "Verified payment directly reject "
                        "nahi ho sakti."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if (
            payment.status
            == Payment.PaymentStatus.REFUNDED
        ):
            return Response(
                {
                    "detail": (
                        "Refunded payment reject nahi "
                        "ho sakti."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        payment.status = (
            Payment.PaymentStatus.REJECTED
        )

        payment.rejection_reason = reason
        payment.verified_by = request.user
        payment.verified_at = timezone.now()
        payment.paid_at = None

        payment.save(
            update_fields=(
                "status",
                "rejection_reason",
                "verified_by",
                "verified_at",
                "paid_at",
                "updated_at",
            )
        )

        create_payment_notification(
            payment=payment,
            notification_type=(
                Notification
                .NotificationType
                .PAYMENT_REJECTED
            ),
            title="Payment Rejected",
            message=(
                f"Payment for "
                f"{payment.appointment.appointment_reference} "
                f"was rejected. Reason: {reason}"
            ),
        )

        serializer = PaymentSerializer(
            payment,
            context={
                "request": request,
            },
        )

        return Response(
            {
                "message": "Payment rejected.",
                "payment": serializer.data,
            },
            status=status.HTTP_200_OK,
        )