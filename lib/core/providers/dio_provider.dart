import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import 'storage_providers.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.6:3001',
);

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  return DioClient().create(baseUrl: _baseUrl, storage: storage);
});
