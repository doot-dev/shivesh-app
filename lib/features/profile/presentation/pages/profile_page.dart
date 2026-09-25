import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_providers.dart';
import 'package:go_router/go_router.dart';
import '../../../bills/presentation/pages/bills_page.dart' show inr;
import '../../../bills/providers/bill_providers.dart';
import '../../data/models/user_profile.dart';
import '../../providers/profile_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load profile',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(userProfileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (profile) => _ProfileBody(profile: profile),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.primary,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Row(
                children: [
                  const BackButton(color: Colors.white),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Profile',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),

        Transform.translate(
          offset: const Offset(0, -40),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.border,
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Text(
                        profile.name.isNotEmpty
                            ? profile.name[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                profile.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profile.email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -24),
            child: SingleChildScrollView(
              // Bottom padding clears the floating nav bar (extendBody: true).
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...[
                    Text(
                      'Credit',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _LiveCreditCard(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Bills & invoices'),
                        onPressed: () => context.push('/bills'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Company details',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CompanyCard(profile: profile),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context, ref),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _CompanyRow(
            icon: Icons.business_rounded,
            label: 'Company',
            value: profile.companyName,
          ),
          if (profile.address.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),
            _CompanyRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: profile.address,
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          _CompanyRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: profile.phone,
          ),
        ],
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Real credit from the server (P1.14): used vs limit, what's due and when.
class _LiveCreditCard extends ConsumerWidget {
  const _LiveCreditCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final credit = ref.watch(creditProvider);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: credit.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const Text('Credit details unavailable right now'),
        data: (c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment due', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(inr(c.outstanding), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (c.overdueAmount > 0)
              Text('${inr(c.overdueAmount)} overdue', style: theme.textTheme.bodySmall?.copyWith(color: Colors.red, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: c.utilisation,
                backgroundColor: AppColors.border,
                color: c.flag == 'OK' ? AppColors.primary : Colors.red,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              c.limit > 0
                  ? 'Used ${inr(c.used)} of ${inr(c.limit + c.extraUnused + c.extraInUse)} · available ${inr(c.available)}'
                  : 'Credit limit not set',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            if (c.extraUnused > 0 || c.extraInUse > 0)
              Text('Includes extra credit ${inr(c.extraUnused)} unused${c.extraInUse > 0 ? ' · ${inr(c.extraInUse)} in use' : ''}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            if (c.advance > 0)
              Text('Advance with Shivesh: ${inr(c.advance)}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.green)),
            if (c.daysLeft != null)
              Text('Next payment due in ${c.daysLeft} days', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
