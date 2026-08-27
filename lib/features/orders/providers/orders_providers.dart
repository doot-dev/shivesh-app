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

/// One order-list query: the Active/Past tab plus optional search text and a
/// delivery-date window.
///
/// Used as a Riverpod family key, so it MUST be value-equal — two identical
/// filters have to hash the same, or every rebuild would refetch and the list
/// would flicker on each keystroke.
class OrderFilter {
  const OrderFilter({
    this.type = 'active',
    this.query = '',
    this.from,
    this.to,
  });

  /// `active` or `past`.
  final String type;

  /// Free text: order code, project, product or grade.
  final String query;

  /// Inclusive delivery-date window. Null means unbounded on that side.
  final DateTime? from;
  final DateTime? to;

  bool get hasQuery => query.trim().isNotEmpty;
  bool get hasDate => from != null || to != null;
  bool get isActive => hasQuery || hasDate;

  OrderFilter copyWith({
    String? type,
    String? query,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return OrderFilter(
      type: type ?? this.type,
      query: query ?? this.query,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  /// Drop the text and dates but keep the tab.
  OrderFilter cleared() => OrderFilter(type: type);

  /// The backend only understands ISO `yyyy-MM-dd`; anything else is ignored
  /// server-side, so format here rather than at the call site.
  static String? _iso(DateTime? d) {
    if (d == null) return null;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String? get fromIso => _iso(from);
  String? get toIso => _iso(to);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderFilter &&
          other.type == type &&
          other.query.trim() == query.trim() &&
          other.fromIso == fromIso &&
          other.toIso == toIso;

  @override
  int get hashCode => Object.hash(type, query.trim(), fromIso, toIso);
}

/// The live filter for the Orders screen.
///
/// A `Notifier` rather than the legacy `StateProvider`: on Riverpod 3.x
/// `StateProvider` only exists behind `flutter_riverpod/legacy.dart`, and the
/// rest of this app is already on the modern API.
class OrderFilterNotifier extends Notifier<OrderFilter> {
  @override
  OrderFilter build() => const OrderFilter();

  void setQuery(String value) => state = state.copyWith(query: value);

  void setType(String type) => state = state.copyWith(type: type);

  void setRange(DateTime? from, DateTime? to) => state = state.copyWith(
    from: from,
    to: to,
    clearFrom: from == null,
    clearTo: to == null,
  );

  void clearDates() => state = state.copyWith(clearFrom: true, clearTo: true);

  /// Drop the text and dates, keeping the current tab.
  void clear() => state = state.cleared();
}

final orderFilterProvider = NotifierProvider<OrderFilterNotifier, OrderFilter>(
  OrderFilterNotifier.new,
);

/// Server-side filtered orders for one [OrderFilter].
///
/// With no filter applied this reuses the plain active/past providers, so a
/// cleared search box hits the cache the rest of the app already warmed rather
/// than firing a redundant request.
///
/// Note it calls [_refreshOnOrderEvents] too — without that, live status
/// pushes would stop updating the list the moment a search was active.
final searchedOrdersProvider =
    FutureProvider.family<List<Order>, OrderFilter>((ref, filter) async {
      if (!filter.isActive) {
        return ref.watch(
          filter.type == 'past'
              ? pastOrdersProvider.future
              : activeOrdersProvider.future,
        );
      }

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
