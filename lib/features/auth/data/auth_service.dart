import 'package:dio/dio.dart';

class AuthService {
  const AuthService(this._dio);
  final Dio _dio;

  /// Step 1: confirm the number (mobile number or clientId code) belongs to an
  /// active client. No SMS is sent and the response never carries the OTP —
  /// the backend verifies a fixed OTP in [verifyOtp].
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await _dio.post(
      '/api/v1/mobile/client/auth/send-otp',
      data: {'phone': phone},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Step 2: exchange the OTP for a JWT. Validity is decided server-side.
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final res = await _dio.post(
      '/api/v1/mobile/client/auth/verify-otp',
      data: {'phone': phone, 'otp': otp},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Single-step login with no OTP. The backend only mounts this route when
  /// ALLOW_NUMBER_ONLY_LOGIN=true, so it 404s in the default configuration —
  /// kept so the no-OTP flow can be switched back on from the server alone.
  Future<Map<String, dynamic>> loginWithNumber(String number) async {
    final res = await _dio.post(
      '/api/v1/mobile/client/auth/login',
      data: {'number': number},
    );
    return res.data as Map<String, dynamic>;
  }
}
