import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../data/models/notification_model.dart';

class _NotificationsNotifier
    extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() {
    return ref.read(clientApiProvider).getNotifications();
  }

  Future<void> markRead(String id) async {
    await ref.read(clientApiProvider).markNotificationRead(id);
    ref.invalidateSelf();
  }
}

final notificationsProvider =
    AsyncNotifierProvider<_NotificationsNotifier, List<AppNotification>>(
  _NotificationsNotifier.new,
);
