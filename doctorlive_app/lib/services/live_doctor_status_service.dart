import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Doctor ki live availability aur clinic queue manage karega.
class LiveDoctorStatusService {
  LiveDoctorStatusService({AuthService? authService, http.Client? client})
    : _authService = authService ?? AuthService(),
      _client = client ?? http.Client();

  final AuthService _authService;
  final http.Client _client;

  /// Logged-in doctor ka active clinic live-status URL.
  String get _myLiveStatusUrl {
    return '${ApiConfig.baseUrl}/api/doctors/live-status/me/';
  }

  /// Selected doctor-clinic ka live-status URL.
  String _liveStatusUrl(int doctorClinicId) {
    return '${ApiConfig.baseUrl}/api/doctors/'
        'live-status/$doctorClinicId/';
  }

  /// Selected doctor-clinic ka next-token URL.
  String _nextTokenUrl(int doctorClinicId) {
    return '${ApiConfig.baseUrl}/api/doctors/'
        'live-status/$doctorClinicId/next-token/';
  }

  /// Selected doctor-clinic ka reset-queue URL.
  String _resetQueueUrl(int doctorClinicId) {
    return '${ApiConfig.baseUrl}/api/doctors/'
        'live-status/$doctorClinicId/reset-queue/';
  }

  /// Saved authentication token lazmi return karega.
  Future<String> _requireToken() async {
    final String? token = await _authService.getToken();

    if (token == null || token.trim().isEmpty) {
      throw Exception(
        'Login session expire ho chuka hai. Dobara login karein.',
      );
    }

    return token;
  }

  /// Authenticated request headers return karega.
  Future<Map<String, String>> _headers({bool json = false}) async {
    final String token = await _requireToken();

    return <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };
  }

  /// Logged-in doctor ka active clinic aur live status load karega.
  ///
  /// Is request ko appointment response ki doctor-clinic ID ki zaroorat
  /// nahi hai. Backend authenticated doctor se clinic khud resolve karega.
  Future<Map<String, dynamic>> getMyLiveStatus() async {
    final http.Response response = await _client
        .get(Uri.parse(_myLiveStatusUrl), headers: await _headers())
        .timeout(const Duration(seconds: 20));

    return _handleMapResponse(response);
  }

  /// Selected doctor-clinic ka current live status load karega.
  Future<Map<String, dynamic>> getLiveStatus({
    required int doctorClinicId,
  }) async {
    final http.Response response = await _client
        .get(
          Uri.parse(_liveStatusUrl(doctorClinicId)),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));

    return _handleMapResponse(response);
  }

  /// Doctor/receptionist live availability update karega.
  Future<Map<String, dynamic>> updateLiveStatus({
    required int doctorClinicId,
    required String status,
    required int currentToken,
    String statusNote = '',
    DateTime? expectedReturnAt,
  }) async {
    final Map<String, dynamic> requestBody = <String, dynamic>{
      'status': status,
      'current_token': currentToken,
      'status_note': statusNote.trim(),
      'expected_return_at': expectedReturnAt?.toIso8601String(),
    };

    final http.Response response = await _client
        .patch(
          Uri.parse(_liveStatusUrl(doctorClinicId)),
          headers: await _headers(json: true),
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 20));

    return _handleMapResponse(response);
  }

  /// Current queue ko next token par move karega.
  Future<Map<String, dynamic>> moveToNextToken({
    required int doctorClinicId,
  }) async {
    return _postWithoutData(_nextTokenUrl(doctorClinicId));
  }

  /// New shift/day ke liye current token zero karega.
  Future<Map<String, dynamic>> resetQueue({required int doctorClinicId}) async {
    return _postWithoutData(_resetQueueUrl(doctorClinicId));
  }

  /// Empty JSON POST request ka shared implementation.
  Future<Map<String, dynamic>> _postWithoutData(String url) async {
    final http.Response response = await _client
        .post(
          Uri.parse(url),
          headers: await _headers(json: true),
          body: jsonEncode(<String, dynamic>{}),
        )
        .timeout(const Duration(seconds: 20));

    return _handleMapResponse(response);
  }

  /// Successful response return karega aur failed response ko readable
  /// exception mein convert karega.
  Map<String, dynamic> _handleMapResponse(http.Response response) {
    final dynamic decodedBody = _decodeResponse(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decodedBody is Map) {
        return Map<String, dynamic>.from(decodedBody);
      }

      return <String, dynamic>{};
    }

    throw Exception(_extractErrorMessage(decodedBody, response.statusCode));
  }

  /// Empty ya invalid response safely decode karega.
  dynamic _decodeResponse(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(body);
    } on FormatException {
      return <String, dynamic>{'detail': body};
    }
  }

  /// Backend error ko readable message mein convert karega.
  String _extractErrorMessage(dynamic decodedBody, int statusCode) {
    if (decodedBody is Map) {
      final dynamic directMessage =
          decodedBody['detail'] ??
          decodedBody['message'] ??
          decodedBody['error'];

      if (directMessage != null) {
        return directMessage.toString();
      }

      final dynamic nestedErrors = decodedBody['errors'];

      if (nestedErrors is Map && nestedErrors.isNotEmpty) {
        return nestedErrors.entries
            .map((dynamic entry) {
              return '${_fieldTitle(entry.key.toString())}: '
                  '${_readValue(entry.value)}';
            })
            .join('\n');
      }

      if (decodedBody.isNotEmpty) {
        return decodedBody.entries
            .map((dynamic entry) {
              return '${_fieldTitle(entry.key.toString())}: '
                  '${_readValue(entry.value)}';
            })
            .join('\n');
      }
    }

    return 'Live status request complete nahi ho saki. HTTP $statusCode';
  }

  /// Backend list aur normal values readable banayega.
  String _readValue(dynamic value) {
    if (value is List) {
      return value.join(', ');
    }

    return value.toString();
  }

  /// Backend field name ko readable title banayega.
  String _fieldTitle(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .map((String word) {
          if (word.isEmpty) {
            return word;
          }

          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  /// HTTP client resources release karega.
  void dispose() {
    _client.close();
  }
}
