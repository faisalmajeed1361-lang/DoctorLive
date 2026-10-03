# DoctorLive

DoctorLive is a cross-platform telemedicine and clinic management platform developed with Flutter and Django REST Framework. It connects patients, doctors, clinic staff, and administrators through a secure role-based system.

## Core Features

- Patient, doctor, and administrator dashboards
- Doctor discovery by city and medical specialty
- Clinic, video, and audio appointment booking
- Unique daily appointment token system
- Live doctor availability and queue tracking
- Doctor availability and current-token management
- Bank transfer, JazzCash, Easypaisa, and cash payments
- Payment-proof submission and admin verification
- Printable verified-payment receipts
- Secure online consultation access
- Consultation notes and digital prescriptions
- Patient medical records and documents
- Appointment and payment notifications
- Role-based API permissions
- Persistent authenticated sessions

## Technology Stack

### Frontend

- Flutter
- Dart
- Material Design
- Shared Preferences
- HTTP
- PDF and Printing
- File and Image Picker
- URL Launcher

### Backend

- Python
- Django
- Django REST Framework
- Token Authentication
- SQLite for local development
- Pillow

## Project Structure

- `doctorlive_app/` — Flutter application
- `doctorlive_backend/` — Django REST API
- `doctorlive_backend/accounts/` — Authentication and profiles
- `doctorlive_backend/doctors/` — Doctors, clinics, specialties, and live status
- `doctorlive_backend/appointments/` — Appointment and token management
- `doctorlive_backend/payments/` — Accounts, payments, and verification
- `doctorlive_backend/consultations/` — Consultations, prescriptions, and records
- `doctorlive_backend/notifications/` — Notifications and reminders
- `doctorlive_backend/dashboard/` — Role-specific dashboard APIs

## Backend Setup

1. Open the backend directory:

       cd doctorlive_backend

2. Create and activate a virtual environment:

       python -m venv .venv
       .\.venv\Scripts\Activate.ps1

3. Install dependencies:

       pip install -r requirements.txt

4. Copy `.env.example` to `.env` and configure local values.

5. Run migrations:

       python manage.py migrate

6. Start the development server:

       python manage.py runserver

## Flutter Setup

1. Open the Flutter directory:

       cd doctorlive_app

2. Install dependencies:

       flutter pub get

3. Start the application:

       flutter run -d windows

## Testing

The backend test suite contains 55 automated tests covering authentication, appointments, payments, consultations, dashboards, notifications, and permissions.

       python manage.py test

Flutter validation:

       flutter analyze
       flutter test

## Security

- Secrets and environment variables are excluded from Git.
- Databases and virtual environments are excluded.
- Patient medical documents are never committed.
- Payment proofs are never committed.
- Payment PINs, passwords, OTPs, and secret keys are not stored.
- API access is protected through authentication and role permissions.

## Project Status

Completed and tested in October 2026.

## Developer

Developed by **Faisal Majeed**

- GitHub: https://github.com/faisalmajeed1361-lang
- Portfolio: https://faisal-majeed-ai-portfolio.faisalmajeed1361.chatgpt.site

## Disclaimer

DoctorLive is currently a portfolio and demonstration project. Production deployment requires HTTPS, a production database, secure media storage, environment-specific configuration, monitoring, and compliance review.
