import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/access_provider.dart';

import '../../../../core/realtime/realtime_providers.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../data/models/order_models.dart';
import '../../providers/live_order_provider.dart';
import '../../../../core/providers/client_api_provider.dart';
import '../../../../core/widgets/file_viewer.dart';
import '../../../cube_test/presentation/pages/order_cube_tests_page.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../bills/presentation/pages/bills_page.dart' show inr;

/// Order details + live updates on ONE screen.
///
/// Deliberately has no tabs: the previous version hid comments behind a
/// "Comments" tab, so seeing a live update cost a tap and the details card left
/// two thirds of the screen empty. Here the facts sit in a compact header and
/// the update feed fills the rest, with the composer permanently docked — so
/// reading an update and replying are both zero extra taps.
///
/// The feed is NEWEST-FIRST on purpose. A new comment arriving over the socket
/// lands directly under the details card, already on screen, instead of below
/// the fold at the bottom of a chat log.
class OrderDetailsPage extends ConsumerStatefulWidget {
  const OrderDetailsPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends ConsumerState<OrderDetailsPage> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _feedKey = GlobalKey();

  bool _sendingComment = false;

  /// True when a new update arrived while the user was scrolled away from the
  /// top of the feed — surfaces a "New update" pill instead of yanking them.
  bool _hasUnseenUpdate = false;

  /// Below this offset the top of the feed is effectively on screen.
  static const _feedVisibleOffset = 260.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasUnseenUpdate &&
        _scrollController.hasClients &&
        _scrollController.offset <= _feedVisibleOffset) {
      setState(() => _hasUnseenUpdate = false);
    }
  }

  bool get _feedTopVisible =>
      !_scrollController.hasClients ||
      _scrollController.offset <= _feedVisibleOffset;

  /// Bring the newest update into view. Uses ensureVisible on the feed header
  /// rather than a fixed offset, so it stays correct however tall the details
  /// section renders.
  void _scrollToFeed() {
    final ctx = _feedKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: AppStyles.medium,
      curve: AppStyles.curve,
      alignment: 0.05,
    );
  }

  Future<void> _sendComment() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    // Clear immediately: the comment is echoed optimistically, so leaving the
    // text in the box makes it look like nothing happened.
    _messageController.clear();
    setState(() => _sendingComment = true);

    // The optimistic bubble is inserted at the top of the feed — make sure the
    // client actually sees it land.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFeed());

    try {
      await ref
          .read(liveOrderProvider(widget.orderId).notifier)
          .addComment(msg, authorName: ref.read(authProvider).name ?? 'You');
    } catch (e) {
      if (mounted) {
        // Give the text back so it can be retried.
        _messageController.text = msg;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detect updates arriving over the socket while this screen is open.
    ref.listen(liveOrderProvider(widget.orderId), (prev, next) {
      final before = prev?.value?.comments.length ?? 0;
      final after = next.value?.comments.length ?? 0;
      if (after > before && !_feedTopVisible && mounted) {
        setState(() => _hasUnseenUpdate = true);
      }
    });

    final orderAsync = ref.watch(liveOrderProvider(widget.orderId));
    final socketStatus = ref.watch(socketStatusProvider).value;
    final live = socketStatus == SocketStatus.connected;

    return orderAsync.when(
      loading: () => const _DetailsScaffold(child: _DetailsSkeleton()),
      error: (e, _) => _DetailsScaffold(
        child: ErrorState(
          message: 'We could not load this order.',
          onRetry: () =>
              ref.read(liveOrderProvider(widget.orderId).notifier).refresh(),
        ),
      ),
      data: (order) {
        if (order == null) {
          return const _DetailsScaffold(
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Order not found',
              message: 'This order may have been removed.',
            ),
          );
        }
        return _buildOrder(context, order, live);
      },
    );
  }

  Widget _buildOrder(BuildContext context, Order order, bool live) {
    // Newest first — see the class doc.
    final comments = order.comments.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      // The composer is laid out by hand in the body below instead of being
      // handed to Scaffold.bottomNavigationBar. Under edge-to-edge insets that
      // slot ended up UNDERNEATH the keyboard, hiding the input exactly when
      // it is needed. Owning the inset ourselves makes it deterministic:
      // _MessageInput grows by viewInsets.bottom, which shrinks the Expanded
      // above it, so the field always lands directly on top of the keyboard.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => ref
                      .read(liveOrderProvider(widget.orderId).notifier)
                      .refresh(),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      _OrderHeader(order: order, live: live),

                      // Key facts, pulled out of the old detail list so the three
                      // things clients check most are readable at a glance.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: FadeSlideIn(child: _QuickFacts(order: order)),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: FadeSlideIn(
                            index: 1,
                            child: _SecondaryDetails(order: order),
                          ),
                        ),
                      ),

                      if (order.creditBand != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: CreditBandBar(
                              band: order.creditBand!,
                              position: order.creditPosition,
                              footer: order.creditAfterThisOrder == null
                                  ? null
                                  : Text(
                                      'Available ${inr(order.creditAvailable ?? 0)} → '
                                      '${inr(order.creditAfterThisOrder!)} once this order is delivered',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                            ),
                          ),
                        ),

                      if (ref.can('cubeTests.view'))
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _CubeTestsEntry(orderId: widget.orderId),
                          ),
                        ),

                      // D15: cancel directly until the order is dispatched.
                      if (order.canClientCancel && ref.can('orders.cancel'))
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.cancel_outlined,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Cancel order',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                              ),
                              onPressed: () => _cancelOrder(
                                context,
                                ref,
                                order.id,
                                widget.orderId,
                              ),
                            ),
                          ),
                        ),

                      if (order.tmDetails.isNotEmpty ||
                          _canAddTruck(ref, order))
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: SectionHeader(
                              title: 'Delivery (TM)',
                              count: order.tmDetails.length,
                              actionLabel: _canAddTruck(ref, order)
                                  ? 'Add truck'
                                  : null,
                              onAction: _canAddTruck(ref, order)
                                  ? () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => _AddTruckPage(
                                          orderId: widget.orderId,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      if (order.tmDetails.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 212,
                            child: ListView.separated(
                              // Horizontal so multiple TMs never push the update feed
                              // off the screen.
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: order.tmDetails.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, i) => _TmCard(
                                tm: order.tmDetails[i],
                                orderId: order.id,
                                routeOrderId: widget.orderId,
                              ),
                            ),
                          ),
                        ),
                      ],

                      SliverToBoxAdapter(
                        child: Padding(
                          key: _feedKey,
                          padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                          child: _FeedHeader(
                            count: comments.length,
                            live: live,
                          ),
                        ),
                      ),

                      if (comments.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                            child: _NoUpdatesYet(),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CommentBubble(comment: comments[i]),
                              ),
                              childCount: comments.length,
                            ),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                  ),
                ),

                if (_hasUnseenUpdate)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: _NewUpdatePill(
                        onTap: () {
                          setState(() => _hasUnseenUpdate = false);
                          _scrollToFeed();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Docked, so replying never costs a tab switch. Hidden for roles
          // that may only read (docs/06).
          if (ref.can('orders.comment'))
            _MessageInput(
              controller: _messageController,
              sending: _sendingComment,
              onSend: _sendComment,
            ),
        ],
      ),
    );
  }
}

