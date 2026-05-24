import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/client_api_service.dart';
import '../services/notification_service.dart';
import 'dio_provider.dart';

final clientApiProvider = Provider<ClientApiService>((ref) {
  return ClientApiService(ref.read(dioProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(clientApiProvider));
});
