from django.contrib.auth.models import User

from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import UserProfile


class AccountAPITests(APITestCase):
    """
    Accounts, authentication, profile aur logout API tests.
    """

    def setUp(self):
        """
        Har test se pehle patient aur doctor accounts create karega.
        """

        # Patient user create karein.
        self.patient_user = User.objects.create_user(
            username="test_patient",
            email="patient@test.com",
            password="Patient@123",
            first_name="Test",
            last_name="Patient",
        )

        # Patient profile create ya retrieve karein.
        self.patient_profile, created = (
            UserProfile.objects.get_or_create(
                user=self.patient_user,
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
            user=self.patient_user,
        ).update(
            role="patient",
        )

        # Updated patient objects database se reload karein.
        self.patient_user.refresh_from_db()

        self.patient_profile = UserProfile.objects.get(
            user=self.patient_user,
        )

        # Doctor user create karein.
        self.doctor_user = User.objects.create_user(
            username="test_doctor",
            email="doctor@test.com",
            password="Doctor@123",
            first_name="Test",
            last_name="Doctor",
        )

        # Doctor profile create ya retrieve karein.
        self.doctor_profile, created = (
            UserProfile.objects.get_or_create(
                user=self.doctor_user,
                defaults={
                    "role": "doctor",
                    "phone_number": "03002222222",
                    "city": "Khanpur",
                    "address": "Hospital Road, Khanpur",
                },
            )
        )

        # Signal se profile pehle create hui ho to role update karein.
        UserProfile.objects.filter(
            user=self.doctor_user,
        ).update(
            role="doctor",
        )

        # Updated doctor objects database se reload karein.
        self.doctor_user.refresh_from_db()

        self.doctor_profile = UserProfile.objects.get(
            user=self.doctor_user,
        )

        # Accounts endpoint paths.
        self.login_url = "/api/accounts/login/"
        self.profile_url = "/api/accounts/profile/"
        self.logout_url = "/api/accounts/logout/"

    def test_patient_login_successful(self):
        """
        Patient correct credentials ke sath login kar sake.
        """

        response = self.client.post(
            self.login_url,
            {
                "username": "test_patient",
                "password": "Patient@123",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        self.assertIn("token", response.data)
        self.assertIn("user", response.data)

        self.assertEqual(
            response.data["user"]["username"],
            "test_patient",
        )

        self.assertEqual(
            response.data["user"]["role"],
            "patient",
        )

    def test_doctor_login_successful(self):
        """
        Doctor correct credentials ke sath login kar sake.
        """

        response = self.client.post(
            self.login_url,
            {
                "username": "test_doctor",
                "password": "Doctor@123",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        self.assertIn("token", response.data)
        self.assertIn("user", response.data)

        self.assertEqual(
            response.data["user"]["username"],
            "test_doctor",
        )

        self.assertEqual(
            response.data["user"]["role"],
            "doctor",
        )

    def test_login_with_wrong_password_fails(self):
        """
        Wrong password ke sath login reject hona chahiye.
        """

        response = self.client.post(
            self.login_url,
            {
                "username": "test_patient",
                "password": "WrongPassword",
            },
            format="json",
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_400_BAD_REQUEST,
                status.HTTP_401_UNAUTHORIZED,
            ],
        )

        self.assertNotIn("token", response.data)

    def test_login_requires_username(self):
        """
        Username ke baghair login validation error return kare.
        """

        response = self.client.post(
            self.login_url,
            {
                "password": "Patient@123",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

    def test_login_requires_password(self):
        """
        Password ke baghair login validation error return kare.
        """

        response = self.client.post(
            self.login_url,
            {
                "username": "test_patient",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

    def test_profile_requires_authentication(self):
        """
        Anonymous user profile access na kar sake.
        """

        response = self.client.get(
            self.profile_url,
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
            ],
        )

    def test_authenticated_patient_can_view_profile(self):
        """
        Patient authentication ke baad apna profile dekh sake.
        """

        token, created = Token.objects.get_or_create(
            user=self.patient_user,
        )

        self.client.credentials(
            HTTP_AUTHORIZATION=f"Token {token.key}",
        )

        response = self.client.get(
            self.profile_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

    def test_authenticated_doctor_can_view_profile(self):
        """
        Doctor authentication ke baad apna profile dekh sake.
        """

        token, created = Token.objects.get_or_create(
            user=self.doctor_user,
        )

        self.client.credentials(
            HTTP_AUTHORIZATION=f"Token {token.key}",
        )

        response = self.client.get(
            self.profile_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

    def test_logout_removes_authentication_token(self):
        """
        Logout current authentication token delete kare.
        """

        token, created = Token.objects.get_or_create(
            user=self.patient_user,
        )

        self.client.credentials(
            HTTP_AUTHORIZATION=f"Token {token.key}",
        )

        response = self.client.post(
            self.logout_url,
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

        self.assertFalse(
            Token.objects.filter(
                key=token.key,
            ).exists()
        )