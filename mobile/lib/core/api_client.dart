import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';

/// Thrown by the API layer on any non-success. Carries a human message parsed
/// from the JSON:API `errors` array when present.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// The single seam to the FleetMS JSON:API. Features talk to this — never to
/// `dio` directly. It injects the bearer token and `x-organization` tenant
/// header on every request once a session + org are set.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;
  String? _token;
  String? _orgPublicId;

  /// Set after sign-in / on bootstrap; both headers flow from here.
  void setSession({String? token, String? orgPublicId}) {
    _token = token;
    _orgPublicId = orgPublicId;
  }

  void setOrg(String? orgPublicId) => _orgPublicId = orgPublicId;

  void clearSession() {
    _token = null;
    _orgPublicId = null;
  }

  /// Whether a token + tenant are set — i.e. authed requests can be made. Used by
  /// the outbox sync to avoid flushing (and getting 401s) before sign-in.
  bool get hasSession => _token != null && _orgPublicId != null;

  Map<String, dynamic> get _authHeaders => {
        if (_token != null) 'authorization': 'Bearer $_token',
        if (_orgPublicId != null) 'x-organization': _orgPublicId,
      };

  // --- JSON:API reads/writes -------------------------------------------------

  /// GET a collection → the raw response body (use `JsonApi.many`).
  Future<Map<String, dynamic>> getMany(String path,
      {Map<String, dynamic>? query}) async {
    return _send(() => _dio.get<Map<String, dynamic>>(path,
        queryParameters: query, options: _jsonApiOptions()));
  }

  /// GET one → the raw response body (use `JsonApi.one`).
  Future<Map<String, dynamic>> getOne(String path) async {
    return _send(
        () => _dio.get<Map<String, dynamic>>(path, options: _jsonApiOptions()));
  }

  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    return _send(() => _dio.post<Map<String, dynamic>>(path,
        data: body, options: _jsonApiOptions()));
  }

  Future<Map<String, dynamic>> patch(
      String path, Map<String, dynamic> body) async {
    return _send(() => _dio.patch<Map<String, dynamic>>(path,
        data: body, options: _jsonApiOptions()));
  }

  Future<void> delete(String path) async {
    await _send(() =>
        _dio.delete<Map<String, dynamic>>(path, options: _jsonApiOptions()));
  }

  // --- uploads (multipart/form-data) -----------------------------------------

  Future<Map<String, dynamic>> uploadPhoto(String filePath,
      {void Function(int, int)? onSendProgress}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    return _send(() => _dio.post<Map<String, dynamic>>(
          '/uploads',
          data: formData,
          onSendProgress: onSendProgress,
          options: Options(
            headers: {'accept': 'application/json', ..._authHeaders},
            contentType: 'multipart/form-data',
          ),
        ));
  }

  Future<void> deleteUpload(String imageKey, String thumbnailKey) async {
    await _send(() => _dio.delete<Map<String, dynamic>>(
          '/uploads',
          data: {'image_key': imageKey, 'thumbnail_key': thumbnailKey},
          options: Options(
            headers: {'accept': 'application/json', ..._authHeaders},
            contentType: 'application/json',
          ),
        ));
  }

  // --- auth (plain JSON, no token/tenant) ------------------------------------

  /// `POST /sign-in` — returns `{token, token_type, user_id, organizations}`.
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    return _send(() => _dio.post<Map<String, dynamic>>(
          '/sign-in',
          data: {'email': email, 'password': password},
          options: Options(
            headers: {'accept': 'application/json'},
            contentType: 'application/json',
          ),
        ));
  }

  Future<void> register(String email, String password) async {
    await _send(() => _dio.post<Map<String, dynamic>>(
          '/register',
          data: {
            'email': email,
            'password': password,
            'password_confirmation': password
          },
          options: Options(
            headers: {'accept': 'application/json'},
            contentType: 'application/json',
          ),
        ));
  }

  Future<void> requestPasswordReset(String email) async {
    await _send(() => _dio.post<Map<String, dynamic>>(
          '/request-password-reset',
          data: {'email': email},
          options: Options(
            headers: {'accept': 'application/json'},
            contentType: 'application/json',
          ),
        ));
  }

  Future<void> resetPassword(String token, String password) async {
    await _send(() => _dio.post<Map<String, dynamic>>(
          '/reset-password',
          data: {
            'reset_token': token,
            'password': password,
            'password_confirmation': password
          },
          options: Options(
            headers: {'accept': 'application/json'},
            contentType: 'application/json',
          ),
        ));
  }

  Options _jsonApiOptions() => Options(
        headers: {'accept': AppConfig.mediaType, ..._authHeaders},
        contentType: AppConfig.mediaType,
      );

  Future<Map<String, dynamic>> _send(
      Future<Response<Map<String, dynamic>>> Function() run) async {
    try {
      final res = await run();
      return res.data ?? const {};
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map &&
        data['errors'] is List &&
        (data['errors'] as List).isNotEmpty) {
      final first = (data['errors'] as List).first;
      if (first is Map) {
        return (first['detail'] ?? first['title'] ?? 'Request failed')
            .toString();
      }
    }
    return e.message ?? 'Network error';
  }
}

final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: '${AppConfig.baseUrl}${AppConfig.apiPrefix}',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    // Accept any status < 500 so we can map 4xx to ApiException with a message.
    validateStatus: (code) => code != null && code < 400,
  ));

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));
  }

  return dio;
});

final apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(_dioProvider)));
