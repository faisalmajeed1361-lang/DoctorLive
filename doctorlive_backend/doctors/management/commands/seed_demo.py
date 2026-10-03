from datetime import time, timedelta

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import UserProfile
from appointments.models import Appointment
from doctors.models import (
    Clinic,
    DoctorClinic,
    DoctorProfile,
    LiveDoctorStatus,
    Specialty,
)


class Command(BaseCommand):
    """
    DoctorLive ke liye multiple testing records create/update karta hai.

    Yeh command idempotent hai: dobara run karne par same usernames,
    clinics aur appointments duplicate nahi honge.
    """

    help = "Create complete DoctorLive demo/testing data"

    DOCTOR_PASSWORD = "Doctor@123"
    PATIENT_PASSWORD = "Patient@123"

    def handle(self, *args, **options):
        User = get_user_model()
        today = timezone.localdate()

        # -------------------------------------------------------------
        # 1. Testing specialties
        # -------------------------------------------------------------
        specialty_rows = [
            (
                "Cardiologist",
                "Heart and cardiovascular specialist",
            ),
            (
                "Dermatologist",
                "Skin, hair and nail specialist",
            ),
            (
                "General Physician",
                "General medical care and common diseases",
            ),
            (
                "Gynecologist",
                "Women health and maternity specialist",
            ),
            (
                "Orthopedic Surgeon",
                "Bones, joints and muscles specialist",
            ),
            (
                "Pediatrician",
                "Children health specialist",
            ),
        ]

        specialties = {}

        for name, description in specialty_rows:
            specialty, _ = Specialty.objects.update_or_create(
                name=name,
                defaults={
                    "description": description,
                    "is_active": True,
                },
            )
            specialties[name] = specialty

        # -------------------------------------------------------------
        # 2. Testing hospitals and clinics
        # -------------------------------------------------------------
        clinic_rows = [
            {
                "key": "khanpur_city",
                "name": "DoctorLive City Hospital",
                "city": "Khanpur",
                "area": "Model Town",
                "address": "Model Town Road, Khanpur",
                "phone": "0300-1234567",
                "email": "cityhospital@example.com",
            },
            {
                "key": "khanpur_skin",
                "name": "Khanpur Skin Clinic",
                "city": "Khanpur",
                "area": "Satellite Town",
                "address": "Satellite Town, Khanpur",
                "phone": "0300-1234568",
                "email": "skinclinic@example.com",
            },
            {
                "key": "ryk_general",
                "name": "RYK General Hospital",
                "city": "Rahim Yar Khan",
                "area": "Hospital Road",
                "address": "Hospital Road, Rahim Yar Khan",
                "phone": "0300-1234569",
                "email": "rykgeneral@example.com",
            },
            {
                "key": "multan_women",
                "name": "Multan Women Hospital",
                "city": "Multan",
                "area": "Gulgasht Colony",
                "address": "Gulgasht Colony, Multan",
                "phone": "0300-1234570",
                "email": "womenhospital@example.com",
            },
            {
                "key": "bahawalpur_ortho",
                "name": "Bahawalpur Orthopedic Centre",
                "city": "Bahawalpur",
                "area": "Model Town A",
                "address": "Model Town A, Bahawalpur",
                "phone": "0300-1234571",
                "email": "orthocentre@example.com",
            },
            {
                "key": "khanpur_children",
                "name": "Khanpur Children Clinic",
                "city": "Khanpur",
                "area": "Shahi Road",
                "address": "Shahi Road, Khanpur",
                "phone": "0300-1234572",
                "email": "childrenclinic@example.com",
            },
        ]

        clinics = {}

        for row in clinic_rows:
            clinic, _ = Clinic.objects.update_or_create(
                name=row["name"],
                city=row["city"],
                area=row["area"],
                defaults={
                    "complete_address": row["address"],
                    "phone_number": row["phone"],
                    "email": row["email"],
                    "is_verified": True,
                    "is_active": True,
                },
            )
            clinics[row["key"]] = clinic

        # -------------------------------------------------------------
        # 3. Testing doctors, profiles and clinic assignments
        # -------------------------------------------------------------
        doctor_rows = [
            {
                "username": "dr_ahmed",
                "first_name": "Ahmed",
                "last_name": "Ali",
                "email": "ahmed.doctor@example.com",
                "phone": "0300-1111101",
                "city": "Khanpur",
                "specialty": "Cardiologist",
                "pmdc": "PMDC-DEMO-001",
                "qualification": "MBBS, FCPS Cardiology",
                "experience": 10,
                "fee": 2000,
                "languages": "Urdu, English, Punjabi",
                "clinic": "khanpur_city",
                "room": "Room 12",
                "start": time(17, 0),
                "end": time(21, 0),
            },
            {
                "username": "dr_sara",
                "first_name": "Sara",
                "last_name": "Khan",
                "email": "sara.doctor@example.com",
                "phone": "0300-1111102",
                "city": "Khanpur",
                "specialty": "Dermatologist",
                "pmdc": "PMDC-DEMO-002",
                "qualification": "MBBS, FCPS Dermatology",
                "experience": 7,
                "fee": 1800,
                "languages": "Urdu, English",
                "clinic": "khanpur_skin",
                "room": "Room 3",
                "start": time(16, 0),
                "end": time(20, 0),
            },
            {
                "username": "dr_usman",
                "first_name": "Usman",
                "last_name": "Malik",
                "email": "usman.doctor@example.com",
                "phone": "0300-1111103",
                "city": "Rahim Yar Khan",
                "specialty": "General Physician",
                "pmdc": "PMDC-DEMO-003",
                "qualification": "MBBS, MCPS Medicine",
                "experience": 9,
                "fee": 1500,
                "languages": "Urdu, English, Saraiki",
                "clinic": "ryk_general",
                "room": "Room 8",
                "start": time(9, 0),
                "end": time(14, 0),
            },
            {
                "username": "dr_hina",
                "first_name": "Hina",
                "last_name": "Fatima",
                "email": "hina.doctor@example.com",
                "phone": "0300-1111104",
                "city": "Multan",
                "specialty": "Gynecologist",
                "pmdc": "PMDC-DEMO-004",
                "qualification": "MBBS, FCPS Gynecology",
                "experience": 12,
                "fee": 2500,
                "languages": "Urdu, English, Saraiki",
                "clinic": "multan_women",
                "room": "Room 5",
                "start": time(10, 0),
                "end": time(15, 0),
            },
            {
                "username": "dr_bilal",
                "first_name": "Bilal",
                "last_name": "Hussain",
                "email": "bilal.doctor@example.com",
                "phone": "0300-1111105",
                "city": "Bahawalpur",
                "specialty": "Orthopedic Surgeon",
                "pmdc": "PMDC-DEMO-005",
                "qualification": "MBBS, FCPS Orthopedic Surgery",
                "experience": 11,
                "fee": 2200,
                "languages": "Urdu, English, Punjabi",
                "clinic": "bahawalpur_ortho",
                "room": "Room 7",
                "start": time(15, 0),
                "end": time(19, 0),
            },
            {
                "username": "dr_zain",
                "first_name": "Zain",
                "last_name": "Abbas",
                "email": "zain.doctor@example.com",
                "phone": "0300-1111106",
                "city": "Khanpur",
                "specialty": "Pediatrician",
                "pmdc": "PMDC-DEMO-006",
                "qualification": "MBBS, FCPS Pediatrics",
                "experience": 8,
                "fee": 1700,
                "languages": "Urdu, English, Punjabi",
                "clinic": "khanpur_children",
                "room": "Room 2",
                "start": time(14, 0),
                "end": time(18, 0),
            },
        ]

        doctor_users = {}
        doctor_clinics = {}

        for index, row in enumerate(doctor_rows, start=1):
            doctor_user, _ = User.objects.update_or_create(
                username=row["username"],
                defaults={
                    "first_name": row["first_name"],
                    "last_name": row["last_name"],
                    "email": row["email"],
                    "is_active": True,
                },
            )

            # Demo accounts ka password har run par known value par reset hoga.
            doctor_user.set_password(self.DOCTOR_PASSWORD)
            doctor_user.save(update_fields=["password"])

            UserProfile.objects.update_or_create(
                user=doctor_user,
                defaults={
                    "role": UserProfile.Role.DOCTOR,
                    "phone_number": row["phone"],
                    "city": row["city"],
                    "address": row["city"],
                },
            )

            doctor, _ = DoctorProfile.objects.update_or_create(
                user=doctor_user,
                defaults={
                    "specialty": specialties[row["specialty"]],
                    "full_name": (
                        f'{row["first_name"]} {row["last_name"]}'
                    ),
                    "pmdc_registration_number": row["pmdc"],
                    "qualification": row["qualification"],
                    "experience_years": row["experience"],
                    "consultation_fee": row["fee"],
                    "languages": row["languages"],
                    "bio": (
                        f'Experienced {row["specialty"].lower()} '
                        "providing clinic and online consultations."
                    ),
                    "offers_video_consultation": True,
                    "offers_audio_consultation": True,
                    "is_verified": True,
                    "is_active": True,
                },
            )

            doctor_clinic, _ = DoctorClinic.objects.update_or_create(
                doctor=doctor,
                clinic=clinics[row["clinic"]],
                defaults={
                    "room_number": row["room"],
                    "start_time": row["start"],
                    "end_time": row["end"],
                    "average_consultation_minutes": 10 + index,
                    "is_active": True,
                },
            )

            LiveDoctorStatus.objects.update_or_create(
                doctor_clinic=doctor_clinic,
                defaults={
                    "status": LiveDoctorStatus.Status.AVAILABLE,
                    "current_token": 0,
                    "status_note": "Doctor is available for consultation.",
                    "updated_by": doctor_user,
                },
            )

            doctor_users[row["username"]] = doctor_user
            doctor_clinics[row["username"]] = doctor_clinic

        # -------------------------------------------------------------
        # 4. Multiple testing patient accounts
        # -------------------------------------------------------------
        patient_rows = [
            (
                "demo_patient",
                "Demo",
                "Patient",
                "Khanpur",
                "0300-2222201",
            ),
            (
                "patient_ali",
                "Ali",
                "Raza",
                "Khanpur",
                "0300-2222202",
            ),
            (
                "patient_ayesha",
                "Ayesha",
                "Noor",
                "Rahim Yar Khan",
                "0300-2222203",
            ),
            (
                "patient_sana",
                "Sana",
                "Ahmed",
                "Multan",
                "0300-2222204",
            ),
            (
                "patient_hamza",
                "Hamza",
                "Khan",
                "Bahawalpur",
                "0300-2222205",
            ),
            (
                "patient_child",
                "Hassan",
                "Raza",
                "Khanpur",
                "0300-2222206",
            ),
        ]

        patients = {}

        for username, first_name, last_name, city, phone in patient_rows:
            patient, _ = User.objects.update_or_create(
                username=username,
                defaults={
                    "first_name": first_name,
                    "last_name": last_name,
                    "email": f"{username}@example.com",
                    "is_active": True,
                },
            )

            patient.set_password(self.PATIENT_PASSWORD)
            patient.save(update_fields=["password"])

            UserProfile.objects.update_or_create(
                user=patient,
                defaults={
                    "role": UserProfile.Role.PATIENT,
                    "phone_number": phone,
                    "city": city,
                    "address": f"Demo address, {city}",
                },
            )

            patients[username] = patient

        # -------------------------------------------------------------
        # 5. Dynamic testing appointments
        # -------------------------------------------------------------
        appointment_rows = [
            {
                "patient": "patient_ali",
                "doctor": "dr_ahmed",
                "days": 0,
                "time": time(17, 20),
                "mode": Appointment.ConsultationMode.IN_PERSON,
                "status": Appointment.AppointmentStatus.BOOKED,
                "symptoms": "Chest pain and increased heartbeat.",
            },
            {
                "patient": "patient_ayesha",
                "doctor": "dr_usman",
                "days": 0,
                "time": time(10, 30),
                "mode": Appointment.ConsultationMode.VIDEO,
                "status": Appointment.AppointmentStatus.BOOKED,
                "symptoms": "Fever, headache and weakness.",
            },
            {
                "patient": "demo_patient",
                "doctor": "dr_sara",
                "days": 1,
                "time": time(17, 0),
                "mode": Appointment.ConsultationMode.IN_PERSON,
                "status": Appointment.AppointmentStatus.BOOKED,
                "symptoms": "Skin allergy and itching.",
            },
            {
                "patient": "patient_sana",
                "doctor": "dr_hina",
                "days": 2,
                "time": time(11, 0),
                "mode": Appointment.ConsultationMode.VIDEO,
                "status": Appointment.AppointmentStatus.BOOKED,
                "symptoms": "Routine women health consultation.",
            },
            {
                "patient": "patient_hamza",
                "doctor": "dr_bilal",
                "days": -1,
                "time": time(16, 0),
                "mode": Appointment.ConsultationMode.IN_PERSON,
                "status": Appointment.AppointmentStatus.COMPLETED,
                "symptoms": "Knee pain after exercise.",
            },
            {
                "patient": "patient_child",
                "doctor": "dr_zain",
                "days": 3,
                "time": time(15, 0),
                "mode": Appointment.ConsultationMode.IN_PERSON,
                "status": Appointment.AppointmentStatus.CANCELLED,
                "symptoms": "Child fever and cough.",
                "cancellation_reason": "Patient requested cancellation.",
            },
            {
                "patient": "demo_patient",
                "doctor": "dr_ahmed",
                "days": -2,
                "time": time(18, 0),
                "mode": Appointment.ConsultationMode.IN_PERSON,
                "status": Appointment.AppointmentStatus.NO_SHOW,
                "symptoms": "Blood pressure follow-up.",
            },
        ]

        appointments = []

        for row in appointment_rows:
            appointment_date = today + timedelta(days=row["days"])
            doctor_clinic = doctor_clinics[row["doctor"]]
            patient = patients[row["patient"]]

            appointment = Appointment.objects.filter(
                patient=patient,
                doctor_clinic=doctor_clinic,
                appointment_date=appointment_date,
                appointment_time=row["time"],
            ).first()

            if appointment is None:
                appointment = Appointment.objects.create(
                    patient=patient,
                    doctor_clinic=doctor_clinic,
                    appointment_date=appointment_date,
                    appointment_time=row["time"],
                    consultation_mode=row["mode"],
                    status=row["status"],
                    symptoms_summary=row["symptoms"],
                    cancellation_reason=row.get(
                        "cancellation_reason",
                        "",
                    ),
                )
            else:
                # Existing demo appointment ko expected testing state dega.
                appointment.consultation_mode = row["mode"]
                appointment.status = row["status"]
                appointment.symptoms_summary = row["symptoms"]
                appointment.cancellation_reason = row.get(
                    "cancellation_reason",
                    "",
                )
                appointment.save()

            appointments.append(appointment)

        # -------------------------------------------------------------
        # 6. Command summary
        # -------------------------------------------------------------
        self.stdout.write(
            self.style.SUCCESS(
                "\nComplete DoctorLive testing data created successfully."
            )
        )
        self.stdout.write(f"Specialties: {len(specialties)}")
        self.stdout.write(f"Clinics: {len(clinics)}")
        self.stdout.write(f"Doctors: {len(doctor_users)}")
        self.stdout.write(f"Patients: {len(patients)}")
        self.stdout.write(f"Appointments: {len(appointments)}")

        self.stdout.write("\nDoctor password: Doctor@123")
        self.stdout.write("Patient password: Patient@123")
        self.stdout.write(
            "Doctor usernames: " + ", ".join(doctor_users.keys())
        )
        self.stdout.write(
            "Patient usernames: " + ", ".join(patients.keys())
        )
