import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../orders/data/models/order_models.dart';
import '../../data/models/home_models.dart';
import '../../providers/home_providers.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage>
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
    final detailAsync = ref.watch(projectDetailProvider(widget.projectId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: detailAsync.maybeWhen(
          data: (p) => Text(p.name),
          orElse: () => const Text('Project'),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load project'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(projectDetailProvider(widget.projectId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (project) => _ProjectDetailBody(
          project: project,
          projectId: widget.projectId,
          tabController: _tabController,
        ),
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
}

class _ProjectDetailBody extends ConsumerWidget {
  const _ProjectDetailBody({
    required this.project,
    required this.projectId,
    required this.tabController,
  });

  final ProjectDetail project;
  final String projectId;
  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(projectActiveOrdersProvider(projectId));
    final pastAsync = ref.watch(projectPastOrdersProvider(projectId));

    return Column(
      children: [
        _ProjectInfoCard(project: project),
        _buildTabBar(context),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _OrderList(asyncOrders: activeAsync),
              _OrderList(asyncOrders: pastAsync, isPast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: TabBar(
        controller: tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.border,
        tabs: const [Tab(text: 'Active Orders'), Tab(text: 'Order History')],
      ),
    );
  }
}

class _ProjectInfoCard extends StatelessWidget {
  const _ProjectInfoCard({required this.project});

  final ProjectDetail project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.business,
                  color: AppColors.textMuted,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (project.siteName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        project.siteName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: project.location,
          ),
          if (project.address != null && project.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.map_outlined,
              label: 'Address',
              value: project.address!,
            ),
          ],
          if (project.projectManager != null &&
              project.projectManager!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Manager',
              value: project.projectManager!,
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CreditChip(
                  label: 'Remaining Credits',
                  value: project.remainingCredits,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CreditChip(
                  label: 'Credit Period',
                  value: project.creditPeriod,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

class _CreditChip extends StatelessWidget {
  const _CreditChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.asyncOrders, this.isPast = false});

  final AsyncValue<List<Order>> asyncOrders;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    return asyncOrders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load orders')),
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Text(
              isPast ? 'No order history' : 'No active orders',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _OrderCard(order: orders[index]),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                  order.id,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoColumn(label: 'Product', value: order.product),
                const SizedBox(width: 24),
                _InfoColumn(label: 'Grade', value: order.grade),
                const SizedBox(width: 24),
                _InfoColumn(label: 'Qty', value: order.quantity),
              ],
            ),
            if (order.date.isNotEmpty || order.time.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (order.date.isNotEmpty)
                    _InfoColumn(label: 'Date', value: order.date),
                  if (order.date.isNotEmpty && order.time.isNotEmpty)
                    const SizedBox(width: 24),
                  if (order.time.isNotEmpty)
                    _InfoColumn(label: 'Time', value: order.time),
                ],
              ),
            ],
            const Divider(height: 20, color: AppColors.border),
            Text(
              'Field Technician: ${order.fieldTechnician}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      OrderStatus.active => ('Active', const Color(0xFFE8F5E9), AppColors.accent),
      OrderStatus.completed => ('Completed', const Color(0xFFEEEEEE), AppColors.textMuted),
      OrderStatus.pending => ('Pending', const Color(0xFFFFF8E1), AppColors.secondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.label, required this.value});

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
