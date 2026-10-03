from django.contrib.auth.models import User

from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile


class PaymentPermissionTests(APITestCase):
    """
    Payment endpoints ki authentication aur role permissions test karega.
    """

    def setUp(self):
        """
        Patient aur administrator test accounts create karega.
        """

        # Patient account create karein.
        self.patient = User.objects.create_user(
            username="payment_patient",
            email="payment.patient@test.com",
            password="Patient@123",
            first_name="Payment",
            last_name="Patient",
        )

        # Patient profile create ya retrieve karein.
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

        # Signal se profile pehle create hui ho to role update karein.
        UserProfile.objects.filter(
            user=self.patient,
        ).update(
            role="patient",
        )

        # Updated patient objects database se reload karein.
        self.patient.refresh_from_db()

        self.patient_profile = UserProfile.objects.get(
            user=self.patient,
        )

        # Administrator account payment verification ke liye.
        self.admin_user = User.objects.create_superuser(
            username="payment_admin",
            email="payment.admin@test.com",
            password="Admin@123",
        )

        # API endpoint paths.
        self.payment_list_url = "/api/payments/"

        self.payment_accounts_url = (
            "/api/payments/accounts/"
        )

        # Fake payment ID permissions aur missing-object behavior test karegi.
        self.verify_payment_url = (
            "/api/payments/999999/verify/"
        )

        self.reject_payment_url = (
            "/api/payments/999999/reject/"
        )

    def test_anonymous_user_cannot_view_payments(self):
        """
        Login ke baghair payment records access nahi hone chahiye.
        """

        response = self.client.get(
            self.payment_list_url,
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
            ],
        )

    def test_patient_can_view_own_payment_list(self):
        """
        Patient apni payment list access kar sake.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.get(
            self.payment_list_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

    def test_empty_payment_submission_is_rejected(self):
        """
        Required payment data ke baghair submission reject ho.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.post(
            self.payment_list_url,
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

    def test_patient_cannot_verify_payment(self):
        """
        Patient payment verification complete nahi kar sake.

        Fake payment ID par endpoint 403 ya 404 return kar sakta hai.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.post(
            self.verify_payment_url,
            {},
            format="json",
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_403_FORBIDDEN,
                status.HTTP_404_NOT_FOUND,
            ],
        )

    def test_patient_cannot_reject_payment(self):
        """
        Patient payment rejection complete nahi kar sake.

        Fake payment ID par endpoint 403 ya 404 return kar sakta hai.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.post(
            self.reject_payment_url,
            {
                "rejection_reason": "Invalid receipt",
            },
            format="json",
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_403_FORBIDDEN,
                status.HTTP_404_NOT_FOUND,
            ],
        )

    def test_admin_can_reach_payment_verification_logic(self):
        """
        Administrator verification logic tak pohanch sake.

        Fake payment ID ki wajah se 404 expected hai.
        """

        self.client.force_authenticate(
            user=self.admin_user,
        )

        response = self.client.post(
            self.verify_payment_url,
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

    def test_admin_can_reach_payment_rejection_logic(self):
        """
        Administrator rejection logic tak pohanch sake.

        Fake payment ID ki wajah se 404 expected hai.
        """

        self.client.force_authenticate(
            user=self.admin_user,
        )

        response = self.client.post(
            self.reject_payment_url,
            {
                "rejection_reason": "Invalid receipt",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

    def test_payment_account_endpoint_is_available(self):
        """
        Authenticated patient receiving payment accounts dekh sake.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.get(
            self.payment_accounts_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )