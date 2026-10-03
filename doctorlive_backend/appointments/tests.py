from django.contrib.auth.models import User

from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile


class AppointmentPermissionTests(APITestCase):
    """
    Appointment endpoints ki authentication aur role permissions
    test karega.
    """

    def setUp(self):
        """
        Har test se pehle patient aur doctor accounts create honge.
        """

        # Patient user create karein.
        self.patient = User.objects.create_user(
            username="appointment_patient",
            email="appointment.patient@test.com",
            password="Patient@123",
            first_name="Appointment",
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

        # Signal profile pehle create kare to patient role update karein.
        UserProfile.objects.filter(
            user=self.patient,
        ).update(
            role="patient",
        )

        # Updated patient aur profile database se dobara load karein.
        self.patient.refresh_from_db()

        self.patient_profile = UserProfile.objects.get(
            user=self.patient,
        )

        # Doctor user create karein.
        self.doctor = User.objects.create_user(
            username="appointment_doctor",
            email="appointment.doctor@test.com",
            password="Doctor@123",
            first_name="Appointment",
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

        # Signal profile pehle create kare to doctor role update karein.
        UserProfile.objects.filter(
            user=self.doctor,
        ).update(
            role="doctor",
        )

        # Updated doctor aur profile database se dobara load karein.
        self.doctor.refresh_from_db()

        self.doctor_profile = UserProfile.objects.get(
            user=self.doctor,
        )

        # Appointment list aur booking endpoint.
        self.appointment_list_url = (
            "/api/appointments/"
        )

        # Available doctor slots endpoint.
        self.available_slots_url = (
            "/api/appointments/slots/"
        )

        # Fake IDs permission aur missing-object behavior test karenge.
        self.book_slot_url = (
            "/api/appointments/slots/999999/book/"
        )

        self.cancel_url = (
            "/api/appointments/999999/cancel/"
        )

        self.reschedule_url = (
            "/api/appointments/999999/reschedule/"
        )

        # Doctor-only appointment status endpoint.
        self.doctor_status_url = (
            "/api/appointments/999999/status/"
        )

    def test_anonymous_user_cannot_view_appointments(self):
        """
        Login ke baghair appointment list access nahi honi chahiye.
        """

        response = self.client.get(
            self.appointment_list_url,
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
            ],
        )

    def test_patient_can_view_appointment_list(self):
        """
        Patient apni appointment list access kar sake.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.get(
            self.appointment_list_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

    def test_doctor_can_view_appointment_list(self):
        """
        Doctor apne patients ki appointment list access kar sake.
        """

        self.client.force_authenticate(
            user=self.doctor,
        )

        response = self.client.get(
            self.appointment_list_url,
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

    def test_patient_empty_booking_data_is_rejected(self):
        """
        Required booking data ke baghair appointment reject ho.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.post(
            self.appointment_list_url,
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

    def test_available_slots_endpoint_responds(self):
        """
        Available-slots endpoint valid response return kare.

        Endpoint project configuration ke mutabiq public ya protected
        ho sakta hai.
        """

        response = self.client.get(
            self.available_slots_url,
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_200_OK,
                status.HTTP_400_BAD_REQUEST,
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
            ],
        )

    def test_doctor_cannot_book_patient_slot(self):
        """
        Doctor patient-only slot booking action perform na kar sake.
        """

        self.client.force_authenticate(
            user=self.doctor,
        )

        response = self.client.post(
            self.book_slot_url,
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_patient_can_reach_slot_booking_logic(self):
        """
        Patient slot booking permission pass kare.

        Fake slot ID ki wajah se 404 expected hai.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.post(
            self.book_slot_url,
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

    def test_doctor_cannot_cancel_patient_appointment(self):
        """
        Doctor patient-only cancellation action perform na kar sake.
        """

        self.client.force_authenticate(
            user=self.doctor,
        )

        response = self.client.post(
            self.cancel_url,
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_patient_can_reach_cancellation_logic(self):
        """
        Patient cancellation permission pass kare.

        Fake appointment ID ki wajah se 404 expected hai.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.post(
            self.cancel_url,
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

    def test_doctor_cannot_reschedule_patient_appointment(self):
        """
        Doctor patient-only reschedule action perform na kar sake.
        """

        self.client.force_authenticate(
            user=self.doctor,
        )

        response = self.client.post(
            self.reschedule_url,
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_patient_can_reach_reschedule_logic(self):
        """
        Patient reschedule permission pass kare.

        Fake appointment ID ki wajah se 404 expected hai.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.post(
            self.reschedule_url,
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

    def test_patient_cannot_update_doctor_appointment_status(self):
        """
        Patient doctor-only appointment status action use na kar sake.
        """

        self.client.force_authenticate(
            user=self.patient,
        )

        response = self.client.post(
            self.doctor_status_url,
            {
                "status": "checked_in",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_anonymous_user_cannot_update_appointment_status(self):
        """
        Anonymous user appointment status update na kar sake.
        """

        response = self.client.post(
            self.doctor_status_url,
            {
                "status": "checked_in",
            },
            format="json",
        )

        self.assertIn(
            response.status_code,
            [
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
            ],
        )