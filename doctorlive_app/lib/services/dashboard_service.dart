import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Patient aur doctor dashboard APIs manage karega.
class DashboardService {
  /// Logged-in patient ka dashboard data return karega.
  Future<Map<String, dynamic>> getPatientDashboard() async {
    return _getDashboardData('${ApiConfig.baseUrl}/api/dashboard/patient/');
  }

  /// Logged-in doctor ka dashboard data return karega.
  Future<Map<String, dynamic>> getDoctorDashboard() async {
    return _getDashboardData('${ApiConfig.baseUrl}/api/dashboard/doctor/');
  }

  /// Token ke sath protected dashboard request send karega.
  Future<Map<String, dynamic>> _getDashboardData(String url) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String token = preferences.getString('auth_token') ?? '';

    if (token.isEmpty) {
      throw Exception('Login session nahi mili. Please login again.');
    }

    final http.Response response = await http
        .get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Token $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decodedBody = jsonDecode(response.body);

    final Map<String, dynamic> responseData =
        decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};

    if (response.statusCode == 200) {
      return responseData;
    }

    final String message =
        responseData['detail']?.toString() ??
        responseData['message']?.toString() ??
        'Dashboard data load nahi ho saka.';

    throw Exception(message);
  }
}
