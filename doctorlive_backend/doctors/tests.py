from rest_framework import status
from rest_framework.test import APITestCase

from .models import Clinic, Specialty


class DoctorDirectoryAPITests(APITestCase):
    """
    Specialties, clinics aur doctor directory endpoints ke tests.
    """

    def setUp(self):
        """
        Har test se pehle specialty aur clinic demo data create hoga.
        """

        self.specialty = Specialty.objects.create(
            name="Cardiologist",
            description="Heart and cardiovascular specialist",
        )

        self.clinic = Clinic.objects.create(
            name="DoctorLive Test Hospital",
            city="Khanpur",
            area="Model Town",
            complete_address="Model Town Road, Khanpur",
            phone_number="03001234567",
            email="testclinic@example.com",
            is_verified=True,
        )

        self.doctor_list_url = "/api/doctors/"
        self.specialty_list_url = "/api/doctors/specialties/"
        self.clinic_list_url = "/api/doctors/clinics/"

    def get_results(self, response):
        """
        Paginated aur normal list responses dono support karega.
        """

        if isinstance(response.data, dict):
            return response.data.get("results", [])

        return response.data

    def test_specialty_list_is_available(self):
        """
        Specialty list endpoint successful response return kare.
        """

        response = self.client.get(self.specialty_list_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        results = self.get_results(response)

        self.assertEqual(len(results), 1)
        self.assertEqual(
            results[0]["name"],
            "Cardiologist",
        )

    def test_clinic_list_is_available(self):
        """
        Verified clinic list endpoint successful response return kare.
        """

        response = self.client.get(self.clinic_list_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        results = self.get_results(response)

        self.assertEqual(len(results), 1)
        self.assertEqual(
            results[0]["name"],
            "DoctorLive Test Hospital",
        )

    def test_clinic_can_be_filtered_by_city(self):
        """
        Clinic ko city query parameter se filter kiya ja sake.
        """

        response = self.client.get(
            self.clinic_list_url,
            {
                "city": "Khanpur",
            },
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        results = self.get_results(response)

        self.assertEqual(len(results), 1)
        self.assertEqual(
            results[0]["city"],
            "Khanpur",
        )

    def test_unknown_city_returns_empty_clinic_list(self):
        """
        Unknown city par empty clinic list return honi chahiye.
        """

        response = self.client.get(
            self.clinic_list_url,
            {
                "city": "Lahore",
            },
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        results = self.get_results(response)

        self.assertEqual(len(results), 0)

    def test_doctor_list_endpoint_is_available(self):
        """
        Doctor directory endpoint available hona chahiye.
        Doctor record create na hone ki wajah se list empty ho sakti hai.
        """

        response = self.client.get(self.doctor_list_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        results = self.get_results(response)

        self.assertIsInstance(results, list)

    def test_public_can_view_specialties(self):
        """
        Login ke baghair specialties access ki ja sakein.
        """

        response = self.client.get(self.specialty_list_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

    def test_public_can_view_verified_clinics(self):
        """
        Login ke baghair verified clinics access ki ja sakein.
        """

        response = self.client.get(self.clinic_list_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )