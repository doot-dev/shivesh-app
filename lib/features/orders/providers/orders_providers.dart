import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../data/models/order_models.dart';

/// Re-fetch this provider whenever the server pushes an order-level change.
///
/// The list screens show status and order counts, so an `order:status` or
/// `order:new` push must invalidate them — otherwise the detail screen goes
/// live while the list behind it stays stale.
///
/// NOTE: this self-invalidates via `ref.invalidateSelf`, deliberately. Routing
/// it through a shared "refresh" provider that the lists watch creates a
/// circular dependency (the refresher would invalidate its own dependents).
void _refreshOnOrderEvents(Ref ref) {
  ref.listen(socketEventsProvider, (_, next) {
    next.whenData((event) {
      if (event.type == 'order:status' ||
          event.type == 'order:new' ||
          event.type == 'notification') {
        ref.invalidateSelf();
      }
    });
  });
}

final activeOrdersProvider = FutureProvider<List<Order>>((ref) {
  _refreshOnOrderEvents(ref);
  return ref.read(clientApiProvider).getOrders(type: 'active');
});

final pastOrdersProvider = FutureProvider<List<Order>>((ref) {
  _refreshOnOrderEvents(ref);
  return ref.read(clientApiProvider).getOrders(type: 'past');
});

/// One-shot fetch. Prefer `liveOrderProvider` on screens that must stay current.
final orderByIdProvider = FutureProvider.family<Order?, String>((
  ref,
  orderId,
) async {
  try {
    return await ref.read(clientApiProvider).getOrder(orderId);
  } catch (_) {
    return null;
  }
});
