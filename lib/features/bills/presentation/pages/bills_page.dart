import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/client_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/links.dart';
import '../../data/models/bill_models.dart';
import '../../providers/bill_providers.dart';

String inr(double v) {
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

String _date(DateTime? d) => d == null ? '—' : '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

/// Bills & invoices (W16): every issued bill, with the invoice PDF one tap away —
/// no more waiting for it on WhatsApp.
class BillsPage extends ConsumerWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bills & invoices')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(billsProvider),
        child: bills.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('Could not load bills. Pull to retry.'))]),
          data: (list) => list.isEmpty
              ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('No bills yet.'))])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _BillTile(bill: list[i]),
                ),
        ),
      ),
    );
  }
}

class _BillTile extends ConsumerWidget {
  const _BillTile({required this.bill});
  final ClientBill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final paid = bill.status == 'PAID';
    final overdue = bill.daysOverdue > 0;
    final (label, color) = paid
        ? ('Paid', Colors.green)
        : overdue
            ? ('Overdue · ${bill.daysOverdue} days', Colors.red)
            : ('Due ${_date(bill.dueDate)}', AppColors.secondary);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(bill.billNo, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              Text(inr(bill.amount), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text('${bill.orderId} · ${bill.product} · ${bill.projectName}', style: theme.textTheme.bodySmall),
            Text('Issued ${_date(bill.issueDate)}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Row(children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Invoice'),
                onPressed: () async {
                  final ok = await openServerLink(ref, ref.read(clientApiProvider).invoicePath(bill.billNo));
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the invoice')));
                  }
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
