# DoctorLive Backend

DoctorLive is a Django REST Framework backend for finding verified specialist doctors, checking availability, booking appointments, submitting consultation fees, attending online consultations, receiving prescriptions, and managing appointment reminders.

## Main Features

- Patient and doctor accounts with token authentication
- Role-based patient, doctor, clinic staff, and administrator permissions
- Verified doctors, specialties, clinics, and live doctor status
- Doctor availability slots, appointment tokens, cancellation, and rescheduling
- Clinic visit, video consultation, and audio consultation support
- Bank transfer, JazzCash, Easypaisa, and cash payment records
- Payment proof submission and staff/admin verification
- Consultations, prescriptions, medicines, and medical documents
- Notifications and appointment reminders
- Patient and doctor dashboard APIs
- API root and database health endpoint
- Django administration panel
- Automated test suite: 53 passing tests

## Technology

- Python 3.13
- Django 6.1.1
- Django REST Framework 3.18.1
- SQLite for local development
- DRF token authentication
- Pillow for uploaded images
- python-dotenv for local environment variables

## Project Setup

### 1. Create and activate the virtual environment

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### 2. Install dependencies

```powershell
python -m pip install -r requirements.txt
```

### 3. Create the local environment file

Create `.env` in the same directory as `manage.py`:

```env
DJANGO_SECRET_KEY=your-private-random-secret-key
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=127.0.0.1,localhost

EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-google-app-password
DEFAULT_FROM_EMAIL=DoctorLive <your-email@gmail.com>
```

Never commit `.env`. Keep only placeholder values in `.env.example`.

Generate a Django secret key with:

```powershell
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

### 4. Apply database migrations

```powershell
python manage.py migrate
```

### 5. Create an administrator

```powershell
python manage.py createsuperuser
```

### 6. Run the development server

```powershell
python manage.py runserver
```

Open:

- API root: `http://127.0.0.1:8000/api/`
- Health check: `http://127.0.0.1:8000/api/health/`
- Administration: `http://127.0.0.1:8000/admin/`

## Important API Groups

| Module | Base endpoint |
|---|---|
| Accounts | `/api/accounts/` |
| Doctors | `/api/doctors/` |
| Specialties | `/api/doctors/specialties/` |
| Clinics | `/api/doctors/clinics/` |
| Appointments | `/api/appointments/` |
| Payments | `/api/payments/` |
| Consultations | `/api/consultations/` |
| Prescriptions | `/api/consultations/prescriptions/` |
| Consultation sessions | `/api/consultations/sessions/` |
| Medical documents | `/api/consultations/medical-document/` |
| Notifications | `/api/notifications/` |
| Patient dashboard | `/api/dashboard/patient/` |
| Doctor dashboard | `/api/dashboard/doctor/` |

The live API root contains the current detailed endpoint map.

## Authentication

Login returns a DRF token. Send it with protected requests:

```http
Authorization: Token YOUR_TOKEN
```

Demo credentials, when demo data has been created:

```text
Doctor: dr_ahmed / Doctor@123
Patient: demo_patient / Patient@123
```

Change demo passwords before any public deployment.

## Tests

Run all automated tests:

```powershell
python manage.py test
```

Current verified result:

```text
Found 53 test(s).
Ran 53 tests
OK
```

Additional checks:

```powershell
python manage.py makemigrations --check --dry-run
python manage.py migrate
python manage.py check
```

## Email Test

After adding real Gmail SMTP details and a Google App Password to `.env`:

```powershell
python manage.py shell
```

```python
from django.core.mail import send_mail

send_mail(
    subject="DoctorLive Email Test",
    message="DoctorLive email configuration is working.",
    from_email=None,
    recipient_list=["your-receiving-email@gmail.com"],
    fail_silently=False,
)
```

A successful send returns `1`.

## Security Notes

- Never commit `.env`, the SQLite database, uploaded medical files, or credentials.
- Use a new random secret key for production.
- Set `DJANGO_DEBUG=False` in production.
- Configure the real production hostname in `DJANGO_ALLOWED_HOSTS`.
- Serve the production application through HTTPS.
- Enable secure cookies and HSTS only after HTTPS is correctly configured.
- Use PostgreSQL and production-grade object storage for a real deployment.
- Change all demo passwords before deployment.

## Backend Status

The DoctorLive backend feature implementation, migrations, API checks, permissions, and automated tests are complete. Production deployment and the mobile/web frontend are separate project phases.
