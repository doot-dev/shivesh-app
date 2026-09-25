import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client_api_provider.dart';

/// The signed-in person and what their client role allows (GET /client/me,
/// docs/06). Menus and buttons are built from this; the server enforces the
/// same rules, so hiding a button is convenience, not security.
class ClientAccess {
  const ClientAccess({
    required this.name,
    required this.roleName,
    required this.isOwner,
    required this.permissions,
    required this.allProjects,
    required this.projects,
    this.contactId,
    this.phone,
    this.companyName,
  });

  factory ClientAccess.fromJson(Map<String, dynamic> j) {
    final role = (j['role'] as Map?) ?? const {};
    return ClientAccess(
      contactId: j['contactId'] as String?,
      name: j['name'] as String? ?? '',
      phone: j['phone'] as String?,
      roleName: role['name'] as String? ?? '',
      isOwner: role['isOwner'] == true,
      companyName: (j['company'] as Map?)?['companyName'] as String?,
      permissions: {
        ...((j['permissions'] as List?) ?? const []).cast<String>(),
      },
      allProjects: j['allProjects'] != false,
      projects: ((j['projects'] as List?) ?? const [])
          .map((p) => (p as Map)['projectName'] as String? ?? '')
          .toList(),
    );
  }

  final String? contactId;
  final String name;
  final String? phone;
  final String roleName;
  final bool isOwner;
  final String? companyName;
  final Set<String> permissions;
  final bool allProjects;
  final List<String> projects;

  bool can(String key) => permissions.contains(key);
}

final accessProvider = FutureProvider<ClientAccess>(
  (ref) => ref.read(clientApiProvider).getMe(),
);

/// `can('orders.create')` for widgets.
///
/// Still loading = no, so nothing flashes on screen that the role then takes
/// away. Failed (no network on first launch, or a server without /me) = yes,
/// like before roles existed: the server still refuses what the role forbids.
extension AccessRef on WidgetRef {
  bool can(String permission) {
    final access = watch(accessProvider);
    return access.value?.can(permission) ?? access.hasError;
  }
}
