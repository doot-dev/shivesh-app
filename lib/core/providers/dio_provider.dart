import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/auth_events.dart';
import '../network/dio_client.dart';
import 'storage_providers.dart';

/// Single source of truth for the backend host — REST and the WebSocket hub
/// MUST point at the same server, so the socket layer reads this too.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.6:3001',
);

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  return DioClient().create(
    baseUrl: apiBaseUrl,
    storage: storage,
    // Lets a 401 on any authenticated call surface as an app-wide logout.
    authEvents: ref.read(authEventBusProvider),
  );
});
