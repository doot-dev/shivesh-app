import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/access_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/month_bar.dart';
import '../../../orders/presentation/widgets/order_search_bar.dart';
import '../../data/models/cube_test_model.dart';
import '../../providers/cube_test_providers.dart';
import 'order_cube_tests_page.dart';

/// Every cube testing report across all of this client's orders.
///
/// A bottom-nav destination, so it deliberately has NO back button. A card
/// opens that order's cube tests ([OrderCubeTestsPage]), where Owners and Site
/// Engineers (cubeTests.manage) log and edit tests; they can add files here too.
///
/// All filtering is server-side (see `allCubeTestsProvider`); the search box,
/// casting month and status chips write into one shared [CubeTestFilter] which
/// keys the request.
class CubeTestsPage extends ConsumerStatefulWidget {
  const CubeTestsPage({super.key});

  @override
  ConsumerState<CubeTestsPage> createState() => _CubeTestsPageState();
}

class _CubeTestsPageState extends ConsumerState<CubeTestsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(cubeTestFilterProvider);
    final notifier = ref.read(cubeTestFilterProvider.notifier);
    final testsAsync = ref.watch(allCubeTestsProvider(filter));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Gradient header, matching Home and Orders so the shell feels
          // continuous.
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cube tests',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              testsAsync.when(
                                data: (t) => t.isEmpty
                                    ? 'No reports found'
                                    : '${t.length} report${t.length == 1 ? '' : 's'}',
                                loading: () => 'Loading…',
                                error: (_, _) => 'Could not load',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
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
                    const SizedBox(height: 14),
                    OrderSearchBar(
                      hintText: 'Search order, project or grade',
                      onQueryChanged: notifier.setQuery,
                    ),
                    const SizedBox(height: 10),
                    MonthBar(month: filter.month, onChanged: notifier.setMonth),
                    const SizedBox(height: 12),
                    _StatusChips(
                      selected: filter.status,
                      onSelect: notifier.setStatus,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (filter.isActive)
            _FilterSummary(
              count: testsAsync.value?.length,
              onClear: notifier.clear,
            ),

          Expanded(
            child: testsAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                children: const [
                  SkeletonCard(lines: 4),
                  SizedBox(height: 14),
                  SkeletonCard(lines: 4),
                  SizedBox(height: 14),
                  SkeletonCard(lines: 4),
                ],
              ),
              error: (e, _) => ErrorState(
                message: 'We could not load your cube test reports.',
                onRetry: () => ref.invalidate(allCubeTestsProvider(filter)),
              ),
              data: (tests) {
                if (tests.isEmpty) {
                  return EmptyState(
                    icon: Icons.science_outlined,
                    title: filter.isActive
                        ? 'No matching reports'
                        : 'No cube tests in ${monthLabel(filter.month)}',
                    message: filter.isActive
                        ? 'Try a different search, status or month.'
                        : 'Reports show here by casting date once a test is '
                              'logged. Use ‹ › to see another month.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(allCubeTestsProvider(filter));
                    await ref
                        .read(allCubeTestsProvider(filter).future)
                        .catchError((_) => <CubeTestEntry>[]);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    // Bottom padding clears the floating nav bar.
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                    itemCount: tests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => FadeSlideIn(
                      index: i,
                      child: _CubeTestCard(entry: tests[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// All / Tested / Scheduled selector.
class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.selected, required this.onSelect});

  final CubeTestStatusFilter selected;
  final ValueChanged<CubeTestStatusFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Wrap: at 300dp with large text the third chip drops to a new line.
    return Wrap(
      runSpacing: 8,
      children: CubeTestStatusFilter.values.map((status) {
        final active = status == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelect(status),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: AppStyles.fast,
              curve: AppStyles.curve,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.16),
                // No radiusPill token in this app — a large radius on a short
                // chip reads as a pill.
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: active ? 1 : 0.4),
                  width: 1.2,
                ),
              ),
              child: Text(
                status.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: active ? AppColors.primary : Colors.white,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// "N results · Clear filters" strip, shown only while a filter is applied.
class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.count, required this.onClear});

  final int? count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null
                  ? 'Filtering…'
                  : '$count result${count == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Clear filters'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

/// One report. Tapping opens that order's cube tests, like the field app.
class _CubeTestCard extends ConsumerWidget {
  const _CubeTestCard({required this.entry});

  final CubeTestEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = entry.test;
    final canManage = ref.can('cubeTests.manage') && entry.orderId.isNotEmpty;

    return AppCard(
      onTap: entry.orderId.isEmpty
          ? null
          : () => context.push('/orders/${entry.orderId}/cube-tests'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CubeIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shrink, never break the order code across lines.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        entry.orderId.isEmpty ? 'Cube test' : entry.orderId,
                        maxLines: 1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (entry.projectLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.projectLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              CubeDueBadge(test: t),
            ],
          ),
          // Same rows, same order as the field app's cube test card.
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          CubeTestRows(test: t, product: entry.productLabel),
          const SizedBox(height: 10),
          CubeTestFiles(
            orderId: entry.orderId,
            test: t,
            canAdd: canManage,
            canRemove: canManage,
          ),
        ],
      ),
    );
  }
}
