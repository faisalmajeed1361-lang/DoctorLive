from django.contrib import admin
from django.urls import include, path


urlpatterns = [
    path("admin/", admin.site.urls),
    path("api-auth/", include("rest_framework.urls")),

    path("api/", include("core.urls")),
    path("api/accounts/", include("accounts.urls")),
    path("api/doctors/", include("doctors.urls")),
    path("api/appointments/", include("appointments.urls")),
    path("api/payments/", include("payments.urls")),
    path(
        "api/consultations/",
        include("consultations.urls"),
    ),
    path(
        "api/notifications/",
        include("notifications.urls"),
    ),
    path(
        "api/dashboard/",
        include("dashboard.urls"),
    ),
]
