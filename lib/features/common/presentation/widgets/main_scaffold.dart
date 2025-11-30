import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  static const _destinations = [
    _NavDestination('/home', Icons.home_outlined, 'Home'),
    _NavDestination('/orders', Icons.receipt_long_outlined, 'Orders'),
    _NavDestination('/profile', Icons.person_outline, 'Profile'),
  ];

  int _locationToIndex(String currentLocation) {
    if (currentLocation.startsWith('/orders')) {
      return 1;
    }
    if (currentLocation.startsWith('/profile')) {
      return 2;
    }
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    final target = _destinations[index].path;
    if (target == location) {
      return;
    }
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(context, index),
        items: _destinations
            .map(
              (destination) => BottomNavigationBarItem(
                icon: Icon(destination.icon),
                label: destination.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(this.path, this.icon, this.label);

  final String path;
  final IconData icon;
  final String label;
}
