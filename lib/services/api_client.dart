import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/app_provider_container.dart';
import '../data/auth_provider.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final List<dynamic>? details;

  ApiException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.details,
  });

  @override
  String toString() => message;
}

class ApiClient {
  static final http.Client _client = http.Client();
  static Future<String?>? _refreshInFlight;

  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query);
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    String? bearerToken,
  }) async {
    final response = await _sendWithAuthRetry(
      bearerToken: bearerToken,
      send: (token) => _client.get(
        _uri(path, query),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    final response = await _sendWithAuthRetry(
      bearerToken: bearerToken,
      send: (token) => _client.post(
        _uri(path),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    final response = await _sendWithAuthRetry(
      bearerToken: bearerToken,
      send: (token) => _client.put(
        _uri(path),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fileField,
    required List<int> fileBytes,
    required String fileName,
    Map<String, String>? fields,
    String? bearerToken,
  }) async {
    try {
      final response = await _sendWithAuthRetry(
        bearerToken: bearerToken,
        send: (token) async {
          final request = http.MultipartRequest('POST', _uri(path))
            ..headers.addAll({
              if (token != null) 'Authorization': 'Bearer $token',
            })
            ..fields.addAll(fields ?? const <String, String>{})
            ..files.add(
              http.MultipartFile.fromBytes(
                fileField,
                fileBytes,
                filename: fileName,
              ),
            );

          final streamedResponse =
              await _client.send(request).timeout(const Duration(seconds: 12));
          return http.Response.fromStream(streamedResponse);
        },
      );
      return _decode(response);
    } on SocketException {
      throw ApiException(
        'Cannot reach ${AppConfig.apiBaseUrl}. '
        '${AppConfig.localApiTroubleshootingHint}',
        errorCode: 'NETWORK_ERROR',
      );
    } on http.ClientException {
      throw ApiException(
        'Request to ${AppConfig.apiBaseUrl} failed before the backend responded. '
        '${AppConfig.localApiTroubleshootingHint}',
        errorCode: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      throw ApiException(
        'Request to ${AppConfig.apiBaseUrl} timed out. '
        '${AppConfig.localApiTroubleshootingHint}',
        errorCode: 'NETWORK_TIMEOUT',
      );
    }
  }

  static Future<void> delete(
    String path, {
    String? bearerToken,
  }) async {
    final response = await _sendWithAuthRetry(
      bearerToken: bearerToken,
      send: (token) => _client.delete(
        _uri(path),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _extractApiException(response);
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw _extractApiException(response);
  }

  static ApiException _extractApiException(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        return ApiException(
          error,
          statusCode: response.statusCode,
        );
      }
      if (error is Map<String, dynamic> && error['message'] is String) {
        return ApiException(
          error['message'] as String,
          statusCode: response.statusCode,
          errorCode: error['code'] as String?,
          details: error['details'] as List<dynamic>?,
        );
      }
    } catch (_) {
      // Ignore parse errors and return fallback.
    }
    return ApiException(
      'Request failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  static Future<http.Response> _safeRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(const Duration(seconds: 12));
    } on SocketException {
      throw ApiException(
        'Cannot reach ${AppConfig.apiBaseUrl}. '
        '${AppConfig.localApiTroubleshootingHint}',
        errorCode: 'NETWORK_ERROR',
      );
    } on http.ClientException {
      throw ApiException(
        'Request to ${AppConfig.apiBaseUrl} failed before the backend responded. '
        '${AppConfig.localApiTroubleshootingHint}',
        errorCode: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      throw ApiException(
        'Request to ${AppConfig.apiBaseUrl} timed out. '
        '${AppConfig.localApiTroubleshootingHint}',
        errorCode: 'NETWORK_TIMEOUT',
      );
    }
  }

  static Future<http.Response> _sendWithAuthRetry({
    required Future<http.Response> Function(String? token) send,
    String? bearerToken,
  }) async {
    final response = await _safeRequest(() => send(bearerToken));
    if (response.statusCode != 401 ||
        bearerToken == null ||
        bearerToken.isEmpty) {
      return response;
    }

    final refreshedToken = await _refreshAccessToken();
    if (refreshedToken == null || refreshedToken.isEmpty) {
      return response;
    }

    return _safeRequest(() => send(refreshedToken));
  }

  static Future<String?> _refreshAccessToken() async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }

    final future = _performRefresh();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  static Future<String?> _performRefresh() async {
    final session = appProviderContainer.read(authProvider).value;
    final refreshToken = session?.refreshToken;
    final currentUser = session?.user;

    if (refreshToken == null || refreshToken.isEmpty || currentUser == null) {
      return null;
    }

    try {
      final response = await _safeRequest(
        () => _client.post(
          _uri('/api/v1/auth/refresh'),
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'refreshToken': refreshToken,
          }),
        ),
      );

      final payload = _decode(response);
      final data = payload['data'] as Map<String, dynamic>? ?? const {};
      final nextAccessToken = data['accessToken'] as String?;
      final nextRefreshToken = data['refreshToken'] as String?;

      if (nextAccessToken == null ||
          nextAccessToken.isEmpty ||
          nextRefreshToken == null ||
          nextRefreshToken.isEmpty) {
        throw ApiException('Missing auth tokens');
      }

      appProviderContainer.read(authProvider.notifier).setSession(
            access: nextAccessToken,
            refresh: nextRefreshToken,
            currentUser: currentUser,
          );

      return nextAccessToken;
    } catch (_) {
      await appProviderContainer.read(authProvider.notifier).clear();
      return null;
    }
  }
}
