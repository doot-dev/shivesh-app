import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/providers/access_provider.dart';
import '../../../../../core/providers/client_api_provider.dart';
import '../../../../../core/realtime/realtime_providers.dart';
import '../../../../../core/theme/app_colors.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  // A tab with a permission shows only if the person's client role has it (docs/06).
  static const _destinations = [
    _NavDestination('/home', Icons.home_rounded, Icons.home_outlined, 'Home'),
    _NavDestination(
      '/orders',
      Icons.local_shipping_rounded,
      Icons.local_shipping_outlined,
      'Orders',
      'orders.view',
    ),
    _NavDestination(
      '/bills',
      Icons.receipt_long_rounded,
      Icons.receipt_long_outlined,
      'Bills',
      'bills.view',
    ),
    _NavDestination(
      '/cube-tests',
      Icons.science_rounded,
      Icons.science_outlined,
      'Cube tests',
      'cubeTests.view',
    ),
    _NavDestination(
      '/profile',
      Icons.person_rounded,
      Icons.person_outline_rounded,
      'Profile',
    ),
  ];

  // A role changed in the panel reaches this phone when the app comes back
  // to the front — no need to sign out and in again.
  late final _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(accessProvider),
  );

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _lifecycle;
    // Initialise FCM once the authenticated shell is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).initialize();
      // Open the live socket here — this shell only exists once the client is
      // logged in, and reading it anchors the connection for the whole session
      // instead of waiting for an order screen to lazily create it.
      ref.read(socketServiceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _destinations
        .where((d) => d.permission == null || ref.can(d.permission!))
        .toList();
    final selectedIndex = tabs
        .indexWhere((d) => widget.location.startsWith(d.path))
        .clamp(0, tabs.length - 1);

    // Keep the socket provider alive for as long as the authenticated shell is.
    ref.watch(socketServiceProvider);

    return Scaffold(
      extendBody: true,
      // Cross-fade between tabs so switching sections doesn't hard-cut.
      body: AnimatedSwitcher(
        duration: AppStyles.medium,
        switchInCurve: AppStyles.curve,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        // Key by tab, not by route — otherwise pushing a detail page inside a
        // tab would replay the transition.
        child: KeyedSubtree(key: ValueKey(selectedIndex), child: widget.child),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          // Deliberately NOT SafeArea. The bar already floats inside a 10px
          // margin, so adding the full gesture inset (~24-48px) on top of that
          // is what made it look oversized. Clamp it instead: enough to clear
          // the gesture bar, never more.
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom.clamp(0.0, 8.0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              children: List.generate(tabs.length, (index) {
                final dest = tabs[index];
                final isSelected = index == selectedIndex;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (dest.path != widget.location) context.go(dest.path);
                    },
                    child: AnimatedContainer(
                      duration: AppStyles.medium,
                      curve: AppStyles.curve,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        // The selected tab gets a soft brand-tinted pill.
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.09)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.08 : 1,
                            duration: AppStyles.medium,
                            curve: AppStyles.curveEmphasised,
                            child: Icon(
                              isSelected ? dest.activeIcon : dest.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 21,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: AppStyles.fast,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.1,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                            // Five tabs on a ~300dp Fold cover screen: never wrap.
                            child: Text(
                              dest.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
  const _NavDestination(
    this.path,
    this.activeIcon,
    this.icon,
    this.label, [
    this.permission,
  ]);

  final String path;
  final IconData activeIcon;
  final IconData icon;
  final String label;
  final String? permission;
}
