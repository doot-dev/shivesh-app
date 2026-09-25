import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../../../core/widgets/month_bar.dart';
import '../data/models/bill_models.dart';

/// The client's real credit position (P1.14).
final creditProvider = FutureProvider.autoDispose<CreditPosition>((ref) {
  return ref.read(clientApiProvider).getCredit();
});

/// Statement: bills and payments with a running balance (Phase 2).
final ledgerProvider = FutureProvider.autoDispose<List<LedgerRow>>((ref) {
  return ref.read(clientApiProvider).getLedger();
});

/// The month the Bills screen shows, on both tabs. Starts at this month.
class BillMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => monthOf(DateTime.now());

  void setMonth(DateTime month) => state = monthOf(month);
}

final billMonthProvider = NotifierProvider<BillMonthNotifier, DateTime>(
  BillMonthNotifier.new,
);

/// The client's issued bills (P1.16) for the selected month, by invoice date.
final billsProvider = FutureProvider.autoDispose<List<ClientBill>>((ref) {
  final month = ref.watch(billMonthProvider);
  return ref
      .read(clientApiProvider)
      .getBills(dateFrom: monthFromIso(month), dateTo: monthToIso(month));
});
