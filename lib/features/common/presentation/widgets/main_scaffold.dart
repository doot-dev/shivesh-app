import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/providers/client_api_provider.dart';
import '../../../../../core/theme/app_colors.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  static const _destinations = [
    _NavDestination('/home', Icons.home_rounded, Icons.home_outlined, 'Home'),
    _NavDestination('/orders', Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Orders'),
    _NavDestination('/profile', Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    // Initialise FCM once the authenticated shell is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).initialize();
    });
  }

  int _locationToIndex(String loc) {
    if (loc.startsWith('/orders')) return 1;
    if (loc.startsWith('/profile')) return 2;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    final target = _destinations[index].path;
    if (target == widget.location) return;
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _locationToIndex(widget.location);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_destinations.length, (index) {
                final dest = _destinations[index];
                final isSelected = index == selectedIndex;
                return Expanded(
                  child: InkWell(
                    onTap: () => _onItemTapped(context, index),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? dest.activeIcon : dest.icon,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMuted,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dest.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          width: isSelected ? 24 : 0,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(this.path, this.activeIcon, this.icon, this.label);

  final String path;
  final IconData activeIcon;
  final IconData icon;
  final String label;
}
