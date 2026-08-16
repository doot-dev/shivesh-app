import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../../core/realtime/socket_service.dart';
import '../data/models/order_models.dart';
import 'orders_providers.dart';

/// One order, kept live.
///
/// Loads the order over REST once, then MUTATES that snapshot in place as
/// WebSocket events arrive (`comment:new`, `order:status`) instead of refetching
/// — that is what makes a new comment appear instantly and without a flicker.
/// Watch this, not `orderByIdProvider`, on any screen that should stay current.
///
/// Riverpod 3.x note: family notifiers take their argument through the
/// CONSTRUCTOR (`build()` takes none), which is why orderId is a field.
class LiveOrderNotifier extends AsyncNotifier<Order?> {
  LiveOrderNotifier(this.orderId);

  final String orderId;

  @override
  Future<Order?> build() async {
    // Watching here joins the order's WS room and leaves it when the last
    // listener goes away, so subscriptions track the UI exactly.
    ref.listen<AsyncValue<SocketEvent>>(orderEventsProvider(orderId), (
      _,
      next,
    ) {
      next.whenData(_applyEvent);
    });

    try {
      return await ref.read(clientApiProvider).getOrder(orderId);
    } catch (_) {
      return null;
    }
  }

  void _applyEvent(SocketEvent event) {
    final current = state.value;
    if (current == null) return;

    switch (event.type) {
      case 'comment:new':
        final raw = event.data;
        if (raw is! Map) return;
        final incoming = Comment.fromJson(Map<String, dynamic>.from(raw));

        // Drop the optimistic echo of our own comment before appending the real
        // one, so a message we just sent never shows up twice.
        final kept = current.comments.where((c) {
          if (c.id != null && c.id == incoming.id) return false;
          if (c.pending && c.message == incoming.message) return false;
          return true;
        }).toList();

        state = AsyncData(current.copyWith(comments: [...kept, incoming]));
        break;

      case 'order:status':
        final raw = event.data;
        if (raw is! Map) return;
        final statusStr = raw['status'] as String?;
        if (statusStr == null) return;

        state = AsyncData(current.copyWith(status: mapOrderStatus(statusStr)));
        // The list screens show status too, so let them refetch.
        ref.invalidate(activeOrdersProvider);
        ref.invalidate(pastOrdersProvider);
        break;
    }
  }

  /// Show the client's own comment immediately, then let the socket echo
  /// replace it. On failure the optimistic bubble is rolled back and the error
  /// rethrown so the UI can surface it.
  Future<void> addComment(String message, {required String authorName}) async {
    final current = state.value;
    final trimmed = message.trim();
    if (current == null || trimmed.isEmpty) return;

    final optimistic = Comment(
      author: authorName,
      message: trimmed,
      timeAgo: 'just now',
      isMe: true,
      pending: true,
    );

    state = AsyncData(
      current.copyWith(comments: [...current.comments, optimistic]),
    );

    try {
      await ref.read(clientApiProvider).addComment(orderId, trimmed);
    } catch (_) {
      final rolledBack = state.value;
      if (rolledBack != null) {
        state = AsyncData(
          rolledBack.copyWith(
            comments: rolledBack.comments
                .where((c) => !(c.pending && c.message == trimmed))
                .toList(),
          ),
        );
      }
      rethrow;
    }
  }

  /// Pull-to-refresh / retry.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await ref.read(clientApiProvider).getOrder(orderId));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final liveOrderProvider =
    AsyncNotifierProvider.family<LiveOrderNotifier, Order?, String>(
      LiveOrderNotifier.new,
    );
