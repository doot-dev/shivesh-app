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
    await _localNotifications.initialize(initSettings);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Register current token
    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // Handle token refresh
    messaging.onTokenRefresh.listen(_registerToken);
  }

  Future<void> _registerToken(String token) async {
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await _apiService.registerFcmToken(token, platform);
    } catch (_) {
      // Non-fatal: token will be retried on next refresh
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
    );
  }
}
