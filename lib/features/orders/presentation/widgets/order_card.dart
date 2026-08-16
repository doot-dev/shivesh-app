import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/models/order_models.dart';

/// The single order card used by Home, the Orders list and search results.
///
/// Shared on purpose: these three screens previously had near-identical
/// private copies that drifted apart. Change the order visual HERE.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.showProjectName = true,
  });

  final Order order;
  final VoidCallback? onTap;
  final bool showProjectName;

  /// Date and time joined into one human line, tolerating either being blank.
  String get _schedule {
    final parts = [
      order.date.trim(),
      order.time.trim(),
    ].where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? 'Not scheduled' : parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = order.status == OrderStatus.active;

    // Active orders are marked with a soft border tint instead of the old
    // full-bleed strip: AppCard draws a rounded border but does NOT clip, so a
    // full-width bar butts hard against the corner curve and reads as a lid.
    return AppCard(
      onTap: onTap,
      borderColor: isActive
          ? AppColors.successFg.withValues(alpha: 0.30)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Small rounded marker aligned to the title block. Replaces
              // the top strip: it sits inside the padding so it can never
              // collide with the card radius, and it takes the STATUS
              // colour so it agrees with the pill instead of competing
              // with it (the old bar was brand blue next to a green pill).
              if (isActive) ...[
                Container(
                  width: 3,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.successFg.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showProjectName && order.projectName.isNotEmpty
                          ? order.projectName
                          : order.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.id,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OrderStatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 14),

          // One tinted panel holding the specs, instead of two loose
          // rows. The old second row had an empty third column, which is
          // what made the grid look lopsided.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppStyles.radiusSm),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InfoCell(
                        label: 'Grade',
                        value: order.grade,
                        icon: Icons.layers_outlined,
                      ),
                    ),
                    Expanded(
                      child: InfoCell(
                        label: 'Quantity',
                        value: order.quantity,
                        icon: Icons.scale_outlined,
                      ),
                    ),
                    Expanded(
                      child: InfoCell(
                        label: 'Product',
                        value: order.product,
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.border,
                  ),
                ),
                // Schedule reads as one fact, so date and time sit on the
                // same line rather than in a 3-column grid with a hole.
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _schedule,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _TechnicianTag(order: order),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact trailing tag showing who is assigned.
///
/// Renders a muted "Unassigned" chip rather than an avatar when nobody is on
/// the order — the API returns the literal string 'Not assigned', which the old
/// card turned into an avatar with the initial "N".
class _TechnicianTag extends StatelessWidget {
  const _TechnicianTag({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!order.hasTechnician) {
      return Text(
        'Unassigned',
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.textMuted,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final name = order.fieldTechnician.trim();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            name[0].toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 92),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Maps an [OrderStatus] onto the shared pill. Single place that decides what
/// colour an order status is anywhere in the app.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case OrderStatus.active:
        return StatusPill.success('Active', showDot: true);
      case OrderStatus.completed:
        return const StatusPill(
          label: 'Completed',
          bg: AppColors.infoBg,
          fg: AppColors.infoFg,
          icon: Icons.check_circle_outline_rounded,
        );
      case OrderStatus.pending:
        return StatusPill.warning('Pending');
    }
  }
}
