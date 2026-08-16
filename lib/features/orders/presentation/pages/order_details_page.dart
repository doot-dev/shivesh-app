import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/realtime/realtime_providers.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../data/models/order_models.dart';
import '../../providers/live_order_provider.dart';

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

                      if (order.tmDetails.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: SectionHeader(
                              title: 'Delivery (TM)',
                              count: order.tmDetails.length,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 168,
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
                              itemBuilder: (context, i) =>
                                  _TmCard(tm: order.tmDetails[i]),
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

          // Docked, so replying never costs a tab switch.
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
                      _StatusChipOnDark(order: order),
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

/// Status as it appears on the dark header — translucent rather than the light
/// pill used on white cards.
class _StatusChipOnDark extends StatelessWidget {
  const _StatusChipOnDark({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final active = order.status == OrderStatus.active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            order.statusLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
              label: 'Quantity',
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
      _DetailRow(
        icon: Icons.engineering_outlined,
        label: 'Technician',
        value: order.fieldTechnician,
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
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
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
      ],
    );
  }
}

class _TmCard extends StatelessWidget {
  const _TmCard({required this.tm});

  final TmDetail tm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              ],
            ),
            const SizedBox(height: 10),
            _TmLine(label: 'Truck', value: tm.truckNo),
            _TmLine(label: 'Qty', value: tm.qty),
            _TmLine(label: 'Challan', value: tm.challanNo),
            _TmLine(label: 'Batch', value: _batchWindow(tm)),
            const Spacer(),
            if (tm.challanUrl != null)
              SizedBox(
                width: double.infinity,
                height: 32,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppStyles.radiusSm),
                    ),
                  ),
                  child: const Text('View challan'),
                ),
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
