import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Patient aur doctor notifications ki API requests manage karega.
class NotificationService {
  NotificationService({http.Client? client, AuthService? authService})
    : _client = client ?? http.Client(),
      _authService = authService ?? AuthService();

  final http.Client _client;
  final AuthService _authService;

  String get _baseUrl => '${ApiConfig.baseUrl}/api/notifications/';

  /// Saved login token validate karke return karega.
  Future<String> _requireToken() async {
    final String? token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Login session expired. Please login again.');
    }
    return token;
  }

  /// Logged-in user ki all ya unread notifications load karega.
  Future<List<Map<String, dynamic>>> getNotifications({
    bool unreadOnly = false,
  }) async {
    final String token = await _requireToken();
    final Uri uri = Uri.parse(_baseUrl).replace(
      queryParameters: unreadOnly ? <String, String>{'unread': 'true'} : null,
    );

    final http.Response response = await _client
        .get(
          uri,
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Token $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decoded = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _extractList(decoded);
    }
    throw Exception(_extractError(decoded));
  }

  /// Dashboard badge ke liye unread notification count return karega.
  Future<int> getUnreadCount() async {
    final String token = await _requireToken();
    final http.Response response = await _client
        .get(
          Uri.parse('${_baseUrl}unread-count/'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Token $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decoded = _decode(response.body);
    if (response.statusCode == 200 && decoded is Map) {
      return int.tryParse(decoded['unread_count']?.toString() ?? '0') ?? 0;
    }
    throw Exception(_extractError(decoded));
  }

  /// Selected notification backend mein read mark karega.
  Future<Map<String, dynamic>> markAsRead(int notificationId) async {
    final String token = await _requireToken();
    final http.Response response = await _client
        .post(
          Uri.parse('$_baseUrl$notificationId/read/'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Token $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decoded = _decode(response.body);
    if (response.statusCode == 200 && decoded is Map) {
      final dynamic notification = decoded['notification'];
      return notification is Map
          ? Map<String, dynamic>.from(notification)
          : <String, dynamic>{};
    }
    throw Exception(_extractError(decoded));
  }

  /// Current user ki tamam unread notifications read mark karega.
  Future<int> markAllAsRead() async {
    final String token = await _requireToken();
    final http.Response response = await _client
        .post(
          Uri.parse('${_baseUrl}mark-all-read/'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Token $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decoded = _decode(response.body);
    if (response.statusCode == 200 && decoded is Map) {
      return int.tryParse(decoded['updated_count']?.toString() ?? '0') ?? 0;
    }
    throw Exception(_extractError(decoded));
  }

  dynamic _decode(String body) {
    return body.trim().isEmpty ? <String, dynamic>{} : jsonDecode(body);
  }

  /// Paginated aur normal list responses dono handle karega.
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

  /// Backend error response ko readable message mein convert karega.
  String _extractError(dynamic decoded) {
    if (decoded is Map) {
      final dynamic message =
          decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      if (message != null) return message.toString();
      if (decoded.isNotEmpty) return decoded.values.first.toString();
    }
    return 'Notifications request complete nahi ho saki.';
  }
}
