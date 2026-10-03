/// DoctorLive backend API configuration.
class ApiConfig {
  ApiConfig._();

  /// Backend URL build time par set hoga.
  ///
  /// Local development mein default URL use hoga. Release build mein:
  /// --dart-define=DOCTORLIVE_API_BASE_URL=https://your-api.example.com
  static const String baseUrl = String.fromEnvironment(
    'DOCTORLIVE_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Account endpoints.
  static const String login = '$baseUrl/api/accounts/login/';
  static const String register = '$baseUrl/api/accounts/register/';
  static const String profile = '$baseUrl/api/accounts/profile/';
  static const String logout = '$baseUrl/api/accounts/logout/';

  /// Doctor endpoints.
  static const String doctors = '$baseUrl/api/doctors/';
  static const String specialties = '$baseUrl/api/doctors/specialties/';
  static const String clinics = '$baseUrl/api/doctors/clinics/';

  //// Appointment endpoints.
  static const String appointments = '$baseUrl/api/appointments/';

  /// Payment endpoints.
  static const String payments = '$baseUrl/api/payments/';

  static const String paymentAccounts = '$baseUrl/api/payments/accounts/';

  /// API health endpoint.
  static const String health = '$baseUrl/api/health/';
}
