import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/models/order_models.dart';
import '../../providers/orders_providers.dart';
import '../widgets/order_card.dart';

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
    // Rebuild on tab change so the segmented control repaints its selection.
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Gradient header, matching Home so the shell feels continuous.
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppStyles.radiusXl),
                bottomRight: Radius.circular(AppStyles.radiusXl),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Orders',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        PressableScale(
                          onTap: () => context.push('/notifications'),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SegmentedTabs(
                      controller: _tabController,
                      labels: const ['Active', 'Past'],
                      counts: [
                        activeAsync.value?.length,
                        pastAsync.value?.length,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AsyncOrderList(asyncOrders: activeAsync, isPast: false),
                _AsyncOrderList(asyncOrders: pastAsync, isPast: true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: PressableScale(
        onTap: () => context.push('/create-order'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppStyles.raisedShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 6),
              Text(
                'New order',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill-style segmented control with a sliding selection.
///
/// Replaces the default underline TabBar, which looked washed out on the
/// gradient header.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.controller,
    required this.labels,
    required this.counts,
  });

  final TabController controller;
  final List<String> labels;
  final List<int?> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = controller.index == i;
          final count = counts.length > i ? counts[i] : null;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.animateTo(i),
              child: AnimatedContainer(
                duration: AppStyles.medium,
                curve: AppStyles.curve,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: AppStyles.fast,
                      style:
                          theme.textTheme.labelLarge?.copyWith(
                            color: selected
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.85),
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ) ??
                          const TextStyle(),
                      child: Text(labels[i]),
                    ),
                    if (count != null && count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: selected ? AppColors.primary : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AsyncOrderList extends ConsumerWidget {
  const _AsyncOrderList({required this.asyncOrders, required this.isPast});

  final AsyncValue<List<Order>> asyncOrders;
  final bool isPast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncOrders.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const SkeletonCard(),
      ),
      error: (e, _) => ErrorState(
        message: 'We couldn\'t load your orders. Check your connection.',
        onRetry: () => _invalidate(ref),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return EmptyState(
            icon: isPast
                ? Icons.history_rounded
                : Icons.local_shipping_outlined,
            title: isPast ? 'No past orders' : 'No active orders',
            message: isPast
                ? 'Completed orders will show up here.'
                : 'Place an order and follow it live.',
            actionLabel: isPast ? null : 'New order',
            onAction: isPast ? null : () => context.push('/create-order'),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            _invalidate(ref);
            await Future<void>.delayed(const Duration(milliseconds: 350));
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => FadeSlideIn(
              index: index,
              child: OrderCard(
                order: orders[index],
                onTap: () => context.push('/orders/${orders[index].id}'),
              ),
            ),
          ),
        );
      },
    );
  }

  void _invalidate(WidgetRef ref) {
    ref.invalidate(isPast ? pastOrdersProvider : activeOrdersProvider);
  }
}
