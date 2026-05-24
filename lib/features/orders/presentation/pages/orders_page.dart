import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_models.dart';
import '../../providers/orders_providers.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeOrdersProvider);
    final pastAsync = ref.watch(pastOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text('Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTabBar(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AsyncOrderList(asyncOrders: activeAsync),
          _AsyncOrderList(asyncOrders: pastAsync, isPast: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-order'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
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
      tabs: const [Tab(text: 'Active'), Tab(text: 'Past')],
    );
  }
}

class _AsyncOrderList extends ConsumerWidget {
  const _AsyncOrderList({required this.asyncOrders, this.isPast = false});

  final AsyncValue<List<Order>> asyncOrders;
  final bool isPast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncOrders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load orders',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(
                isPast ? pastOrdersProvider : activeOrdersProvider,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (orders) => _OrderList(orders: orders, isPast: isPast),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, this.isPast = false});

  final List<Order> orders;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          'No ${isPast ? 'past' : 'active'} orders',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _OrderCard(order: orders[index], isPast: isPast),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.isPast = false});

  final Order order;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPast ? Colors.white : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: isPast
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPast ? '#ORD ${order.id}' : order.projectName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 10),
            if (isPast) ...[
              Row(
                children: [
                  _InfoItem(label: 'Project', value: order.projectName),
                  const SizedBox(width: 24),
                  _InfoItem(label: 'Product', value: order.product),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoItem(label: 'Grade', value: order.grade),
                  const SizedBox(width: 24),
                  _InfoItem(label: 'Quantity', value: order.quantity),
                  const SizedBox(width: 24),
                  _InfoItem(label: 'Date', value: order.date),
                ],
              ),
              const SizedBox(height: 8),
              _InfoItem(label: 'Field Technician', value: order.fieldTechnician),
            ] else ...[
              Row(
                children: [
                  _InfoItem(label: 'Grade', value: order.grade),
                  const SizedBox(width: 24),
                  _InfoItem(label: 'Quantity', value: order.quantity),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoItem(label: 'Product', value: order.product),
                  const SizedBox(width: 24),
                  _InfoItem(label: 'Date', value: order.date),
                  const SizedBox(width: 24),
                  _InfoItem(label: 'Time', value: order.time),
                ],
              ),
              const Divider(height: 18, color: AppColors.border),
              Text(
                'Field Technician: ${order.fieldTechnician}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
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
