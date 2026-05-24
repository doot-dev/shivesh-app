import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/storage_providers.dart';
import '../data/auth_service.dart';

// ─── Service provider ─────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(dioProvider));
});

// ─── Auth state ───────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({
    this.token,
    this.name,
    this.clientId,
    this.phone,
    this.isLoading = false,
    this.error,
    this.devOtp,
  });

  final String? token;
  final String? name;
  final String? clientId;
  final String? phone;
  final bool isLoading;
  final String? error;
  final String? devOtp;

  bool get isLoggedIn => token != null;

  AuthState copyWith({
    String? token,
    String? name,
    String? clientId,
    String? phone,
    bool? isLoading,
    String? error,
    String? devOtp,
    bool clearError = false,
    bool clearAll = false,
  }) {
    if (clearAll) return const AuthState();
    return AuthState(
      token: token ?? this.token,
      name: name ?? this.name,
      clientId: clientId ?? this.clientId,
      phone: phone ?? this.phone,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      devOtp: devOtp ?? this.devOtp,
    );
  }
}

// ─── Auth notifier (Riverpod 3.x Notifier) ────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_loadFromStorage);
    return const AuthState();
  }

  AuthService get _service => ref.read(authServiceProvider);

  Future<void> _loadFromStorage() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: tokenKey);
    final raw = await storage.read(key: userDataKey);
    if (token != null && raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        state = AuthState(
          token: token,
          name: data['name'] as String?,
          clientId: data['clientId'] as String?,
          phone: data['phone'] as String?,
        );
      } catch (_) {
        await logout();
      }
    }
  }

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _service.sendOtp(phone);
      final data = res['data'] as Map<String, dynamic>?;
      final devOtp = data?['otp'] as String?;
      state = state.copyWith(isLoading: false, phone: phone, devOtp: devOtp);
      return res['success'] == true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _service.verifyOtp(phone, otp);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final storage = ref.read(secureStorageProvider);

        await storage.write(key: tokenKey, value: token);
        await storage.write(
          key: userDataKey,
          value: jsonEncode({
            'name': data['name'],
            'clientId': data['clientId'],
            'phone': data['phone'],
          }),
        );

        state = AuthState(
          token: token,
          name: data['name'] as String?,
          clientId: data['clientId'] as String?,
          phone: data['phone'] as String?,
        );
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: res['message'] as String? ?? 'Verification failed',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: tokenKey);
    await storage.delete(key: userDataKey);
    state = const AuthState();
  }

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) return data['message'] as String;
      return e.message ?? 'Network error';
    }
    return e.toString();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
