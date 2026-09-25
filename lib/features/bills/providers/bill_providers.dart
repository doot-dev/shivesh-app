import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../data/models/bill_models.dart';

/// The client's real credit position (P1.14).
final creditProvider = FutureProvider.autoDispose<CreditPosition>((ref) {
  return ref.read(clientApiProvider).getCredit();
});

/// The client's issued bills (P1.16).
final billsProvider = FutureProvider.autoDispose<List<ClientBill>>((ref) {
  return ref.read(clientApiProvider).getBills();
});
