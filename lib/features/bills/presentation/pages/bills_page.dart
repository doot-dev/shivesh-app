import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/access_provider.dart';
import '../../../../core/providers/client_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/links.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/month_bar.dart';
import '../../data/models/bill_models.dart';
import '../../providers/bill_providers.dart';

/// Indian grouping: ₹12,34,567. Negative (an advance) gets a leading minus.
String inr(double v) {
  if (v < 0) return '−${inr(-v)}';
  final s = v.round().toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}

/// Server dates are UTC; an IST-midnight invoice must not show the day before.
String _date(DateTime? d) =>
    d == null ? '—' : DateFormat('d MMM yyyy').format(d.toLocal());

/// Bills & invoices (W16): every issued bill for a month, with the invoice PDF
/// one tap away. The money summary and the Statement tab are account data, so
/// they need `account.view` on top of the `bills.view` that opens this tab.
class BillsPage extends ConsumerWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showMoney = ref.can('account.view');
    final month = ref.watch(billMonthProvider);

    return DefaultTabController(
      key: ValueKey(showMoney),
      length: showMoney ? 2 : 1,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _Header(
              month: month,
              showMoney: showMoney,
              onMonth: ref.read(billMonthProvider.notifier).setMonth,
            ),
            Expanded(
              child: showMoney
                  ? TabBarView(
                      children: [
                        _BillList(month: month),
                        _Statement(month: month),
                      ],
                    )
                  : _BillList(month: month),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navy header, as on Home and Orders: title, the money summary, the month
/// and the Bills / Statement switch.
class _Header extends StatelessWidget {
  const _Header({
    required this.month,
    required this.showMoney,
    required this.onMonth,
  });

  final DateTime month;
  final bool showMoney;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bills & invoices',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => context.push('/notifications'),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (showMoney)
                _MoneySummary(month: month)
              else
                _BilledLine(month: month),
              const SizedBox(height: 14),
              MonthBar(month: month, onChanged: onMonth),
              if (showMoney) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.85),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: theme.textTheme.labelLarge,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    splashBorderRadius: BorderRadius.circular(999),
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    tabs: const [
                      Tab(height: 44, text: 'Bills'),
                      Tab(height: 44, text: 'Statement'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "₹93,600 billed in August 2026 · 1 bill" — from the month's bills.
String? _billedText(List<ClientBill>? bills, DateTime month) {
  if (bills == null) return null;
  final total = bills.fold<double>(0, (s, b) => s + b.amount);
  final n = bills.length;
  return '${inr(total)} billed in ${monthLabel(month)} · $n bill${n == 1 ? '' : 's'}';
}

/// Outstanding overall, overdue, and what was paid in the selected month.
class _MoneySummary extends ConsumerWidget {
  const _MoneySummary({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final credit = ref.watch(creditProvider).value;
    final ledger = ref.watch(ledgerProvider).value;
    final billed = _billedText(ref.watch(billsProvider).value, month);
    final paid = ledger
        ?.where((r) => r.credit > 0 && inMonth(r.date, month))
        .fold<double>(0, (s, r) => s + r.credit);
    final overdue = credit?.overdueAmount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total outstanding',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            credit == null ? '—' : inr(credit.outstanding),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ),
        if (billed != null)
          Text(
            billed,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Tile(
                label: 'Overdue',
                value: credit == null ? '—' : inr(overdue),
                alert: overdue > 0,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                label: 'Paid in ${DateFormat.MMM().format(month)}',
                value: paid == null ? '—' : inr(paid),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Without account.view: only what the month's bills themselves say.
class _BilledLine extends ConsumerWidget {
  const _BilledLine({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      _billedText(ref.watch(billsProvider).value, month) ?? 'Loading…',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

/// Frosted figure on the header; turns to the err tone when [alert].
class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.alert = false});

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = alert ? AppColors.dangerFg : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: alert
            ? AppColors.dangerBg
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppStyles.radiusMd),
        border: Border.all(
          color: alert
              ? AppColors.dangerBg
              : Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: fg,
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
              color: alert ? fg : Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable filler so pull-to-refresh works on empty and error states too.
class _Fill extends StatelessWidget {
  const _Fill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          // Bottom padding clears the floating nav bar.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

const _listPadding = EdgeInsets.fromLTRB(20, 20, 20, 110);

Widget _skeletons() => ListView(
  physics: const AlwaysScrollableScrollPhysics(),
  padding: _listPadding,
  children: const [
    SkeletonCard(lines: 4),
    SizedBox(height: 12),
    SkeletonCard(lines: 4),
    SizedBox(height: 12),
    SkeletonCard(lines: 4),
  ],
);

class _BillList extends ConsumerWidget {
  const _BillList({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsProvider);

    Future<void> refresh() async {
      // The header figures are on the same screen; refresh them together.
      ref.invalidate(creditProvider);
      ref.invalidate(ledgerProvider);
      ref.invalidate(billsProvider);
      await ref.read(billsProvider.future).catchError((_) => <ClientBill>[]);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: refresh,
      child: bills.when(
        loading: _skeletons,
        error: (_, _) => _Fill(
          child: ErrorState(
            message: 'We could not load your bills.',
            onRetry: () => ref.invalidate(billsProvider),
          ),
        ),
        data: (list) => list.isEmpty
            ? _Fill(
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No bills in ${monthLabel(month)}',
                  message:
                      'Invoices issued this month show here. '
                      'Use ‹ › above to see another month.',
                ),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: _listPadding,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => FadeSlideIn(
                  index: i,
                  child: _BillCard(bill: list[i]),
                ),
              ),
      ),
    );
  }
}

class _BillCard extends ConsumerWidget {
  const _BillCard({required this.bill});

  final ClientBill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overdue = bill.daysOverdue > 0 && bill.status != 'PAID';
    final paidShare = bill.amount > 0
        ? (bill.paid / bill.amount).clamp(0.0, 1.0)
        : 0.0;
    final small = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
      fontSize: 11,
    );

    Future<void> openInvoice() async {
      final ok = await openServerLink(
        ref,
        ref.read(clientApiProvider).invoicePath(bill.billNo),
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the invoice')),
        );
      }
    }

    return AppCard(
      onTap: openInvoice,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        bill.billNo,
                        maxLines: 1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bill.projectName.isEmpty
                          ? bill.orderId
                          : bill.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.of(overdue ? 'OVERDUE' : bill.status),
            ],
          ),
          const SizedBox(height: 14),

          // Amount, and how much of it is paid.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppStyles.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount', style: small),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    inr(bill.amount),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: paidShare,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    color: AppColors.successFg,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      'Paid ${inr(bill.paid)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.successFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Pending ${inr(bill.balance)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: overdue
                            ? AppColors.dangerFg
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Meta(
                icon: Icons.event_outlined,
                text: 'Issued ${_date(bill.issueDate)}',
              ),
              if (bill.status != 'PAID')
                _Meta(
                  icon: Icons.schedule_rounded,
                  text: 'Due ${_date(bill.dueDate)}',
                ),
              if (overdue)
                _Meta(
                  icon: Icons.error_outline_rounded,
                  text:
                      '${bill.daysOverdue} day${bill.daysOverdue == 1 ? '' : 's'} overdue',
                  color: AppColors.dangerFg,
                ),
              if (bill.orderId.isNotEmpty)
                _Meta(
                  icon: Icons.local_shipping_outlined,
                  text: [
                    bill.orderId,
                    bill.product,
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: openInvoice,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('View invoice'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppStyles.radiusSm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color ?? AppColors.textPrimary,
              fontWeight: color != null ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// The month's bills (debit) and payments (credit) with the running balance,
/// between the opening and closing balance.
class _Statement extends ConsumerWidget {
  const _Statement({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(ledgerProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(creditProvider);
        ref.invalidate(ledgerProvider);
        await ref.read(ledgerProvider.future).catchError((_) => <LedgerRow>[]);
      },
      child: rows.when(
        loading: _skeletons,
        error: (_, _) => _Fill(
          child: ErrorState(
            message: 'We could not load your statement.',
            onRetry: () => ref.invalidate(ledgerProvider),
          ),
        ),
        data: (all) {
          // The server sends every row oldest first with a running balance,
          // so the month is a slice and its opening balance the row before.
          final end = DateTime(month.year, month.month + 1);
          var opening = 0.0;
          final monthRows = <LedgerRow>[];
          for (final r in all) {
            final d = r.date;
            if (d == null) continue;
            if (d.isBefore(month)) {
              opening = r.balance;
            } else if (d.isBefore(end)) {
              monthRows.add(r);
            }
          }
          final closing = monthRows.isEmpty ? opening : monthRows.last.balance;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: _listPadding,
            children: [
              _BalanceStrip(opening: opening, closing: closing),
              const SizedBox(height: 12),
              if (monthRows.isEmpty)
                EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No entries in ${monthLabel(month)}',
                  message: 'Bills and payments of this month show here.',
                )
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, r) in monthRows.reversed.indexed) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: AppColors.border,
                          ),
                        _LedgerTile(row: r),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BalanceStrip extends StatelessWidget {
  const _BalanceStrip({required this.opening, required this.closing});

  final double opening;
  final double closing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String label, double v) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              inr(v),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          cell('Opening balance', opening),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          cell('Closing balance', closing),
        ],
      ),
    );
  }
}

/// Date · reference and detail · amount over running balance.
class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.row});

  final LedgerRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBill = row.debit > 0;
    final d = row.date?.toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Text(
                  d == null ? '—' : '${d.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                if (d != null)
                  Text(
                    DateFormat.MMM().format(d),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    row.ref,
                    maxLines: 1,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${isBill ? 'Bill' : 'Payment'} · ${row.detail}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isBill ? inr(row.debit) : '− ${inr(row.credit)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isBill ? AppColors.textPrimary : AppColors.successFg,
                ),
              ),
              Text(
                'Bal ${inr(row.balance)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