/// Entry to this order's cube test reports, as in the field app.
///
/// ponytail: shown on every order — the order payload has no isConcrete flag,
/// and the server refuses a cube test on a non-concrete product with its own
/// message. Hide it here if the order ever carries the flag.
class _CubeTestsEntry extends ConsumerWidget {
  const _CubeTestsEntry({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push('/orders/$orderId/cube-tests'),
      child: Row(
        children: [
          const CubeIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cube test reports',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ref.can('cubeTests.manage')
                      ? 'Log casting details and attach results'
                      : 'Casting details and result files',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Plain scaffold used by the loading / error / empty states so they keep the
/// same chrome as the loaded screen.
class _DetailsScaffold extends StatelessWidget {
  const _DetailsScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text('Order Details'),
      ),
      body: child,
    );
  }
}

/// Collapsing brand header: identity, status and live-connection state.
class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order, required this.live});

  final Order order;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 186,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: const BackButton(color: Colors.white),
      title: Text(
        order.id.isEmpty ? 'Order Details' : order.id,
        style: theme.textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(child: _LiveChip(live: live)),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          order.product.isEmpty ? '—' : order.product,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      StatusBadge.of(order.rawStatus, label: order.statusLabel),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Replaces the old full-width "Reconnecting" banner. Same information, but as
/// a chip in the header instead of a bar that ate a row of vertical space.
class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppStyles.medium,
      curve: AppStyles.curve,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: live
            ? AppColors.accent.withValues(alpha: 0.22)
            : AppColors.warningBg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live)
            const _LiveDot()
          else
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: AppColors.warningFg,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            live ? 'Live' : 'Reconnecting',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: live ? Colors.white : AppColors.warningFg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Grade / quantity / schedule — the three facts clients check first.
class _QuickFacts extends StatelessWidget {
  const _QuickFacts({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final schedule = [
      order.date,
      order.time,
    ].where((s) => s.isNotEmpty).join(' · ');

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: InfoCell(
              label: 'Grade',
              value: order.grade,
              icon: Icons.grid_view_rounded,
            ),
          ),
          const _FactDivider(),
          Expanded(
            child: InfoCell(
              label: 'Qty', // fits a ~300dp Fold cover screen
              value: order.quantity,
              icon: Icons.scale_outlined,
            ),
          ),
          const _FactDivider(),
          Expanded(
            flex: 2,
            child: InfoCell(
              label: 'Schedule',
              value: schedule,
              icon: Icons.event_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactDivider extends StatelessWidget {
  const _FactDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppColors.border,
    );
  }
}

/// Site, address and technician — shown compactly so they never crowd out the
/// update feed.
class _SecondaryDetails extends StatelessWidget {
  const _SecondaryDetails({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (order.site != null && order.site!.isNotEmpty)
        _DetailRow(
          icon: Icons.location_city_outlined,
          label: 'Site',
          value: order.site!,
        ),
      if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
        _DetailRow(
          icon: Icons.location_on_outlined,
          label: 'Delivery',
          value: order.deliveryAddress!,
        ),
      if (order.contacts.isEmpty)
        const _DetailRow(
          icon: Icons.support_agent_outlined,
          label: 'Contact person',
          value: 'Not assigned yet',
        ),
      for (final c in order.contacts)
        _DetailRow(
          icon: Icons.support_agent_outlined,
          label: 'Contact person',
          value: c.phone.isEmpty ? c.name : '${c.name}\n${c.phone}',
          phone: c.phone,
        ),
      for (final x in order.extras)
        _DetailRow(
          icon: Icons.add_card_outlined,
          label: 'Extra',
          value: '${x.name} · ${inr(x.amount)}',
        ),
      if (order.placedBy != null)
        _DetailRow(
          icon: Icons.person_outline_rounded,
          label: 'Placed by',
          value: order.placedBy!,
        ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              const Divider(height: 16, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.phone,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Shows a call button when set.
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhone = phone != null && phone!.isNotEmpty;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (hasPhone)
          IconButton(
            tooltip: 'Call or copy',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.call_rounded, color: AppColors.primary),
            onPressed: () => showPhoneActions(context, phone!),
          ),
      ],
    );
    // Tap the number itself too: call or copy it.
    return hasPhone
        ? InkWell(onTap: () => showPhoneActions(context, phone!), child: row)
        : row;
  }
}

class _TmCard extends ConsumerWidget {
  const _TmCard({
    required this.tm,
    required this.orderId,
    required this.routeOrderId,
  });

  final TmDetail tm;
  final String orderId;
  final String routeOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasChallan = tm.challanUrl != null && tm.challanUrl!.isNotEmpty;

    return SizedBox(
      width: 240,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tm.tmNumber.isEmpty ? 'TM' : tm.tmNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge.of(tm.isRejected ? 'REJECTED' : tm.status),
              ],
            ),
            const SizedBox(height: 10),
            _TmLine(label: 'Truck', value: tm.truckNo),
            _TmLine(
              label: 'Qty',
              value: tm.isPartRejected
                  ? '${tm.qty} (−${_num(tm.rejectedQty!)} wasted)'
                  : tm.qty,
            ),
            _TmLine(label: 'Challan', value: tm.challanNo),
            _TmLine(label: 'Batch', value: _batchWindow(tm)),
            if (tm.isRejected)
              Text(
                'Rejected${tm.rejectedByType == 'CLIENT' ? ' by you' : ''}: ${tm.rejectionReason ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
            if (tm.isPartRejected)
              Text(
                'Part rejected${tm.rejectedByType == 'CLIENT' ? ' by you' : ''}: ${tm.rejectionReason ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orange.shade800,
                ),
              ),
            const Spacer(),
            Row(
              children: [
                if (hasChallan)
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: OutlinedButton(
                        onPressed: () => openServerFile(
                          context,
                          tm.challanUrl!,
                          title: 'Challan ${tm.challanNo}',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppStyles.radiusSm,
                            ),
                          ),
                        ),
                        child: const Text('View challan'),
                      ),
                    ),
                  ),
                if ((tm.canClientReject || tm.canPartReject) &&
                    ref.can('trucks.reject'))
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: OutlinedButton(
                        onPressed: () => _rejectTruck(
                          context,
                          ref,
                          orderId,
                          routeOrderId,
                          tm,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppStyles.radiusSm,
                            ),
                          ),
                        ),
                        child: Text(
                          tm.canClientReject ? 'Reject truck' : 'Report waste',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _batchWindow(TmDetail tm) {
    final parts = [
      tm.batchStartTime,
      tm.batchEndTime,
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(' → ');
  }
}

String _apiError(Object e, String fallback) => e is DioException
    ? (e.response?.data is Map
          ? (e.response!.data['message'] as String? ?? fallback)
          : fallback)
    : fallback;

Future<void> _cancelOrder(
  BuildContext context,
  WidgetRef ref,
  String orderId,
  String routeOrderId,
) async {
  final ctrl = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel this order?'),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(labelText: 'Reason'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep order'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Cancel order'),
        ),
      ],
    ),
  );
  if (reason == null || reason.isEmpty || !context.mounted) return;
  try {
    await ref.read(clientApiProvider).cancelOrder(orderId, reason);
    ref.read(liveOrderProvider(routeOrderId).notifier).refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order cancelled')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_apiError(e, 'Could not cancel'))));
    }
  }
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

