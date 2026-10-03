import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Doctor ke patients, consultations, prescriptions aur documents load karega.
class DoctorRecordsService {
  DoctorRecordsService({http.Client? client, AuthService? authService})
    : _client = client ?? http.Client(),
      _authService = authService ?? AuthService();

  final http.Client _client;
  final AuthService _authService;

  /// Doctor ki appointment history se unique patients build karega.
  Future<List<Map<String, dynamic>>> getPatients() async {
    final List<Map<String, dynamic>> appointments = await _getList(
      ApiConfig.appointments,
    );
    final Map<String, Map<String, dynamic>> patients =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> appointment in appointments) {
      final dynamic patientValue = appointment['patient'];
      final Map<String, dynamic> patient = patientValue is Map
          ? Map<String, dynamic>.from(patientValue)
          : <String, dynamic>{};
      final String name =
          appointment['patient_name']?.toString().trim().isNotEmpty == true
          ? appointment['patient_name'].toString().trim()
          : patient['full_name']?.toString().trim().isNotEmpty == true
          ? patient['full_name'].toString().trim()
          : patient['username']?.toString() ?? 'Patient';
      final String key =
          (appointment['patient_id'] ?? patient['id'])?.toString() ??
          name.toLowerCase();
      final Map<String, dynamic> current = patients.putIfAbsent(
        key,
        () => <String, dynamic>{
          'id': appointment['patient_id'] ?? patient['id'],
          'name': name,
          'username': appointment['patient_username'] ?? patient['username'],
          'email': appointment['patient_email'] ?? patient['email'],
          'phone_number':
              appointment['patient_phone_number'] ?? patient['phone_number'],
          'city':
              appointment['patient_city'] ??
              patient['city'] ??
              appointment['clinic_city'],
          'appointment_count': 0,
          'latest_appointment': appointment,
        },
      );
      current['appointment_count'] =
          (int.tryParse(current['appointment_count'].toString()) ?? 0) + 1;

      final DateTime? oldDate = _appointmentDate(current['latest_appointment']);
      final DateTime? newDate = _appointmentDate(appointment);
      if (newDate != null && (oldDate == null || newDate.isAfter(oldDate))) {
        current['latest_appointment'] = appointment;
      }
    }

    final List<Map<String, dynamic>> result = patients.values.toList();
    result.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    return result;
  }

  /// Logged-in doctor ki consultation reports return karega.
  Future<List<Map<String, dynamic>>> getConsultations() {
    return _getList('${ApiConfig.baseUrl}/api/consultations/');
  }

  /// Logged-in doctor ki issued prescriptions return karega.
  Future<List<Map<String, dynamic>>> getPrescriptions() {
    return _getList('${ApiConfig.baseUrl}/api/consultations/prescriptions/');
  }

  /// Doctor ko accessible patient medical documents return karega.
  Future<List<Map<String, dynamic>>> getMedicalDocuments() {
    return _getList(
      '${ApiConfig.baseUrl}/api/consultations/medical-documents/',
    );
  }

  Future<String> _requireToken() async {
    final String? token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Login session expired. Please login again.');
    }
    return token;
  }

  /// Paginated aur normal authenticated list API request handle karega.
  Future<List<Map<String, dynamic>>> _getList(String url) async {
    final String token = await _requireToken();
    final http.Response response = await _client
        .get(
          Uri.parse(url),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Token $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic source = decoded is Map
          ? decoded['results'] ?? decoded['data'] ?? <dynamic>[]
          : decoded;
      if (source is! List) return <Map<String, dynamic>>[];
      return source
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList();
    }
    throw Exception(_error(decoded));
  }

  DateTime? _appointmentDate(dynamic value) {
    if (value is! Map) return null;
    return DateTime.tryParse(value['appointment_date']?.toString() ?? '');
  }

  String _error(dynamic decoded) {
    if (decoded is Map) {
      final dynamic message =
          decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      if (message != null) return message.toString();
    }
    return 'Doctor records could not be loaded.';
  }
}
