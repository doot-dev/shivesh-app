import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../../core/widgets/month_bar.dart';
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

/// One order-list query: the Active/Past tab, optional search text and the
/// delivery month (defaults to this month).
///
/// Used as a Riverpod family key, so it MUST be value-equal — two identical
/// filters have to hash the same, or every rebuild would refetch and the list
/// would flicker on each keystroke.
class OrderFilter {
  OrderFilter({this.type = 'active', this.query = '', DateTime? month})
    : month = monthOf(month ?? DateTime.now());

  /// `active` or `past`.
  final String type;

  /// Free text: order code, project, product or grade.
  final String query;

  /// First day of the delivery month shown.
  final DateTime month;

  bool get hasQuery => query.trim().isNotEmpty;

  /// The month always applies, so "filtered" means the search box.
  bool get isActive => hasQuery;

  OrderFilter copyWith({String? type, String? query, DateTime? month}) =>
      OrderFilter(
        type: type ?? this.type,
        query: query ?? this.query,
        month: month ?? this.month,
      );

  /// Drop the text but keep the tab and the month.
  OrderFilter cleared() => OrderFilter(type: type, month: month);

  String get fromIso => monthFromIso(month);
  String get toIso => monthToIso(month);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderFilter &&
          other.type == type &&
          other.query.trim() == query.trim() &&
          other.month == month;

  @override
  int get hashCode => Object.hash(type, query.trim(), month);
}

/// The live filter for the Orders screen.
///
/// A `Notifier` rather than the legacy `StateProvider`: on Riverpod 3.x
/// `StateProvider` only exists behind `flutter_riverpod/legacy.dart`, and the
/// rest of this app is already on the modern API.
class OrderFilterNotifier extends Notifier<OrderFilter> {
  @override
  OrderFilter build() => OrderFilter();

  void setQuery(String value) => state = state.copyWith(query: value);

  void setType(String type) => state = state.copyWith(type: type);

  void setMonth(DateTime month) => state = state.copyWith(month: month);

  /// Drop the text, keeping the current tab and month.
  void clear() => state = state.cleared();
}

final orderFilterProvider = NotifierProvider<OrderFilterNotifier, OrderFilter>(
  OrderFilterNotifier.new,
);

/// Server-side filtered orders for one [OrderFilter].
///
/// Always hits the server with the month window; the unfiltered
/// active/past providers above stay for Home, which is not filtered.
/// It calls [_refreshOnOrderEvents] too, so live status pushes keep the list
/// current.
final searchedOrdersProvider = FutureProvider.family<List<Order>, OrderFilter>((
  ref,
  filter,
) {
  _refreshOnOrderEvents(ref);
  return ref
      .read(clientApiProvider)
      .getOrders(
        type: filter.type,
        query: filter.query,
        dateFrom: filter.fromIso,
        dateTo: filter.toIso,
      );
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
