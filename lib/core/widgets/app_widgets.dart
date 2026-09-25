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

/// Colour group for a status. Pick it with [toneFor] so one status word always
/// gets one colour, on every screen.
enum Tone { ok, warn, err, primary, muted }

/// COMPLETED, PAID → ok; DELAYED, PARTIALLY_PAID → warn; CANCELLED, OVERDUE →
/// err; NEW, DISPATCHED, SENT → primary; ASSIGNED and anything unknown → muted.
Tone toneFor(String status) =>
    switch (status.toUpperCase().replaceAll(' ', '_')) {
      'COMPLETED' ||
      'REACHED' ||
      'PAID' ||
      'ACCEPTED' ||
      'DELIVERED' ||
      'TESTED' => Tone.ok,
      'DELAYED' ||
      'PENDING' ||
      'PARTIALLY_PAID' ||
      'DUE' ||
      'DUE_TODAY' => Tone.warn,
      'CANCELLED' || 'REJECTED' || 'OVERDUE' => Tone.err,
      'NEW' ||
      'CONFIRMED' ||
      'DISPATCHED' ||
      'SENT' ||
      'IN_PROGRESS' ||
      'IN_TRANSIT' => Tone.primary,
      _ => Tone.muted,
    };

/// "DISPATCHED" → "Dispatched", "PARTIALLY_PAID" → "Part paid". Never raw CAPS.
String statusText(String status) => switch (status) {
  '' => '—',
  'PARTIALLY_PAID' => 'Part paid',
  'IN_TRANSIT' => 'On the way',
  'IN_PROGRESS' => 'Dispatched',
  _ =>
    status[0].toUpperCase() +
        status.substring(1).toLowerCase().replaceAll('_', ' '),
};

/// (soft background, soft text, solid background, solid text) for a tone.
/// Warn keeps dark text even when solid: white or amber on amber fails contrast.
(Color, Color, Color, Color) _toneColors(Tone tone) {
  final mutedFg = Color.lerp(AppColors.textMuted, AppColors.textPrimary, 0.4)!;
  return switch (tone) {
    Tone.ok => (
      AppColors.successBg,
      AppColors.successFg,
      AppColors.successFg,
      Colors.white,
    ),
    Tone.warn => (
      AppColors.warningBg,
      AppColors.warningFg,
      AppColors.secondary,
      AppColors.textPrimary,
    ),
    Tone.err => (
      AppColors.dangerBg,
      AppColors.dangerFg,
      AppColors.dangerFg,
      Colors.white,
    ),
    Tone.primary => (
      AppColors.infoBg,
      AppColors.primary,
      AppColors.primary,
      Colors.white,
    ),
    Tone.muted => (AppColors.shimmerBase, mutedFg, mutedFg, Colors.white),
  };
}

/// The one status pill: soft tint with a 6px dot and the label in the tone
/// colour, or [solid] (filled, white text and dot).
class StatusBadge extends StatelessWidget {
  const StatusBadge(
    this.label, {
    super.key,
    this.tone = Tone.muted,
    this.solid = false,
  });

  /// From a server status word: tone and readable label in one go.
  StatusBadge.of(String status, {super.key, String? label, this.solid = false})
    : label = label ?? statusText(status),
      tone = toneFor(status);

  final String label;
  final Tone tone;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, solidBg, solidFg) = _toneColors(tone);
    final color = solid ? solidFg : fg;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? solidBg : bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color, size: 6),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small round pill holding a number, e.g. a section's item count.
class CountBubble extends StatelessWidget {
  const CountBubble(
    this.count, {
    super.key,
    this.tone = Tone.primary,
    this.solid = false,
  });

  final int count;
  final Tone tone;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, solidBg, solidFg) = _toneColors(tone);
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: solid ? solidBg : bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
          color: solid ? solidFg : fg,
        ),
      ),
    );
  }
}

/// The status colour alone, for tight spots (a list row, a legend).
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.tone, this.size = 8});

  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Dot(color: _toneColors(tone).$2, size: size);
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
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
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A narrow cell keeps the word and drops the icon.
              if (icon != null && constraints.maxWidth >= 72) ...[
                Icon(icon, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
              ],
              // Flexible + ellipsis: three cells share a ~300dp Fold cover
              // screen, so a label must shrink rather than overflow.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.2,
                  ),
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
      ),
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
  const ErrorState({super.key, required this.message, this.onRetry});

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
        // A ListView, not a Column: a fixed-height skeleton on a small or
        // large-font screen clips its last lines instead of overflowing.
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Flexible(child: SkeletonBox(width: 140, height: 16)),
                SizedBox(width: 8),
                Flexible(
                  child: SkeletonBox(width: 64, height: 22, radius: 999),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < lines; i++) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: SkeletonBox(width: i.isEven ? 220 : 170, height: 12),
              ),
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
              CountBubble(count!),
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
