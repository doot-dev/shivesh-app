import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide "the server rejected our token" channel.
///
/// The Dio interceptor lives below the widget tree and has no `ref`, so it
/// cannot log the user out directly. It broadcasts here instead, and the auth
/// layer listens and performs the actual logout + redirect. Keeping it a
/// broadcast stream means several listeners (auth, socket) can react.
class AuthEventBus {
  final _controller = StreamController<AuthEvent>.broadcast();

  Stream<AuthEvent> get stream => _controller.stream;

  /// Fired when an authenticated request came back 401 / invalid token.
  /// Debounced: a burst of parallel requests failing at once (home loads
  /// orders + projects + profile together) must produce ONE logout, not four.
  DateTime? _lastEmit;

  void sessionExpired([String reason = 'Your session has expired']) {
    final now = DateTime.now();
    if (_lastEmit != null &&
        now.difference(_lastEmit!) < const Duration(seconds: 3)) {
      return;
    }
    _lastEmit = now;
    if (!_controller.isClosed) {
      _controller.add(AuthEvent.sessionExpired(reason));
    }
  }

  void dispose() => _controller.close();
}

class AuthEvent {
  const AuthEvent._(this.type, this.reason);

  factory AuthEvent.sessionExpired(String reason) =>
      AuthEvent._(AuthEventType.sessionExpired, reason);

  final AuthEventType type;
  final String reason;
}

enum AuthEventType { sessionExpired }

/// Single bus for the whole app — the Dio client and the auth notifier must
/// share the same instance or the logout signal never arrives.
final authEventBusProvider = Provider<AuthEventBus>((ref) {
  final bus = AuthEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});
