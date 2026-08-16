import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../providers/storage_providers.dart';
import 'auth_events.dart';

class DioClient {
  Dio create({
    required String baseUrl,
    FlutterSecureStorage? storage,
    AuthEventBus? authEvents,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (storage != null) {
      dio.interceptors.add(_AuthInterceptor(storage, authEvents));
    }

    dio.interceptors.add(
      PrettyDioLogger(requestBody: true, responseBody: true, compact: true),
    );

    return dio;
  }
}

/// Attaches the bearer token and turns a rejected token into a global logout.
///
/// The 401 handling deliberately SKIPS the auth endpoints: `verify-otp`
/// answers a wrong OTP with 401, and treating that as "session expired" would
/// wipe state and bounce the user mid-login instead of showing "Invalid OTP".
class _AuthInterceptor extends Interceptor {
  const _AuthInterceptor(this._storage, this._authEvents);

  final FlutterSecureStorage _storage;
  final AuthEventBus? _authEvents;

  /// Requests that legitimately return 401 as a *validation* answer rather
  /// than an expired-session signal.
  static const _authPaths = '/auth/';

  /// Background/telemetry calls that must NEVER sign the user out.
  ///
  /// FCM registration fires right after login and is not user-visible; if it
  /// fails the app still works perfectly, so treating its 401 as an expired
  /// session would boot a user with a perfectly valid token.
  static const _nonCriticalPaths = <String>['/fcm-token'];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: tokenKey);
    if (token != null) {
      options.headers['authorization'] = token;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    final isAuthCall = path.contains(_authPaths);
    final isNonCritical = _nonCriticalPaths.any(path.contains);
    final isRejectedToken = status == 401 || status == 403;

    if (isRejectedToken && !isAuthCall && !isNonCritical) {
      // Clear the dead token immediately so no in-flight retry re-sends it and
      // so a cold start cannot restore a session the server already rejected.
      await _storage.delete(key: tokenKey);
      await _storage.delete(key: userDataKey);
      _authEvents?.sessionExpired(_messageFor(err));
    }

    handler.next(err);
  }

  String _messageFor(DioException err) {
    final data = err.response?.data;
    if (data is Map && data['message'] is String) {
      final msg = data['message'] as String;
      if (msg.trim().isNotEmpty) return msg;
    }
    return 'Your session has expired. Please log in again.';
  }
}
