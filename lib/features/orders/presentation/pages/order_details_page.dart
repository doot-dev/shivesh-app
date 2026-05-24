import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/client_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_models.dart';
import '../../providers/orders_providers.dart';

class OrderDetailsPage extends ConsumerStatefulWidget {
  const OrderDetailsPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends ConsumerState<OrderDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _messageController = TextEditingController();
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sendingComment = true);
    try {
      await ref.read(clientApiProvider).addComment(widget.orderId, msg);
      _messageController.clear();
      ref.invalidate(orderByIdProvider(widget.orderId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderByIdProvider(widget.orderId));

    return orderAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load order'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(orderByIdProvider(widget.orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (order) {
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order Details')),
            body: const Center(child: Text('Order not found')),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: const BackButton(color: AppColors.textPrimary),
            title: const Text('Order Details'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _buildTabBar(),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _DetailsTab(order: order),
              _CommentsTab(
                order: order,
                messageController: _messageController,
                sendingComment: _sendingComment,
                onSend: _sendComment,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textMuted,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      indicatorColor: AppColors.primary,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.border,
      tabs: const [Tab(text: 'Details'), Tab(text: 'Comments')],
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _OrderInfoCard(order: order),
        if (order.tmDetails.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined,
                  size: 20, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                'TM details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...order.tmDetails.map(
            (tm) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TmCard(tm: tm),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderInfoCard extends StatelessWidget {
  const _OrderInfoCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.projectName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order.product,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          _DetailRow(
              icon: Icons.grid_view_rounded, label: 'Grade', value: order.grade),
          _DetailRow(
              icon: Icons.scale_outlined,
              label: 'Quantity',
              value: order.quantity),
          if (order.site != null)
            _DetailRow(
                icon: Icons.location_city_outlined,
                label: 'Site',
                value: order.site!),
          _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: order.date),
          _DetailRow(
              icon: Icons.access_time_outlined, label: 'Time', value: order.time),
          if (order.deliveryAddress != null)
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Delivery address',
              value: order.deliveryAddress!,
            ),
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Field Technician',
            value: order.fieldTechnician,
            isLast: true,
          ),
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
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TmCard extends StatelessWidget {
  const _TmCard({required this.tm});

  final TmDetail tm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tm.tmNumber,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Truck No: ${tm.truckNo}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
          Text('Qty: ${tm.qty}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
          Text('Batch Start Time: ${tm.batchStartTime}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
          Text('Batch End Time: ${tm.batchEndTime}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
          Text('Challan No: ${tm.challanNo}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
          if (tm.challanUrl != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('View Challan'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentsTab extends StatelessWidget {
  const _CommentsTab({
    required this.order,
    required this.messageController,
    required this.sendingComment,
    required this.onSend,
  });

  final Order order;
  final TextEditingController messageController;
  final bool sendingComment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: order.comments.isEmpty
              ? Center(
                  child: Text(
                    'No comments yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: order.comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) =>
                      _CommentBubble(comment: order.comments[index]),
                ),
        ),
        _MessageInput(
          controller: messageController,
          sending: sendingComment,
          onSend: onSend,
        ),
      ],
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

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: isMe
              ? [
                  Text(
                    comment.timeAgo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    comment.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ]
              : [
                  Text(
                    comment.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    comment.timeAgo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
        ),
        const SizedBox(height: 4),
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            border: isMe ? null : Border.all(color: AppColors.border),
          ),
          child: Text(
            comment.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isMe ? Colors.white : AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              decoration: InputDecoration(
                hintText: 'Post a message...',
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sending
                    ? AppColors.textMuted
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case OrderStatus.active:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = '• Active';
        break;
      case OrderStatus.completed:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = 'Completed';
        break;
      case OrderStatus.pending:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
