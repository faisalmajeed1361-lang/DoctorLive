from django.urls import path

from .views import (
    AdminPaymentListView,
    PaymentAccountListView,
    PaymentDetailView,
    PaymentListCreateView,
    PaymentRejectView,
    PaymentVerifyView,
)


app_name = "payments"


urlpatterns = [
    path(
        "accounts/",
        PaymentAccountListView.as_view(),
        name="payment-account-list",
    ),
    path(
        "admin/",
        AdminPaymentListView.as_view(),
        name="admin-payment-list",
    ),
    path(
        "",
        PaymentListCreateView.as_view(),
        name="payment-list-create",
    ),
    path(
        "<int:pk>/",
        PaymentDetailView.as_view(),
        name="payment-detail",
    ),
    path(
        "<int:pk>/verify/",
        PaymentVerifyView.as_view(),
        name="payment-verify",
    ),
    path(
        "<int:pk>/reject/",
        PaymentRejectView.as_view(),
        name="payment-reject",
    ),
]