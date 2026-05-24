import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../../orders/providers/orders_providers.dart';
import '../../orders/data/models/order_models.dart';
import '../data/models/home_models.dart';

final projectsProvider = FutureProvider<List<ProjectSummary>>((ref) {
  return ref.read(clientApiProvider).getProjects();
});

final homeActiveOrdersProvider = FutureProvider((ref) {
  return ref.watch(activeOrdersProvider.future);
});

final projectDetailProvider =
    FutureProvider.family<ProjectDetail, String>((ref, projectId) {
  return ref.read(clientApiProvider).getProjectDetail(projectId);
});

final projectActiveOrdersProvider =
    FutureProvider.family<List<Order>, String>((ref, projectId) {
  return ref
      .read(clientApiProvider)
      .getProjectOrders(projectId, type: 'active');
});

final projectPastOrdersProvider =
    FutureProvider.family<List<Order>, String>((ref, projectId) {
  return ref.read(clientApiProvider).getProjectOrders(projectId, type: 'past');
});
