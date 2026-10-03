from django.contrib.auth.models import User

from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile


class DashboardPermissionTests(APITestCase):
    """
    Patient aur doctor dashboard ki role permissions test karega.
    """

    def setUp(self):
        """
        Patient aur doctor test accounts create karega.
        """

        # Patient user create karein.
        self.patient = User.objects.create_user(
            username="dashboard_patient",
            email="dashboard.patient@test.com",
            password="Patient@123",
            first_name="Dashboard",
            last_name="Patient",
        )

        # Patient profile create ya update karein.
        self.patient_profile, created = (
            UserProfile.objects.get_or_create(
                user=self.patient,
                defaults={
                    "role": "patient",
                    "phone_number": "03001111111",
                    "city": "Khanpur",
                    "address": "Model Town, Khanpur",
                },
            )
        )

        if not created:
            self.patient_profile.role = "patient"
            self.patient_profile.save()

        # Doctor user create karein.
        self.doctor = User.objects.create_user(
            username="dashboard_doctor",
            email="dashboard.doctor@test.com",
            password="Doctor@123",
            first_name="Dashboard",
            last_name="Doctor",
        )

        # Doctor profile create ya update karein.
        self.doctor_profile, created = (
            UserProfile.objects.get_or_create(
                user=self.doctor,
                defaults={
                    "role": "doctor",
                    "phone_number": "03002222222",
                    "city": "Khanpur",
                    "address": "Hospital Road, Khanpur",
                },
            )
        )

        if not created:
            self.doctor_profile.role = "doctor"
            self.doctor_profile.save()

        # Dashboard endpoint paths.
        self.patient_dashboard_url = (
            "/api/dashboard/patient/"
        )
        self.doctor_dashboard_url = (
            "/api/dashboard/doctor/"
        )

    def test_anonymous_cannot_view_patient_dashboard(self):
        """
        Login ke baghair patient dashboard access nahi hona chahiye.
        """

        response = self.client.get(
            self.patient_dashboard_url,
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
            ],
        )

    def test_anonymous_cannot_view_doctor_dashboard(self):
        """
        Login ke baghair doctor dashboard access nahi hona chahiye.
        """

        response = self.client.get(
            self.doctor_dashboard_url,
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
            ],
        )

    def test_patient_can_view_patient_dashboard(self):
        """
        Patient apna dashboard access kar sake.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.get(
            self.patient_dashboard_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        self.assertIn("user", response.data)
        self.assertIn("statistics", response.data)
        self.assertIn(
            "recent_appointments",
            response.data,
        )

        self.assertEqual(
            response.data["user"]["username"],
            "dashboard_patient",
        )

    def test_patient_cannot_view_doctor_dashboard(self):
        """
        Patient doctor dashboard access nahi kar sake.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.get(
            self.doctor_dashboard_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_doctor_can_view_doctor_dashboard(self):
        """
        Doctor apna dashboard access kar sake.
        """

        self.client.force_authenticate(
            user=self.doctor,
        )

        response = self.client.get(
            self.doctor_dashboard_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        self.assertIn("doctor", response.data)
        self.assertIn("statistics", response.data)
        self.assertIn(
            "upcoming_patient_appointments",
            response.data,
        )

        self.assertEqual(
            response.data["doctor"]["username"],
            "dashboard_doctor",
        )

    def test_doctor_cannot_view_patient_dashboard(self):
        """
        Doctor patient dashboard access nahi kar sake.
        """

        self.client.force_authenticate(
            user=self.doctor,
        )

        response = self.client.get(
            self.patient_dashboard_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_patient_dashboard_statistics_are_available(self):
        """
        Patient dashboard ke required statistics return hone chahiye.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.get(
            self.patient_dashboard_url,
        )

        statistics = response.data["statistics"]

        required_fields = [
            "total_appointments",
            "upcoming_appointments",
            "completed_appointments",
            "cancelled_appointments",
            "verified_payments",
            "pending_payments",
            "prescriptions",
            "medical_documents",
            "unread_notifications",
        ]

        for field in required_fields:
            self.assertIn(field, statistics)

    def test_doctor_dashboard_statistics_are_available(self):
        """
        Doctor dashboard ke required statistics return hone chahiye.
        """

        self.client.force_authenticate(
            user=self.doctor,
        )

        response = self.client.get(
            self.doctor_dashboard_url,
        )

        statistics = response.data["statistics"]

        required_fields = [
            "total_appointments",
            "today_appointments",
            "upcoming_appointments",
            "completed_appointments",
            "cancelled_appointments",
            "consultations_completed",
            "prescriptions_created",
            "active_sessions",
            "unread_notifications",
        ]

        for field in required_fields:
            self.assertIn(field, statistics)