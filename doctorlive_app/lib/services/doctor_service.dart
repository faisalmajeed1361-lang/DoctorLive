import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Doctor search aur verified doctor list API requests manage karega.
class DoctorService {
  DoctorService({AuthService? authService, http.Client? client})
    : _authService = authService ?? AuthService(),
      _client = client ?? http.Client();

  final AuthService _authService;
  final http.Client _client;

  /// Active hospitals aur clinics ki list return karega.
  Future<List<Map<String, dynamic>>> getClinics() async {
    return _getAuthenticatedList('${ApiConfig.baseUrl}/api/doctors/clinics/');
  }

  /// Available doctor specialties ki list return karega.
  Future<List<Map<String, dynamic>>> getSpecialties() async {
    return _getAuthenticatedList(
      '${ApiConfig.baseUrl}/api/doctors/specialties/',
    );
  }

  /// Selected city, hospital, specialty aur availability ke mutabiq
  /// verified doctors backend se load karega.
  Future<List<Map<String, dynamic>>> getDoctors({
    String city = '',
    String hospital = '',
    String specialty = '',
    bool availableOnly = false,
  }) async {
    final String? token = await _authService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Login session expire ho chuka hai. Dobara login karein.',
      );
    }

    // Sirf selected filters request URL mein add karega.
    final Map<String, String> queryParameters = <String, String>{};

    if (city.trim().isNotEmpty) {
      queryParameters['city'] = city.trim();
    }

    if (hospital.trim().isNotEmpty) {
      // Backend clinic ko hospital/clinic filter ke taur par use karta hai.
      queryParameters['clinic'] = hospital.trim();
    }

    if (specialty.trim().isNotEmpty) {
      queryParameters['specialty'] = specialty.trim();
    }

    if (availableOnly) {
      queryParameters['available'] = 'true';
    }

    final Uri baseUri = Uri.parse(ApiConfig.doctors);
    final Uri requestUri = baseUri.replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final http.Response response = await _client
        .get(
          requestUri,
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Token $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decodedBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _extractDoctors(decodedBody);
    }

    throw Exception(_extractError(decodedBody));
  }

  /// Clinics aur specialties ke liye reusable authenticated GET request.
  Future<List<Map<String, dynamic>>> _getAuthenticatedList(String url) async {
    final String? token = await _authService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Login session expire ho chuka hai. Dobara login karein.',
      );
    }

    final http.Response response = await _client
        .get(
          Uri.parse(url),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Token $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decodedBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _extractDoctors(decodedBody);
    }

    throw Exception(_extractError(decodedBody));
  }

  /// Paginated aur non-paginated doctor responses handle karega.
  List<Map<String, dynamic>> _extractDoctors(dynamic decodedBody) {
    final dynamic source = decodedBody is Map<String, dynamic>
        ? decodedBody['results'] ?? decodedBody['data'] ?? <dynamic>[]
        : decodedBody;

    if (source is! List) {
      return <Map<String, dynamic>>[];
    }

    return source
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Backend ka readable error message return karega.
  String _extractError(dynamic decodedBody) {
    if (decodedBody is Map<String, dynamic>) {
      final dynamic message = decodedBody['detail'] ?? decodedBody['message'];

      if (message != null) {
        return message.toString();
      }
    }

    return 'Doctors load nahi ho sake.';
  }
}
