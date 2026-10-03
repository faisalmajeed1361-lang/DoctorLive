from django.contrib.auth.models import User

from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile


class NotificationAPITests(APITestCase):
    """
    Notifications aur appointment reminders ke API tests.
    """

    def setUp(self):
        """
        Har test se pehle patient account create karega.
        """

        self.patient = User.objects.create_user(
            username="notification_patient",
            email="notification.patient@test.com",
            password="Patient@123",
            first_name="Notification",
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

        # Notification endpoint paths.
        self.notification_list_url = (
            "/api/notifications/"
        )
        self.unread_count_url = (
            "/api/notifications/unread-count/"
        )
        self.mark_all_read_url = (
            "/api/notifications/mark-all-read/"
        )
        self.reminder_list_url = (
            "/api/notifications/reminders/"
        )

    def test_anonymous_cannot_view_notifications(self):
        """
        Login ke baghair notifications access nahi honi chahiye.
        """

        response = self.client.get(
            self.notification_list_url,
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
            ],
        )

    def test_patient_can_view_notifications(self):
        """
        Patient apni notification list dekh sake.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.get(
            self.notification_list_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

    def test_anonymous_cannot_view_unread_count(self):
        """
        Login ke baghair unread count access nahi hona chahiye.
        """

        response = self.client.get(
            self.unread_count_url,
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
            ],
        )

    def test_patient_can_view_unread_count(self):
        """
        Patient unread notification count dekh sake.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.get(
            self.unread_count_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        # Response mein count value available honi chahiye.
        self.assertTrue(
            "unread_count" in response.data
            or "count" in response.data
        )

    def test_anonymous_cannot_mark_all_as_read(self):
        """
        Login ke baghair notifications read mark nahi honi chahiye.
        """

        response = self.client.post(
            self.mark_all_read_url,
            {},
            format="json",
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
            ],
        )

    def test_patient_can_mark_all_as_read(self):
        """
        Patient apni notifications ko read mark kar sake.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.post(
            self.mark_all_read_url,
            {},
            format="json",
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_200_OK,
                status.HTTP_204_NO_CONTENT,
            ],
        )

    def test_patient_can_view_appointment_reminders(self):
        """
        Patient apne appointment reminders dekh sake.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.get(
            self.reminder_list_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )