import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../../home/data/models/home_models.dart';
import '../../home/providers/home_providers.dart';

/// Products (name + grade) assigned to a specific project.
final projectProductsProvider =
    FutureProvider.family<List<ProjectProduct>, String>((ref, projectId) {
      return ref.read(clientApiProvider).getProjectProducts(projectId);
    });

final projectNamesProvider = FutureProvider<List<String>>((ref) async {
  final projects = await ref.watch(projectsProvider.future);
  return projects.map((p) => p.name).toList();
});