const _rejectReasons = [
  'Quality / slump not OK',
  'Wasted / spilled at site',
  'Damaged / segregated',
  'Wrong grade',
  'Too late',
  'Other',
];

Future<void> _rejectTruck(
  BuildContext context,
  WidgetRef ref,
  String orderId,
  String routeOrderId,
  TmDetail tm,
) async {
  var reason = _rejectReasons.first;
  final note = TextEditingController();
  final qty = TextEditingController();
  // Whole truck only before the challan; after that just part of it (waste).
  var part = !tm.canClientReject;
  final truckQty = double.tryParse(tm.qty.trim()) ?? 0;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Reject ${tm.tmNumber}?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tm.canClientReject && tm.canPartReject) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Whole truck')),
                    ButtonSegment(value: true, label: Text('Part of it')),
                  ],
                  selected: {part},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => part = v.first),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                part
                    ? 'Only the good concrete is billed: ${tm.qty} minus what you enter.'
                    : 'The truck will not be billed. The office will arrange a replacement.',
              ),
              if (part) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: qty,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Wasted / refused qty (CBM)',
                    helperText: 'Truck carried ${tm.qty}',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: reason,
                isExpanded: true,
                items: _rejectReasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => reason = v ?? reason),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              final q = double.tryParse(qty.text.trim()) ?? 0;
              if (part && !(q > 0 && q < truckQty)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Enter a qty more than 0 and less than ${tm.qty}',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(part ? 'Save' : 'Reject truck'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final wasted = part ? double.tryParse(qty.text.trim()) : null;
  try {
    await ref
        .read(clientApiProvider)
        .rejectTruck(
          orderId,
          tm.id,
          reason,
          note: note.text.trim(),
          rejectedQty: wasted,
        );
    ref.read(liveOrderProvider(routeOrderId).notifier).refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasted == null
                ? '${tm.tmNumber} rejected'
                : '${_num(wasted)} CBM of ${tm.tmNumber} marked as wasted',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_apiError(e, 'Could not reject'))));
    }
  }
}

