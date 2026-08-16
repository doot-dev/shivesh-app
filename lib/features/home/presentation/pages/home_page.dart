import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../../../orders/providers/orders_providers.dart';
import '../../data/models/home_models.dart';
import '../../providers/home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrdersAsync = ref.watch(activeOrdersProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(activeOrdersProvider);
          ref.invalidate(projectsProvider);
          // Give the refresh spinner a beat so the gesture feels acknowledged.
          await Future<void>.delayed(const Duration(milliseconds: 350));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _HomeHeader(
              name: auth.name,
              // Riverpod 3.x: `.value` is itself nullable — `valueOrNull` was
              // removed, so this is the correct "data if loaded" accessor.
              activeCount: activeOrdersAsync.value?.length,
              projectCount: projectsAsync.value?.length,
            ),

            // ── Active orders ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: SectionHeader(
                  title: 'Active orders',
                  count: activeOrdersAsync.value?.length,
                  actionLabel: 'View all',
                  onAction: () => context.go('/orders'),
                ),
              ),
            ),
            activeOrdersAsync.when(
              loading: () => const _SkeletonSliver(count: 2),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _InlineError(
                    message: 'Could not load your orders.',
                    onRetry: () => ref.invalidate(activeOrdersProvider),
                  ),
                ),
              ),
              data: (orders) => orders.isEmpty
                  ? SliverToBoxAdapter(
                      child: _InlineEmpty(
                        icon: Icons.local_shipping_outlined,
                        title: 'No active orders',
                        message: 'Place an order and track it live here.',
                        actionLabel: 'New order',
                        onAction: () => context.push('/create-order'),
                      ),
                    )
                  : SliverList.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: FadeSlideIn(
                          index: index,
                          child: OrderCard(
                            order: orders[index],
                            onTap: () =>
                                context.push('/orders/${orders[index].id}'),
                          ),
                        ),
                      ),
                    ),
            ),

            // ── Projects ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SectionHeader(
                  title: 'Your projects',
                  count: projectsAsync.value?.length,
                ),
              ),
            ),
            projectsAsync.when(
              loading: () => const _SkeletonSliver(count: 2, lines: 2),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _InlineError(
                    message: 'Could not load your projects.',
                    onRetry: () => ref.invalidate(projectsProvider),
                  ),
                ),
              ),
              data: (projects) => projects.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _InlineEmpty(
                        icon: Icons.apartment_rounded,
                        title: 'No projects yet',
                        message: 'Your assigned projects will appear here.',
                      ),
                    )
                  : SliverList.builder(
                      itemCount: projects.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: FadeSlideIn(
                          index: index,
                          child: _ProjectCard(project: projects[index]),
                        ),
                      ),
                    ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
      floatingActionButton: _NewOrderFab(
        onPressed: () => context.push('/create-order'),
      ),
    );
  }
}

/// Gradient hero with the greeting and at-a-glance counts.
///
/// Collapses to a compact bar as the user scrolls, which keeps the brand
/// present without eating the screen.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.name, this.activeCount, this.projectCount});

  final String? name;
  final int? activeCount;
  final int? projectCount;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(AppStyles.radiusXl),
            bottomRight: Radius.circular(AppStyles.radiusXl),
          ),
        ),
        child: Stack(
          children: [
            // Soft decorative orb — depth without another asset.
            Positioned(
              top: -50,
              right: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const BrandLogo.onDark(height: 34),
                        const _NotificationBell(),
                      ],
                    ),
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name?.trim().isNotEmpty == true
                                ? name!
                                : 'Welcome back',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      index: 1,
                      child: Row(
                        children: [
                          _StatChip(
                            icon: Icons.local_shipping_rounded,
                            label: 'Active orders',
                            value: activeCount,
                          ),
                          const SizedBox(width: 12),
                          _StatChip(
                            icon: Icons.apartment_rounded,
                            label: 'Projects',
                            value: projectCount,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted count tile inside the header. Shows a dash until data arrives so
/// the layout never shifts when the number lands.
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: AppStyles.medium,
                    child: Text(
                      value?.toString() ?? '–',
                      key: ValueKey(value),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.push('/notifications'),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.notifications_none_rounded,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Gradient FAB with a label — more discoverable than a bare "+".
class _NewOrderFab extends StatelessWidget {
  const _NewOrderFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final ProjectSummary project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: () => context.push('/projects/${project.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppStyles.radiusSm),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.14),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        project.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InfoCell(
                        label: 'Remaining credits',
                        value: project.remainingCredits,
                      ),
                    ),
                    Expanded(
                      child: InfoCell(
                        label: 'Credit period',
                        value: project.creditPeriod,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 18, left: 4),
            child: Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonSliver extends StatelessWidget {
  const _SkeletonSliver({required this.count, this.lines = 3});

  final int count;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: count,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: SkeletonCard(lines: lines),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: EmptyState(
          icon: icon,
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      borderColor: AppColors.dangerBg,
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.dangerFg,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
