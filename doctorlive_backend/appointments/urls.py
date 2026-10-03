from django.urls import path

from .views import (
    AppointmentDetailView,
    AppointmentListCreateView,
    AppointmentRescheduleView,
    BookDoctorSlotView,
    CancelAppointmentView,
    DoctorAppointmentStatusView,
    DoctorAvailabilitySlotListCreateView,
)


app_name = "appointments"


urlpatterns = [
    path(
        "",
        AppointmentListCreateView.as_view(),
        name="appointment-list-create",
    ),
    path(
        "slots/",
        DoctorAvailabilitySlotListCreateView.as_view(),
        name="doctor-slot-list-create",
    ),
    path(
        "slots/<int:pk>/book/",
        BookDoctorSlotView.as_view(),
        name="doctor-slot-book",
    ),
    path(
        "<int:pk>/cancel/",
        CancelAppointmentView.as_view(),
        name="appointment-cancel",
    ),
    path(
        "<int:pk>/reschedule/",
        AppointmentRescheduleView.as_view(),
        name="appointment-reschedule",
    ),
    path(
        "<int:pk>/status/",
        DoctorAppointmentStatusView.as_view(),
        name="doctor-appointment-status",
    ),
    path(
        "<int:pk>/",
        AppointmentDetailView.as_view(),
        name="appointment-detail",
    ),
]
