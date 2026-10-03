from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient


class CoreAPITests(TestCase):
    """
    DoctorLive API root aur health endpoint ke automated tests.
    """

    def setUp(self):
        """
        Har test se pehle API client create hoga.
        """
        self.client = APIClient()

    def test_api_root_is_available(self):
        """
        API root successful response return kare.
        """
        response = self.client.get("/api/")

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )
        self.assertTrue(response.data["success"])
        self.assertEqual(
            response.data["project"],
            "DoctorLive",
        )
        self.assertIn("endpoints", response.data)

    def test_health_check_is_available(self):
        """
        Health endpoint server aur database status return kare.
        """
        response = self.client.get("/api/health/")

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )
        self.assertTrue(response.data["success"])
        self.assertEqual(
            response.data["status"],
            "healthy",
        )
        self.assertEqual(
            response.data["database"],
            "connected",
        )

    def test_unknown_endpoint_returns_404(self):
        """
        Invalid API URL ko 404 return karna chahiye.
        """
        response = self.client.get("/api/not-existing/")

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )