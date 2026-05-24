import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../providers/storage_providers.dart';

class DioClient {
  Dio create({required String baseUrl, FlutterSecureStorage? storage}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (storage != null) {
      dio.interceptors.add(_AuthInterceptor(storage));
    }

    dio.interceptors.add(
      PrettyDioLogger(requestBody: true, responseBody: true, compact: true),
    );

    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  const _AuthInterceptor(this._storage);
  final FlutterSecureStorage _storage;

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
}
