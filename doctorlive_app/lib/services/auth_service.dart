import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Backend authentication aur local session manage karega.
class AuthService {
  /// Username aur password ke through login request send karega.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final http.Response response = await http
        .post(
          Uri.parse(ApiConfig.login),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'username': username.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 20));

    dynamic decodedBody;

    try {
      decodedBody = jsonDecode(response.body);
    } on FormatException {
      decodedBody = <String, dynamic>{'detail': response.body};
    }

    final Map<String, dynamic> responseData = decodedBody is Map
        ? Map<String, dynamic>.from(decodedBody)
        : <String, dynamic>{};

    if (response.statusCode == 200) {
      final String token = responseData['token']?.toString() ?? '';

      final Map<String, dynamic> user = responseData['user'] is Map
          ? Map<String, dynamic>.from(responseData['user'] as Map)
          : <String, dynamic>{};

      if (token.isEmpty) {
        throw Exception(
          'Backend response mein authentication token nahi mila.',
        );
      }

      await _saveSession(token: token, user: user);

      return responseData;
    }

    final String message =
        responseData['detail']?.toString() ??
        responseData['message']?.toString() ??
        responseData['error']?.toString() ??
        'Username ya password incorrect hai.';

    throw Exception(message);
  }

  /// Authentication token aur user data locally save karega.
  Future<void> _saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.setString('auth_token', token);

    await preferences.setString('username', user['username']?.toString() ?? '');

    await preferences.setString(
      'user_role',
      user['role']?.toString() ?? 'patient',
    );

    await preferences.setString(
      'full_name',
      <String>[
        user['first_name']?.toString() ?? '',
        user['last_name']?.toString() ?? '',
      ].where((String value) => value.trim().isNotEmpty).join(' '),
    );
  }

  /// Saved authentication token return karega.
  Future<String?> getToken() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    return preferences.getString('auth_token');
  }

  /// Saved user role return karega.
  Future<String?> getUserRole() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    return preferences.getString('user_role');
  }

  /// Backend token invalidate karke local session clear karega.
  Future<void> logout() async {
    final String? token = await getToken();

    try {
      if (token != null && token.isNotEmpty) {
        await http
            .post(
              Uri.parse(ApiConfig.logout),
              headers: <String, String>{
                'Accept': 'application/json',
                'Authorization': 'Token $token',
              },
            )
            .timeout(const Duration(seconds: 20));
      }
    } catch (_) {
      // Backend unavailable ho tab bhi local session clear hoga.
    } finally {
      await clearSession();
    }
  }

  /// Local session remove karega.
  Future<void> clearSession() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.remove('auth_token');
    await preferences.remove('username');
    await preferences.remove('user_role');
    await preferences.remove('full_name');
  }
}
