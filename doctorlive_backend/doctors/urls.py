from django.urls import path

from .views import (
    ClinicListView,
    DoctorDetailView,
    DoctorListView,
    SpecialtyListView,
    LiveDoctorNextTokenView,
    LiveDoctorResetQueueView,
    LiveDoctorStatusDetailView,
    MyLiveDoctorStatusView,
)



app_name = "doctors"


urlpatterns = [
    path(
        "specialties/",
        SpecialtyListView.as_view(),
        name="specialty-list",
    ),
    path(
        "clinics/",
        ClinicListView.as_view(),
        name="clinic-list",
    ),
    path(
        "",
        DoctorListView.as_view(),
        name="doctor-list",
    ),
    path(
        "<int:pk>/",
        DoctorDetailView.as_view(),
        name="doctor-detail",
    ),
    path(
    "live-status/<int:doctor_clinic_id>/",
    LiveDoctorStatusDetailView.as_view(),
    name="live-doctor-status-detail",
),
path(
    "live-status/<int:doctor_clinic_id>/next-token/",
    LiveDoctorNextTokenView.as_view(),
    name="live-doctor-next-token",
),
path(
    "live-status/<int:doctor_clinic_id>/reset-queue/",
    LiveDoctorResetQueueView.as_view(),
    name="live-doctor-reset-queue",
),
path(
    "live-status/me/",
    MyLiveDoctorStatusView.as_view(),
    name="my-live-doctor-status",
),
]