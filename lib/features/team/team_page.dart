import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/access_provider.dart';
import '../../core/providers/client_api_provider.dart';
import '../../core/theme/app_colors.dart';
import '../home/providers/home_providers.dart';

/// Team (docs/06, Q1): the owner gives site engineers and the accounts person
/// their own login. Owners are made by the office only; nobody edits themselves.
final _teamProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(clientApiProvider).getTeam(),
);
final _rolesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(clientApiProvider).getTeamRoles(),
);

String _errorText(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'No connection — try again when you are online';
  }
  return 'Something went wrong';
}

class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(_teamProvider);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(_teamProvider);
    final me = ref.watch(accessProvider).value;
    final api = ref.read(clientApiProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Team')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const _AddMemberSheet(),
          );
          if (added == true) ref.invalidate(_teamProvider);
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add person'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_teamProvider),
        child: team.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errorText(e)),
              ),
            ],
          ),
          data: (people) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: people.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = people[i];
              final role = p['role'] as Map<String, dynamic>;
              final isOwner = role['isOwner'] == true;
              final isMe = p['id'] == me?.contactId;
              final active = p['isActive'] == true;
              final projects = (p['projects'] as List)
                  .map((x) => (x as Map)['projectName'])
                  .join(', ');
              final locked = isOwner || isMe; // office-only, or yourself

              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: active
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.border,
                        child: Text(
                          (p['name'] as String).isNotEmpty
                              ? (p['name'] as String)[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['name']}${isMe ? ' (you)' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${role['name']} · ${p['phone']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              p['allProjects'] == true
                                  ? 'All projects'
                                  : projects,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            if (!active)
                              const Text(
                                'Cannot sign in',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!locked)
                        PopupMenuButton<String>(
                          onSelected: (action) {
                            final id = p['id'] as String;
                            if (action == 'toggle') {
                              _run(
                                context,
                                ref,
                                () => api.updateTeamMember(id, {
                                  'isActive': !active,
                                }),
                                active
                                    ? '${p['name']} can no longer sign in'
                                    : '${p['name']} can sign in again',
                              );
                            } else {
                              _run(
                                context,
                                ref,
                                () => api.removeTeamMember(id),
                                '${p['name']} removed',
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                active ? 'Stop access' : 'Give access again',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text(
                                'Remove',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AddMemberSheet extends ConsumerStatefulWidget {
  const _AddMemberSheet();

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  int? _roleId;
  bool _allProjects = true;
  final _projects = <String>{};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(clientApiProvider).addTeamMember({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'roleId': _roleId,
        'allProjects': _allProjects,
        'projects': _projects.toList(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(_rolesProvider).value ?? const [];
    final projects = ref.watch(projectsProvider).value ?? const [];
    _roleId ??= roles.isNotEmpty ? roles.first['id'] as int : null;
    final selectedRole = roles.where((r) => r['id'] == _roleId).firstOrNull;

    return Padding(
      // Lift above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add a person',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'They sign in with their own number and the OTP.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _roleId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final r in roles)
                  DropdownMenuItem(
                    value: r['id'] as int,
                    child: Text(r['name'] as String),
                  ),
              ],
              onChanged: (v) => setState(() => _roleId = v),
            ),
            if (selectedRole?['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  selectedRole!['description'] as String,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All projects'),
              subtitle: const Text('Turn off to choose sites'),
              value: _allProjects,
              onChanged: (v) => setState(() => _allProjects = v),
            ),
            if (!_allProjects)
              for (final p in projects)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: _projects.contains(p.id),
                  onChanged: (v) => setState(
                    () => v == true
                        ? _projects.add(p.id)
                        : _projects.remove(p.id),
                  ),
                ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
