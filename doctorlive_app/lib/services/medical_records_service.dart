import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Patient prescriptions aur medical documents backend se load karega.
class MedicalRecordsService {
  MedicalRecordsService({http.Client? client, AuthService? authService})
    : _client = client ?? http.Client(),
      _authService = authService ?? AuthService();

  final http.Client _client;
  final AuthService _authService;

  /// Logged-in patient ki prescriptions return karega.
  Future<List<Map<String, dynamic>>> getPrescriptions() async {
    return _getList('${ApiConfig.baseUrl}/api/consultations/prescriptions/');
  }

  /// Logged-in patient ke medical documents return karega.
  Future<List<Map<String, dynamic>>> getMedicalDocuments() async {
    return _getList(
      '${ApiConfig.baseUrl}/api/consultations/medical-documents/',
    );
  }

  /// Patient ka PDF/JPG/PNG medical document multipart request se upload karega.
  Future<Map<String, dynamic>> uploadMedicalDocument({
    required int appointmentId,
    required String title,
    required String documentType,
    required String fileName,
    required String notes,
    String? filePath,
    Uint8List? fileBytes,
  }) async {
    final String? token = await _authService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Login session expired. Please login again.');
    }

    if ((filePath == null || filePath.isEmpty) && fileBytes == null) {
      throw Exception('Selected file could not be read.');
    }

    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/consultations/medical-documents/'),
    );

    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      'Authorization': 'Token $token',
    });

    request.fields.addAll(<String, String>{
      // Document ko selected appointment aur uske doctor ke saath link karega.
      'appointment': appointmentId.toString(),
      'title': title.trim(),
      'document_type': documentType,
      'notes': notes.trim(),
    });

    request.files.add(
      fileBytes != null
          ? http.MultipartFile.fromBytes('file', fileBytes, filename: fileName)
          : await http.MultipartFile.fromPath(
              'file',
              filePath!,
              filename: fileName,
            ),
    );

    final http.StreamedResponse streamedResponse = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));
    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );
    final dynamic decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    }

    throw Exception(_extractError(decoded));
  }

  /// Token ke sath generic authenticated list request send karega.
  Future<List<Map<String, dynamic>>> _getList(String url) async {
    final String? token = await _authService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Login session expire ho gayi hai. Dobara login karein.');
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

    final dynamic decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _extractList(decoded);
    }

    throw Exception(_extractError(decoded));
  }

  /// Paginated aur normal API responses dono ko list mein convert karega.
  List<Map<String, dynamic>> _extractList(dynamic decoded) {
    final dynamic source = decoded is Map<String, dynamic>
        ? decoded['results'] ?? decoded['data'] ?? <dynamic>[]
        : decoded;

    if (source is! List) {
      return <Map<String, dynamic>>[];
    }

    return source
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Backend validation/detail message ko readable text mein convert karega.
  String _extractError(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final dynamic detail =
          decoded['detail'] ?? decoded['message'] ?? decoded['error'];

      if (detail != null) {
        return detail.toString();
      }

      if (decoded.isNotEmpty) {
        return decoded.values.first.toString();
      }
    }

    return 'Medical records load nahi ho sake.';
  }
}
