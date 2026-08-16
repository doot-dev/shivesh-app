import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'animations.dart';

/// The standard surface for every piece of content in the app.
///
/// Using this instead of a hand-rolled Container is what keeps radius, border
/// and shadow identical across screens.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.gradient,
    this.borderColor,
    this.radius = AppStyles.radiusLg,
    this.shadow,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Gradient? gradient;
  final Color? borderColor;
  final double radius;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: shadow ?? AppStyles.cardShadow,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return PressableScale(onTap: onTap, child: card);
  }
}

/// Small rounded label — order status, counts, tags.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.showDot = false,
    this.icon,
  });

  /// Convenience constructors so status colours are chosen in one place.
  factory StatusPill.success(String label, {bool showDot = false}) => StatusPill(
    label: label,
    bg: AppColors.successBg,
    fg: AppColors.successFg,
    showDot: showDot,
  );

  factory StatusPill.warning(String label) => StatusPill(
    label: label,
    bg: AppColors.warningBg,
    fg: AppColors.warningFg,
  );

  factory StatusPill.info(String label) =>
      StatusPill(label: label, bg: AppColors.infoBg, fg: AppColors.infoFg);

  final String label;
  final Color bg;
  final Color fg;
  final bool showDot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            _PulsingDot(color: fg),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A slow breathing dot — signals "this is live / in progress".
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
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
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Label above value — the dense metric layout used across order cards.
class InfoCell extends StatelessWidget {
  const InfoCell({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value.isEmpty ? '—' : value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// Friendly empty state with an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
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
    final theme = Theme.of(context);
    return Center(
      child: FadeSlideIn(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.10),
                      AppColors.primary.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Icon(icon, size: 38, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with a retry — used wherever an AsyncValue can fail.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Something went wrong',
      message: message,
      actionLabel: onRetry != null ? 'Try again' : null,
      onAction: onRetry,
    );
  }
}

/// Placeholder card shown while orders/projects load.
///
/// A skeleton that mirrors the real card's shape feels dramatically faster
/// than a spinner, because the layout never jumps when data lands.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3, this.height});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonBox(width: 140, height: 16),
                SkeletonBox(width: 64, height: 22, radius: 999),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < lines; i++) ...[
              SkeletonBox(width: i.isEven ? 220 : 170, height: 12),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.count,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(
                  actionLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
