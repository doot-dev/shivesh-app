import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../data/models/order_models.dart';

final activeOrdersProvider = FutureProvider<List<Order>>((ref) {
  return ref.read(clientApiProvider).getOrders(type: 'active');
});

final pastOrdersProvider = FutureProvider<List<Order>>((ref) {
  return ref.read(clientApiProvider).getOrders(type: 'past');
});

final orderByIdProvider = FutureProvider.family<Order?, String>((ref, orderId) async {
  try {
    return await ref.read(clientApiProvider).getOrder(orderId);
  } catch (_) {
    return null;
  }
});
