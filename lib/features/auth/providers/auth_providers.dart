import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/auth_events.dart';
import '../../../core/providers/client_api_provider.dart';
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
    this.sessionExpiredMessage,
  });

  final String? token;
  final String? name;
  final String? clientId;
  final String? phone;
  final bool isLoading;
  final String? error;

  /// Set when the server rejected our token and we logged the user out for
  /// them. The login screen shows this once, so an unexplained bounce back to
  /// login never happens silently.
  final String? sessionExpiredMessage;

  bool get isLoggedIn => token != null;

  AuthState copyWith({
    String? token,
    String? name,
    String? clientId,
    String? phone,
    bool? isLoading,
    String? error,
    String? sessionExpiredMessage,
    bool clearError = false,
    bool clearAll = false,
    bool clearSessionExpired = false,
  }) {
    if (clearAll) return const AuthState();
    return AuthState(
      token: token ?? this.token,
      name: name ?? this.name,
      clientId: clientId ?? this.clientId,
      phone: phone ?? this.phone,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      sessionExpiredMessage: clearSessionExpired
          ? null
          : (sessionExpiredMessage ?? this.sessionExpiredMessage),
    );
  }
}

// ─── Auth notifier (Riverpod 3.x Notifier) ────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // A 401 on any authenticated call means the token is dead. Logging out
    // here (rather than in each screen) is what pushes the user to /login:
    // the router redirects on `isLoggedIn`, so clearing state is the redirect.
    final sub = ref.read(authEventBusProvider).stream.listen((event) {
      if (event.type == AuthEventType.sessionExpired) {
        _forceLogout(event.reason);
      }
    });
    ref.onDispose(sub.cancel);

    Future.microtask(_loadFromStorage);
    return const AuthState();
  }

  /// Server-initiated logout. Unlike [logout] this leaves a message behind so
  /// the login screen can explain why the user is suddenly back here.
  Future<void> _forceLogout(String reason) async {
    if (state.token == null) return; // already logged out — nothing to do
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: tokenKey);
    await storage.delete(key: userDataKey);
    state = AuthState(sessionExpiredMessage: reason);
  }

  /// Called by the login screen once it has shown the expiry notice.
  void acknowledgeSessionExpiry() {
    if (state.sessionExpiredMessage == null) return;
    state = state.copyWith(clearSessionExpired: true);
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

  /// Step 1 of login: ask the backend to confirm the number belongs to an
  /// active client, then let the UI move to the OTP screen. [phone] is kept in
  /// state because the OTP screen needs it to complete step 2.
  ///
  /// No OTP comes back in the response — the backend checks a fixed OTP.
  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _service.sendOtp(phone);
      if (res['success'] == true) {
        state = state.copyWith(isLoading: false, phone: phone);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: res['message'] as String? ?? 'Could not verify this number',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  /// Step 2 of login: exchange the OTP for a JWT. On success the token is
  /// persisted and [AuthState.isLoggedIn] flips, which the router and the
  /// WebSocket provider both react to.
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

  /// Single-step login with no OTP. Only works when the backend was started
  /// with ALLOW_NUMBER_ONLY_LOGIN=true; unused by the current UI flow.
  Future<bool> loginWithNumber(String number) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _service.loginWithNumber(number);
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
        error: res['message'] as String? ?? 'Login failed',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<void> logout() async {
    // Release the push slot BEFORE clearing the token: the unregister call is
    // authenticated, so wiping storage first would make it 401 and leave this
    // device occupying one of the client's 5 slots — still receiving order
    // notifications after sign-out.
    try {
      await ref.read(notificationServiceProvider).unregister();
    } catch (_) {
      // Best effort — never block a logout on it.
    }

    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: tokenKey);
    await storage.delete(key: userDataKey);
    state = const AuthState();
  }

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      return e.message ?? 'Network error';
    }
    return e.toString();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
