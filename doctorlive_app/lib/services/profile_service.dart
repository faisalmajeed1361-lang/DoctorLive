import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Patient aur doctor ki account profile API requests manage karega.
class ProfileService {
  ProfileService({http.Client? client, AuthService? authService})
    : _client = client ?? http.Client(),
      _authService = authService ?? AuthService();

  final http.Client _client;
  final AuthService _authService;

  String get _profileUrl => '${ApiConfig.baseUrl}/api/accounts/profile/';

  /// Valid login token return karega.
  Future<String> _requireToken() async {
    final String? token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Login session expired. Please login again.');
    }
    return token;
  }

  /// Current logged-in user ki profile load karega.
  Future<Map<String, dynamic>> getProfile() async {
    final String token = await _requireToken();
    final http.Response response = await _client
        .get(
          Uri.parse(_profileUrl),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Token $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decoded = _decode(response.body);
    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded));
  }

  /// Text fields aur optional profile image multipart PATCH se save karega.
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String city,
    required String address,
    required String qualification,
    String? imagePath,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final String token = await _requireToken();
    final http.MultipartRequest request = http.MultipartRequest(
      'PATCH',
      Uri.parse(_profileUrl),
    );

    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      'Authorization': 'Token $token',
    });
    request.fields.addAll(<String, String>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim(),
      'phone_number': phoneNumber.trim(),
      'city': city.trim(),
      'address': address.trim(),
      'qualification': qualification.trim(),
    });

    if (imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'profile_image',
          imageBytes,
          filename: imageName ?? 'profile.jpg',
        ),
      );
    } else if (imagePath != null && imagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_image',
          imagePath,
          filename: imageName,
        ),
      );
    }

    final http.StreamedResponse streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));
    final http.Response response = await http.Response.fromStream(streamed);
    final dynamic decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic user = decoded is Map ? decoded['user'] : null;
      return user is Map
          ? Map<String, dynamic>.from(user)
          : <String, dynamic>{};
    }
    throw Exception(_error(decoded));
  }

  dynamic _decode(String body) {
    return body.trim().isEmpty ? <String, dynamic>{} : jsonDecode(body);
  }

  /// Backend validation response ko readable message banayega.
  String _error(dynamic decoded) {
    if (decoded is Map) {
      final dynamic direct =
          decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      if (direct != null) {
        return direct.toString();
      }
      if (decoded.isNotEmpty) {
        final dynamic value = decoded.values.first;
        return value is List ? value.join(', ') : value.toString();
      }
    }
    return 'Profile request complete nahi ho saki.';
  }
}
