import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

/// First day of [d]'s month: the value every month filter stores.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

final _iso = DateFormat('yyyy-MM-dd');

/// `dateFrom` / `dateTo` for [month]: its first and last day, in the only
/// format the server reads (anything else is silently ignored).
String monthFromIso(DateTime month) => _iso.format(month);
String monthToIso(DateTime month) =>
    _iso.format(DateTime(month.year, month.month + 1, 0));

/// "September 2026".
String monthLabel(DateTime month) => DateFormat('MMMM yyyy').format(month);

/// True when [d] (a server timestamp, often UTC) falls in [month] locally.
bool inMonth(DateTime? d, DateTime month) {
  if (d == null) return false;
  final l = d.toLocal();
  return l.year == month.year && l.month == month.month;
}

/// `‹  September 2026  ›` for the navy headers. The arrows step one month,
/// the label opens a month/year picker, and "This month" (shown only when
/// another month is selected) jumps back.
class MonthBar extends StatelessWidget {
  const MonthBar({super.key, required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final thisMonth = monthOf(DateTime.now());
    final isThisMonth = month == thisMonth;

    return LayoutBuilder(
      builder: (context, c) {
        // Fold cover screen (~300dp): "Sep 2026" leaves room for the chip.
        final narrow = c.maxWidth < 340;
        final label = DateFormat(
          narrow && !isThisMonth ? 'MMM yyyy' : 'MMMM yyyy',
        ).format(month);

        return Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    _Arrow(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Previous month',
                      onTap: () =>
                          onChanged(DateTime(month.year, month.month - 1)),
                    ),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Choose month, $label selected',
                        excludeSemantics: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () async {
                            final picked = await showMonthPicker(
                              context,
                              month,
                            );
                            if (picked != null) onChanged(picked);
                          },
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    label,
                                    maxLines: 1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  if (!narrow) ...[
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.expand_more_rounded,
                                      size: 18,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _Arrow(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Next month',
                      onTap: () =>
                          onChanged(DateTime(month.year, month.month + 1)),
                    ),
                  ],
                ),
              ),
            ),
            if (!isThisMonth) ...[
              const SizedBox(width: 8),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(thisMonth),
                  behavior: HitTestBehavior.opaque,
                  // 44 tall to tap; the visible chip is smaller.
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'This month',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white, size: 24),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    );
  }
}

/// A 12-month grid with a year stepper. Returns the first day of the month.
///
/// ponytail: Material has no month picker; this is the smallest one that
/// works. A Dialog, not an AlertDialog: AlertDialog measures intrinsic widths.
Future<DateTime?> showMonthPicker(BuildContext context, DateTime initial) {
  var year = initial.year;
  final now = monthOf(DateTime.now());
  final months = DateFormat.MMM();

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final theme = Theme.of(ctx);
        Widget cell(int m) {
          final value = DateTime(year, m);
          final selected = value == monthOf(initial);
          final current = value == now;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Material(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppStyles.radiusSm),
                  side: current && !selected
                      ? const BorderSide(color: AppColors.primary)
                      : BorderSide.none,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppStyles.radiusSm),
                  onTap: () => Navigator.pop(ctx, value),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        months.format(value),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: selected || current
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous year',
                        onPressed: () => setState(() => year--),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          '$year',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next year',
                        onPressed: () => setState(() => year++),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var row = 0; row < 4; row++)
                    Row(
                      children: [
                        for (var i = 1; i <= 3; i++) cell(row * 3 + i),
                      ],
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