class _TmLine extends StatelessWidget {
  const _TmLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.count, required this.live});

  final int count;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SectionHeader(title: 'Updates', count: count),
        Text(
          live ? 'Newest first' : 'Paused',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _NoUpdatesYet extends StatelessWidget {
  const _NoUpdatesYet();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
            child: const Icon(
              Icons.forum_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No updates yet. Post a message below and the team will see it '
              'straight away.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = comment.isMe;
    final initial = comment.author.isEmpty
        ? '?'
        : comment.author.trim()[0].toUpperCase();

    return Opacity(
      // A still-sending comment is dimmed until the server echoes it back.
      opacity: comment.pending ? 0.55 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMe
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.secondary.withValues(alpha: 0.22),
            ),
            child: Text(
              initial,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isMe ? AppColors.primary : const Color(0xFF9A6410),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                border: Border.all(
                  color: isMe
                      ? AppColors.primary.withValues(alpha: 0.28)
                      : AppColors.border,
                ),
                boxShadow: AppStyles.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isMe ? 'You' : comment.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isMe
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        comment.pending ? 'sending…' : comment.timeAgo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    comment.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating "New update" affordance — only shown when an update lands while the
/// feed is scrolled out of view, so a live message is never missed silently.
class _NewUpdatePill extends StatelessWidget {
  const _NewUpdatePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      offset: 12,
      duration: AppStyles.fast,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppStyles.raisedShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_upward_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'New update',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // viewInsets is the keyboard; padding.bottom is the gesture bar. Take the
    // larger — when the keyboard is up it already covers the gesture area, so
    // adding both would leave a dead gap above the keys.
    final bottomInset = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.padding.bottom;

    return AnimatedPadding(
      // Matches the keyboard's own animation so the field rides up with it
      // instead of snapping.
      duration: AppStyles.fast,
      curve: AppStyles.curve,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !sending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => sending ? null : onSend(),
                decoration: InputDecoration(
                  hintText: 'Post an update…',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            PressableScale(
              onTap: sending ? null : onSend,
              child: AnimatedContainer(
                duration: AppStyles.fast,
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: sending ? null : AppColors.brandGradient,
                  color: sending ? AppColors.textMuted : null,
                  shape: BoxShape.circle,
                  boxShadow: sending ? null : AppStyles.cardShadow,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton that mirrors the loaded layout, so nothing jumps when data lands.
class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonCard(lines: 2, height: 108),
        SizedBox(height: 12),
        SkeletonCard(lines: 3),
        SizedBox(height: 20),
        SkeletonCard(lines: 2),
        SizedBox(height: 12),
        SkeletonCard(lines: 2),
      ],
    );
  }
}

/// The site adds a truck with its challan (trucks.add, 2026-09-29): the same
/// details as the field app — truck, quantity, challan no., batch start / end
/// from the challan, dispatch / arrival times and a photo of the challan.
class _AddTruckPage extends ConsumerStatefulWidget {
  const _AddTruckPage({required this.orderId});
  final String orderId;

  @override
  ConsumerState<_AddTruckPage> createState() => _AddTruckPageState();
}

class _AddTruckPageState extends ConsumerState<_AddTruckPage> {
  final _truck = TextEditingController();
  final _qty = TextEditingController();
  final _challan = TextEditingController();
  ({String path, String name})? _photo;
  TimeOfDay? _batchStart;
  TimeOfDay? _batchEnd;
  TimeOfDay? _dispatch;
  TimeOfDay? _arrival;
  bool _saving = false;

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(void Function(TimeOfDay) set, TimeOfDay? current) async {
    final t = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => set(t));
  }

  Widget _timeRow(
    String label,
    TimeOfDay? value,
    void Function(TimeOfDay) set,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: const Icon(Icons.schedule_outlined),
    title: Text(label),
    trailing: Text(
      value == null ? 'Select' : value.format(context),
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: value == null ? AppColors.textMuted : AppColors.primary,
      ),
    ),
    onTap: () => _pick(set, value),
  );

  @override
  void dispose() {
    _truck.dispose();
    _qty.dispose();
    _challan.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final res = await FilePicker.pickFiles(type: FileType.image);
    final f = res?.files.firstOrNull;
    if (f?.path != null) {
      setState(() => _photo = (path: f!.path!, name: f.name));
    }
  }

  Future<void> _save() async {
    if (_truck.text.trim().isEmpty ||
        (double.tryParse(_qty.text.trim()) ?? 0) <= 0 ||
        _challan.text.trim().isEmpty ||
        _batchStart == null ||
        _batchEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter truck no., quantity, challan no. and the batch start / end time',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(clientApiProvider)
          .addTruck(
            widget.orderId,
            truckNo: _truck.text.trim().toUpperCase(),
            qty: _qty.text.trim(),
            challanNo: _challan.text.trim(),
            batchStartTime: _hhmm(_batchStart!),
            batchEndTime: _hhmm(_batchEnd!),
            dispatchTime: _dispatch == null ? null : _hhmm(_dispatch!),
            arrivalTime: _arrival == null ? null : _hhmm(_arrival!),
            photo: _photo,
          );
      ref.read(liveOrderProvider(widget.orderId).notifier).refresh();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Truck added')));
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data is Map && data['message'] is String
                  ? data['message'] as String
                  : 'Could not add the truck',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add truck')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Adding…' : 'Add truck'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _truck,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Truck no.'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              textInputAction: TextInputAction.next,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Quantity (CBM)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _challan,
              decoration: const InputDecoration(labelText: 'Challan no.'),
            ),
            const SizedBox(height: 12),
            _timeRow('Batch start', _batchStart, (t) => _batchStart = t),
            _timeRow('Batch end', _batchEnd, (t) => _batchEnd = t),
            _timeRow(
              'Dispatched from plant (optional)',
              _dispatch,
              (t) => _dispatch = t,
            ),
            _timeRow(
              'Arrived at site (optional)',
              _arrival,
              (t) => _arrival = t,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(
                _photo == null ? 'Challan photo (optional)' : _photo!.name,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The site may add trucks until the order is closed (trucks.add).
bool _canAddTruck(WidgetRef ref, Order order) =>
    ref.can('trucks.add') &&
    !const ['COMPLETED', 'CANCELLED'].contains(order.rawStatus);
