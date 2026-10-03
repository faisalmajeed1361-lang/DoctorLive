import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Patient aur doctor appointment API operations manage karega.
class AppointmentService {
  AppointmentService({AuthService? authService, http.Client? client})
    : _authService = authService ?? AuthService(),
      _client = client ?? http.Client();

  final AuthService _authService;
  final http.Client _client;

  Future<String> _requireToken() async {
    final String? token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Login session expired. Please login again.');
    }
    return token;
  }

  /// Logged-in patient ya doctor ki appointments load karega.
  /// Logged-in patient ya doctor ki tamam paginated
  /// appointments backend se load karega.
  Future<List<Map<String, dynamic>>> getAppointments() async {
    final String token = await _requireToken();

    final List<Map<String, dynamic>> allAppointments = <Map<String, dynamic>>[];

    final Set<String> visitedUrls = <String>{};

    String? nextUrl = ApiConfig.appointments;

    while (nextUrl != null && nextUrl.isNotEmpty) {
      // Infinite pagination loop se protection.
      if (visitedUrls.contains(nextUrl)) {
        break;
      }

      visitedUrls.add(nextUrl);

      final http.Response response = await http
          .get(
            Uri.parse(nextUrl),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Token $token',
            },
          )
          .timeout(const Duration(seconds: 20));

      final dynamic decodedBody = _decodeBody(response.body);

      if (response.statusCode != 200) {
        throw Exception(_extractErrorMessage(decodedBody, response.statusCode));
      }

      allAppointments.addAll(_extractList(decodedBody));

      // DRF paginated response ka next page URL.
      if (decodedBody is Map &&
          decodedBody['next'] != null &&
          decodedBody['next'].toString().trim().isNotEmpty) {
        final String returnedNext = decodedBody['next'].toString();

        final Uri nextUri = Uri.parse(returnedNext);

        if (nextUri.hasScheme) {
          nextUrl = returnedNext;
        } else {
          nextUrl = Uri.parse(
            ApiConfig.baseUrl,
          ).resolve(returnedNext).toString();
        }
      } else {
        nextUrl = null;
      }
    }

    return allAppointments;
  }

  /// New appointment backend mein create karega.
  Future<Map<String, dynamic>> createAppointment({
    required int doctorClinicId,
    required DateTime appointmentDate,
    required String appointmentTime,
    required String consultationMode,
    required String symptomSummary,
  }) {
    final String formattedDate =
        '${appointmentDate.year.toString().padLeft(4, '0')}-'
        '${appointmentDate.month.toString().padLeft(2, '0')}-'
        '${appointmentDate.day.toString().padLeft(2, '0')}';

    return _post(
      url: ApiConfig.appointments,
      body: <String, dynamic>{
        'doctor_clinic': doctorClinicId,
        'appointment_date': formattedDate,
        'appointment_time': appointmentTime,
        'consultation_mode': consultationMode,
        'symptoms_summary': symptomSummary.trim(),
      },
      acceptedStatusCodes: <int>{200, 201},
    );
  }

  Future<Map<String, dynamic>> cancelAppointment({
    required int appointmentId,
    required String cancellationReason,
  }) {
    return _post(
      url: '${ApiConfig.appointments}$appointmentId/cancel/',
      body: <String, dynamic>{'cancellation_reason': cancellationReason.trim()},
      acceptedStatusCodes: <int>{200, 202},
    );
  }

  Future<Map<String, dynamic>> updateDoctorAppointmentStatus({
    required int appointmentId,
    required String newStatus,
  }) {
    return _post(
      url: '${ApiConfig.appointments}$appointmentId/status/',
      body: <String, dynamic>{'status': newStatus},
      acceptedStatusCodes: <int>{200},
    );
  }

  Future<Map<String, dynamic>> _post({
    required String url,
    required Map<String, dynamic> body,
    required Set<int> acceptedStatusCodes,
  }) async {
    final http.Response response = await _send(
      () async => _client.post(
        Uri.parse(url),
        headers: await _headers(json: true),
        body: jsonEncode(body),
      ),
    );

    final dynamic decoded = _decodeBody(response.body);
    if (acceptedStatusCodes.contains(response.statusCode)) {
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    }

    throw Exception(_extractErrorMessage(response, decoded));
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final String token = await _requireToken();
    return <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };
  }

  /// Network errors ko user-friendly aur testable messages mein convert karega.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Server response timed out. Please try again.');
    } on SocketException {
      throw Exception('Backend server is not reachable.');
    } on http.ClientException catch (error) {
      throw Exception('Network request failed: ${error.message}');
    }
  }

  dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } on FormatException {
      return <String, dynamic>{'raw_response': body};
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic decoded) {
    final dynamic source = decoded is Map
        ? decoded['results'] ?? decoded['data'] ?? <dynamic>[]
        : decoded;
    if (source is! List) return <Map<String, dynamic>>[];
    return source
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// DRF ke nested field/non-field errors ko readable text mein flatten karega.
  String _extractErrorMessage(http.Response response, dynamic decoded) {
    final List<String> messages = <String>[];
    _flattenErrors(decoded, messages);

    if (messages.isNotEmpty) {
      return messages.join('\n');
    }

    return 'Appointment request failed (HTTP ${response.statusCode}).';
  }

  void _flattenErrors(dynamic value, List<String> output, {String? field}) {
    if (value == null) return;

    if (value is Map) {
      value.forEach((dynamic key, dynamic item) {
        final String keyText = key.toString();
        final String? nextField =
            <String>{
              'detail',
              'message',
              'error',
              'non_field_errors',
              'raw_response',
            }.contains(keyText)
            ? field
            : _fieldTitle(keyText);
        _flattenErrors(item, output, field: nextField);
      });
      return;
    }

    if (value is List) {
      for (final dynamic item in value) {
        _flattenErrors(item, output, field: field);
      }
      return;
    }

    final String message = value.toString().trim();
    if (message.isEmpty) return;
    output.add(field == null ? message : '$field: $message');
  }

  String _fieldTitle(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (String word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}
