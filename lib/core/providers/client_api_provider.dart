import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/client_api_service.dart';
import '../services/notification_service.dart';
import 'dio_provider.dart';

final clientApiProvider = Provider<ClientApiService>((ref) {
  return ClientApiService(ref.read(dioProvider));
});

/// Push notifications for this client.
///
/// Deliberately NOT auto-disposed: the tap streams must outlive any single page
/// so a notification opened from a cold start still routes once the app is up.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(ref.read(clientApiProvider));
  ref.onDispose(service.dispose);
  return service;
});
