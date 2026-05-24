import 'package:dio/dio.dart';

class AuthService {
  const AuthService(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await _dio.post(
      '/api/v1/mobile/client/auth/send-otp',
      data: {'phone': phone},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final res = await _dio.post(
      '/api/v1/mobile/client/auth/verify-otp',
      data: {'phone': phone, 'otp': otp},
    );
    return res.data as Map<String, dynamic>;
  }
}
