import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../providers/dio_provider.dart';
import 'socket_service.dart';

/// The app's single WebSocket connection.
///
/// Connects itself whenever the auth token appears and tears down on logout,
/// so no screen has to manage the connection lifecycle. Keep this alive for the
/// whole app — creating a second instance would open a second socket.
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(baseUrl: apiBaseUrl);

  // Follow the auth token: connect on login, disconnect on logout.
  ref.listen<AuthState>(authProvider, (prev, next) {
    if (next.token != null && next.token != prev?.token) {
      service.connect(next.token!);
    } else if (next.token == null && prev?.token != null) {
      service.disconnect();
    }
  }, fireImmediately: true);

  final token = ref.read(authProvider).token;
  if (token != null) service.connect(token);

  ref.onDispose(service.dispose);
  return service;
});

/// Every server push, app-wide. Screens usually want a filtered view instead.
final socketEventsProvider = StreamProvider<SocketEvent>((ref) {
  return ref.watch(socketServiceProvider).events;
});

/// Connection state — drive a "reconnecting…" banner from this.
final socketStatusProvider = StreamProvider<SocketStatus>((ref) {
  final service = ref.watch(socketServiceProvider);
  return service.statusStream;
});

/// Live events for ONE order. Watching this also joins the order's room and
/// leaves it when the screen goes away, so subscriptions track the UI exactly.
final orderEventsProvider = StreamProvider.family<SocketEvent, String>((
  ref,
  orderId,
) {
  final service = ref.watch(socketServiceProvider);
  service.subscribeToOrder(orderId);
  ref.onDispose(() => service.unsubscribeFromOrder(orderId));

  return service.events.where(
    (e) => e.orderId == orderId || e.type == 'notification',
  );
});
