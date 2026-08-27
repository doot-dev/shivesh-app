import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/client_api_service.dart';

/// Top-level handler for background / terminated messages.
/// Must be a top-level function annotated with @pragma.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised in main() before runApp().
  // No extra work needed — the system tray notification is shown automatically.
}

class NotificationService {
  NotificationService(this._apiService);

  final ClientApiService _apiService;

  static const _channelId = 'shivesh_high_importance';
  static const _channelName = 'High Importance Notifications';
  static const _channelDesc = 'Notifications for orders, comments and updates.';

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.max,
  );

  bool _initialized = false;
  String? _currentToken;

  /// Order codes (ORD-2025-0001) from tapped notifications. The router listens
  /// and opens /orders/<code>.
  ///
  /// A stream rather than a direct navigation call: this service has no
  /// BuildContext, and a cold-start tap arrives before the router exists.
  final _tapController = StreamController<String>.broadcast();
  Stream<String> get onOrderTapped => _tapController.stream;

  /// Fired when the daily "place tomorrow's order" reminder is tapped, so the
  /// app can open the create-order screen instead of an order that has no id.
  final _reminderController = StreamController<void>.broadcast();
  Stream<void> get onReminderTapped => _reminderController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS + Android 13+)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Init flutter_local_notifications (for foreground display)
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      // Tapping a notification this app drew itself while in the foreground.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _handleTapData(jsonDecode(payload) as Map<String, dynamic>);
        } catch (_) {
          // Malformed payload — nothing to route to.
        }
      },
    );

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Background -> tapped (app alive but not focused).
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleTapData(message.data),
    );

    // Cold start: the app was terminated and launched BY the notification.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTapData(initialMessage.data);
    }

    // Register current token
    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // Handle token refresh
    messaging.onTokenRefresh.listen(_registerToken);
  }

  Future<void> _registerToken(String token) async {
    _currentToken = token;
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await _apiService.registerFcmToken(token, platform);
    } catch (_) {
      // Non-fatal: token will be retried on next refresh
    }
  }

  /// Release this device's push slot on logout, so a signed-out phone stops
  /// receiving order updates and frees one of the client's 5 device slots.
  Future<void> unregister() async {
    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (token != null) {
      try {
        await _apiService.unregisterFcmToken(token);
      } catch (_) {
        // Best effort — deleting the FCM token below still stops delivery.
      }
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _currentToken = null;
  }

  /// Route a tapped notification.
  ///
  /// Reads `orderCode`, NOT `orderId`: the payload's orderId is the database
  /// cuid while /orders/:id resolves by the human order code, so routing on
  /// orderId opens a 404.
  void _handleTapData(Map<String, dynamic> data) {
    if (data['type'] == 'ORDER_REMINDER') {
      _reminderController.add(null);
      return;
    }

    final orderCode = data['orderCode'];
    if (orderCode is String && orderCode.isNotEmpty) {
      _tapController.add(orderCode);
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Carried through so a foreground tap routes like a tray tap.
      payload: jsonEncode(message.data),
    );
  }

  void dispose() {
    _tapController.close();
    _reminderController.close();
  }
}
