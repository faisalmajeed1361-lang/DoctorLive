from django.db import connection
from django.utils import timezone

from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView


class HealthCheckView(APIView):
    """
    Check API server and database availability.
    """

    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        database_status = "connected"

        try:
            # Execute a simple database query.
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()

        except Exception:
            database_status = "disconnected"

        is_healthy = database_status == "connected"

        return Response(
            {
                "success": is_healthy,
                "service": "DoctorLive API",
                "status": (
                    "healthy"
                    if is_healthy
                    else "unhealthy"
                ),
                "database": database_status,
                "timestamp": timezone.now(),
            },
            status=200 if is_healthy else 503,
        )


class APIRootView(APIView):
    """
    Return DoctorLive API modules and endpoint information.
    """

    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        base_url = request.build_absolute_uri("/api/")

        return Response({
            "success": True,
            "project": "DoctorLive",
            "description": (
                "Online doctor availability, appointment, "
                "payment and consultation API."
            ),
            "version": "1.0.0",
            "base_url": base_url,
            "endpoints": {
                "accounts": {
                    "register": "/api/accounts/register/",
                    "login": "/api/accounts/login/",
                    "profile": "/api/accounts/profile/",
                    "logout": "/api/accounts/logout/",
                },
                "doctors": {
                    "list": "/api/doctors/",
                    "specialties": (
                        "/api/doctors/specialties/"
                    ),
                    "clinics": "/api/doctors/clinics/",
                },
                "appointments": {
                    "list_create": "/api/appointments/",
                    "available_slots": (
                        "/api/appointments/slots/"
                    ),
                    "book_slot": (
                        "/api/appointments/slots/{id}/book/"
                    ),
                    "cancel": (
                        "/api/appointments/{id}/cancel/"
                    ),
                    "reschedule": (
                        "/api/appointments/{id}/reschedule/"
                    ),
                },
                "payments": {
                    "accounts": "/api/payments/accounts/",
                    "list_create": "/api/payments/",
                    "verify": "/api/payments/{id}/verify/",
                    "reject": "/api/payments/{id}/reject/",
                },
                "consultations": {
                    "list_create": "/api/consultations/",
                    "prescriptions": (
                        "/api/consultations/prescriptions/"
                    ),
                    "sessions": (
                        "/api/consultations/sessions/"
                    ),
                    "medical_documents": (
                        "/api/consultations/medical-documents/"
                    ),
                },
                "notifications": {
                    "list": "/api/notifications/",
                    "unread_count": (
                        "/api/notifications/unread-count/"
                    ),
                    "mark_all_read": (
                        "/api/notifications/mark-all-read/"
                    ),
                    "reminders": (
                        "/api/notifications/reminders/"
                    ),
                },
                "dashboard": {
                    "patient": "/api/dashboard/patient/",
                    "doctor": "/api/dashboard/doctor/",
                },
                "system": {
                    "health": "/api/health/",
                    "admin": "/admin/",
                },
            },
        })