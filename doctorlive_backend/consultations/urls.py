from django.urls import path

from .views import (
    ConsultationDetailView,
    ConsultationListCreateView,
    ConsultationSessionEndView,
    ConsultationSessionJoinView,
    ConsultationSessionListCreateView,
    MedicalDocumentDetailView,
    MedicalDocumentListCreateView,
    PrescriptionDetailView,
    PrescriptionListCreateView,
)

app_name = "consultations"

urlpatterns = [
    path(
        "",
        ConsultationListCreateView.as_view(),
        name="consultation-list-create",
    ),
    path(
        "prescriptions/",
        PrescriptionListCreateView.as_view(),
        name="prescription-list-create",
    ),
    path(
        "prescriptions/<int:pk>/",
        PrescriptionDetailView.as_view(),
        name="prescription-detail",
    ),
    path(
        "sessions/",
        ConsultationSessionListCreateView.as_view(),
        name="session-list-create",
    ),
    path(
        "sessions/<int:pk>/join/",
        ConsultationSessionJoinView.as_view(),
        name="session-join",
    ),
    path(
        "sessions/<int:pk>/end/",
        ConsultationSessionEndView.as_view(),
        name="session-end",
    ),
    path(
        "medical-documents/",
        MedicalDocumentListCreateView.as_view(),
        name="medical-document-list-create",
    ),
    path(
        "medical-documents/<int:pk>/",
        MedicalDocumentDetailView.as_view(),
        name="medical-document-detail",
    ),
    path(
        "<int:pk>/",
        ConsultationDetailView.as_view(),
        name="consultation-detail",
    ),
]
