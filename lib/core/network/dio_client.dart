import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class DioClient {
  Dio create({required String baseUrl}) {
    final dio = Dio(BaseOptions(baseUrl: baseUrl));
    dio.interceptors.add(
      PrettyDioLogger(
        requestBody: true,
        responseBody: true,
      ),
    );
    return dio;
  }
}
