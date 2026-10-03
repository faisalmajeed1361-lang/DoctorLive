import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Patient aur clinic staff ki payment API operations manage karega.
class PaymentService {
  PaymentService({AuthService? authService, http.Client? client})
    : _authService = authService ?? AuthService(),
      _client = client ?? http.Client();

  final AuthService _authService;
  final http.Client _client;

  /// Clinic staff/admin payment list endpoint.
  String get _adminPaymentsUrl {
    return '${ApiConfig.payments}admin/';
  }

  /// Saved authentication token return karega.
  Future<String> _requireToken() async {
    final String? token = await _authService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Login session expire ho chuka hai. '
        'Dobara login karein.',
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

  /// Logged-in patient ki payment history load karega.
  Future<List<Map<String, dynamic>>> getPayments() {
    return _getList(ApiConfig.payments);
  }

  /// Selected clinic ke active receiving accounts load karega.
  ///
  /// Example:
  /// /api/payments/accounts/?clinic=2
  Future<List<Map<String, dynamic>>> getPaymentAccounts({
    required int clinicId,
  }) {
    final Uri uri = Uri.parse(
      ApiConfig.paymentAccounts,
    ).replace(queryParameters: <String, String>{'clinic': clinicId.toString()});

    return _getList(uri.toString());
  }

  /// Clinic staff/admin ke liye authorized payments load karega.
  ///
  /// Status optional hai:
  /// submitted, pending, verified, rejected
  Future<List<Map<String, dynamic>>> getAdminPayments({String status = ''}) {
    final Uri uri = Uri.parse(_adminPaymentsUrl).replace(
      queryParameters: status.trim().isEmpty
          ? null
          : <String, String>{'status': status.trim()},
    );

    return _getList(uri.toString());
  }

  /// Patient cash ya digital payment submit karega.
  Future<Map<String, dynamic>> submitPayment({
    required int appointmentId,
    required String paymentMethod,
    int? paymentAccountId,
    String transactionReference = '',
    String? paymentProofPath,
  }) async {
    final String token = await _requireToken();

    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.payments),
    );

    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      'Authorization': 'Token $token',
    });

    request.fields.addAll(<String, String>{
      'appointment': appointmentId.toString(),
      'payment_method': paymentMethod,
    });

    final bool isCashPayment = paymentMethod == 'cash';

    // Digital payment mein clinic receiving account required hai.
    if (!isCashPayment && paymentAccountId != null) {
      request.fields['payment_account'] = paymentAccountId.toString();
    }

    // Digital payment transaction reference.
    if (!isCashPayment && transactionReference.trim().isNotEmpty) {
      request.fields['transaction_reference'] = transactionReference.trim();
    }

    // Payment screenshot request ke saath upload hoga.
    if (!isCashPayment &&
        paymentProofPath != null &&
        paymentProofPath.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('payment_proof', paymentProofPath),
      );
    }

    final http.StreamedResponse streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
    );

    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );

    final dynamic decodedBody = _decodeResponse(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decodedBody is Map) {
        return Map<String, dynamic>.from(decodedBody);
      }

      return <String, dynamic>{};
    }

    throw Exception(_extractErrorMessage(decodedBody, response.statusCode));
  }

  /// Clinic staff selected payment verify karega.
  Future<Map<String, dynamic>> verifyPayment({required int paymentId}) {
    return _post('${ApiConfig.payments}$paymentId/verify/');
  }

  /// Clinic staff selected payment reject karega.
  Future<Map<String, dynamic>> rejectPayment({
    required int paymentId,
    required String reason,
  }) {
    if (reason.trim().isEmpty) {
      throw Exception('Payment reject karne ka reason required hai.');
    }

    return _post(
      '${ApiConfig.payments}$paymentId/reject/',
      body: <String, dynamic>{'reason': reason.trim()},
    );
  }

  /// Authenticated GET list request.
  Future<List<Map<String, dynamic>>> _getList(String url) async {
    final http.Response response = await _client
        .get(Uri.parse(url), headers: await _headers())
        .timeout(const Duration(seconds: 20));

    final dynamic decodedBody = _decodeResponse(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _extractList(decodedBody);
    }

    throw Exception(_extractErrorMessage(decodedBody, response.statusCode));
  }

  /// Authenticated POST request.
  Future<Map<String, dynamic>> _post(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final http.Response response = await _client
        .post(
          Uri.parse(url),
          headers: await _headers(json: true),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(const Duration(seconds: 20));

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

  /// Paginated aur direct list response handle karega.
  List<Map<String, dynamic>> _extractList(dynamic decodedBody) {
    final dynamic source = decodedBody is Map
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

  /// Backend validation errors readable banayega.
  String _extractErrorMessage(dynamic decodedBody, int statusCode) {
    if (decodedBody is Map) {
      final dynamic directMessage =
          decodedBody['detail'] ??
          decodedBody['message'] ??
          decodedBody['error'];

      if (directMessage != null) {
        return directMessage.toString();
      }

      if (decodedBody.isNotEmpty) {
        return decodedBody.entries
            .map((dynamic entry) {
              final String field = _fieldTitle(entry.key.toString());

              final dynamic value = entry.value;

              if (value is List) {
                return '$field: '
                    '${value.join(', ')}';
              }

              return '$field: $value';
            })
            .join('\n');
      }
    }

    return 'Payment request complete nahi ho saki. '
        'HTTP $statusCode';
  }

  /// Backend field name readable title mein convert karega.
  String _fieldTitle(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .map((String word) {
          if (word.isEmpty) {
            return word;
          }

          return '${word[0].toUpperCase()}'
              '${word.substring(1)}';
        })
        .join(' ');
  }
}
