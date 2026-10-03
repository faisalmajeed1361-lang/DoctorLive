import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Consultation reports, prescriptions and online sessions ki API service.
class ConsultationService {
  ConsultationService({AuthService? authService, http.Client? client})
    : _authService = authService ?? AuthService(),
      _client = client ?? http.Client();

  final AuthService _authService;
  final http.Client _client;

  String get _consultationsUrl => '${ApiConfig.baseUrl}/api/consultations/';

  String get _prescriptionsUrl =>
      '${ApiConfig.baseUrl}/api/consultations/prescriptions/';

  String get _sessionsUrl => '${ApiConfig.baseUrl}/api/consultations/sessions/';

  /// Appointment ki consultation return karega, warna null.
  Future<Map<String, dynamic>?> getConsultationForAppointment(
    int appointmentId,
  ) async {
    final List<Map<String, dynamic>> consultations = await _getList(
      _consultationsUrl,
    );

    for (final Map<String, dynamic> consultation in consultations) {
      if (_relatedId(consultation['appointment']) == appointmentId) {
        return consultation;
      }
    }

    return null;
  }

  /// Doctor consultation report create karega.
  Future<Map<String, dynamic>> createConsultation({
    required int appointmentId,
    required String diagnosis,
    required String symptoms,
    required String clinicalNotes,
    required String recommendedTests,
    required String medicalAdvice,
    required bool followUpRequired,
    DateTime? followUpDate,
  }) {
    return _post(_consultationsUrl, <String, dynamic>{
      'appointment': appointmentId,
      'diagnosis': diagnosis.trim(),
      'symptoms': symptoms.trim(),
      'clinical_notes': clinicalNotes.trim(),
      'recommended_tests': recommendedTests.trim(),
      'medical_advice': medicalAdvice.trim(),
      'follow_up_required': followUpRequired,
      'follow_up_date': followUpRequired && followUpDate != null
          ? _formatDate(followUpDate)
          : null,
    });
  }

  /// Consultation ke liye prescription create karega.
  Future<Map<String, dynamic>> createPrescription({
    required int consultationId,
    required String additionalInstructions,
    required List<Map<String, String>> medicines,
  }) {
    return _post(_prescriptionsUrl, <String, dynamic>{
      'consultation': consultationId,
      'additional_instructions': additionalInstructions.trim(),
      'medicines': medicines,
    });
  }

  /// Appointment ka online session return karega, warna null.
  Future<Map<String, dynamic>?> getSessionForAppointment(
    int appointmentId,
  ) async {
    final String url = '$_sessionsUrl?appointment=$appointmentId';
    final List<Map<String, dynamic>> sessions = await _getList(url);
    return sessions.isEmpty ? null : sessions.first;
  }

  /// Doctor video ya audio session create karega.
  Future<Map<String, dynamic>> createSession({
    required int appointmentId,
    required String sessionType,
  }) {
    if (sessionType != 'video' && sessionType != 'audio') {
      throw ArgumentError('Session type must be video or audio.');
    }

    return _post(_sessionsUrl, <String, dynamic>{
      'appointment': appointmentId,
      'session_type': sessionType,
    });
  }

  /// Doctor ya patient session join karega.
  /// Response ke andar full updated session `session` key mein hoga.
  Future<Map<String, dynamic>> joinSession(int sessionId) {
    return _post('$_sessionsUrl$sessionId/join/', <String, dynamic>{});
  }

  /// Assigned doctor session end karega.
  Future<Map<String, dynamic>> endSession(int sessionId) {
    return _post('$_sessionsUrl$sessionId/end/', <String, dynamic>{});
  }

  Future<String> _requireToken() async {
    final String? token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Login session expired. Please login again.');
    }
    return token;
  }

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

    final dynamic decoded = _decode(response.body);
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
    throw Exception(_errorMessage(decoded));
  }

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final String token = await _requireToken();
    final http.Response response = await _client
        .post(
          Uri.parse(url),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Token $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decoded = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    }
    throw Exception(_errorMessage(decoded));
  }

  dynamic _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } on FormatException {
      return <String, dynamic>{'detail': body};
    }
  }

  int? _relatedId(dynamic value) {
    if (value is Map) {
      return int.tryParse(value['id']?.toString() ?? '');
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _errorMessage(dynamic decoded) {
    if (decoded is Map) {
      final dynamic direct =
          decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      if (direct != null) return direct.toString();
      if (decoded.isNotEmpty) {
        return decoded.entries
            .map((dynamic entry) => '${entry.key}: ${entry.value}')
            .join('\n');
      }
    }
    return 'Consultation request could not be completed.';
  }
}
