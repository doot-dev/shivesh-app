import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// One decoded server push, e.g. `comment:new` or `order:status`.
class SocketEvent {
  const SocketEvent({required this.type, this.orderId, this.data});

  final String type;
  final String? orderId;
  final dynamic data;

  factory SocketEvent.fromJson(Map<String, dynamic> json) => SocketEvent(
    type: json['type'] as String? ?? '',
    orderId: json['orderId'] as String?,
    data: json['data'],
  );

  @override
  String toString() => 'SocketEvent($type, order=$orderId)';
}

enum SocketStatus { disconnected, connecting, connected }

/// Live connection to the backend's `/ws` hub.
///
/// Holds ONE socket for the whole app and re-broadcasts every server push on
/// [events]. Survives the things that kill a mobile socket in practice —
/// backgrounding, network switches, server restarts — by reconnecting with
/// backoff and REPLAYING its room subscriptions, so a screen that subscribed
/// once stays live without knowing a reconnect happened.
///
/// Used by the realtime Riverpod providers; widgets should watch those rather
/// than talking to this class directly.
class SocketService {
  SocketService({required this.baseUrl});

  /// Same host as the REST API, e.g. `http://192.168.1.6:3001`.
  final String baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  String? _token;
  bool _manuallyClosed = false;
  int _attempt = 0;

  /// Rooms this client wants to be in. Replayed after every reconnect.
  final Set<String> _desiredRooms = <String>{};

  final _events = StreamController<SocketEvent>.broadcast();
  final _status = StreamController<SocketStatus>.broadcast();

  Stream<SocketEvent> get events => _events.stream;

  /// Connection status, seeded with the CURRENT value.
  ///
  /// [_status] is a broadcast controller, so it only pushes on change. A screen
  /// that starts listening after the socket is already up would otherwise never
  /// hear anything and would render "Reconnecting" over a perfectly live
  /// socket — which is exactly what the order details screen used to do.
  Stream<SocketStatus> get statusStream async* {
    yield _current;
    yield* _status.stream;
  }

  SocketStatus _current = SocketStatus.disconnected;
  SocketStatus get status => _current;

  bool get isConnected => _current == SocketStatus.connected;

  void _setStatus(SocketStatus s) {
    if (_current == s) return;
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  Uri _wsUri(String token) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws',
      queryParameters: {'token': token},
    );
  }

  /// Open the socket. Safe to call repeatedly — a live socket is reused.
  void connect(String token) {
    if (_channel != null && _token == token && isConnected) return;

    _token = token;
    _manuallyClosed = false;
    _openSocket();
  }

  void _openSocket() {
    final token = _token;
    if (token == null || _manuallyClosed) return;

    _cancelTimers();
    _sub?.cancel();
    _sub = null;

    try {
      _setStatus(SocketStatus.connecting);
      final channel = WebSocketChannel.connect(_wsUri(token));
      _channel = channel;

      _sub = channel.stream.listen(
        _onData,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = json['type'] as String? ?? '';

    if (type == 'connected') {
      _attempt = 0;
      _setStatus(SocketStatus.connected);
      _startPing();
      // Re-join every room after a reconnect so subscribers stay live.
      for (final orderId in _desiredRooms) {
        _send({'type': 'subscribe', 'orderId': orderId});
      }
    }

    if (type == 'pong') return;

    if (!_events.isClosed) _events.add(SocketEvent.fromJson(json));
  }

  void _send(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(payload));
    } catch (_) {
      _scheduleReconnect();
    }
  }

  /// Listen to one order's live events. Idempotent — the room is remembered
  /// even when offline and joined as soon as the socket comes up.
  void subscribeToOrder(String orderId) {
    _desiredRooms.add(orderId);
    if (isConnected) _send({'type': 'subscribe', 'orderId': orderId});
  }

  void unsubscribeFromOrder(String orderId) {
    _desiredRooms.remove(orderId);
    if (isConnected) _send({'type': 'unsubscribe', 'orderId': orderId});
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (isConnected) _send({'type': 'ping'});
    });
  }

  /// Exponential backoff capped at 30s so a dead server does not spin the radio.
  void _scheduleReconnect() {
    if (_manuallyClosed) return;

    _setStatus(SocketStatus.disconnected);
    _cancelTimers();
    _sub?.cancel();
    _sub = null;
    _channel = null;

    final delaySeconds = [1, 2, 5, 10, 20, 30];
    final wait = delaySeconds[_attempt.clamp(0, delaySeconds.length - 1)];
    _attempt++;

    _reconnectTimer = Timer(Duration(seconds: wait), _openSocket);
  }

  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Close for good — call on logout so the next user gets a fresh socket.
  void disconnect() {
    _manuallyClosed = true;
    _desiredRooms.clear();
    _cancelTimers();
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
    _token = null;
    _attempt = 0;
    _setStatus(SocketStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _events.close();
    _status.close();
  }
}
