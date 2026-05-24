import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/otp_page.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/common/presentation/widgets/main_scaffold.dart';
import 'features/common/presentation/pages/splash_page.dart';
import 'features/create_order/presentation/pages/create_order_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/home/presentation/pages/project_detail_page.dart';
import 'features/notifications/presentation/pages/notifications_page.dart';
import 'features/orders/presentation/pages/order_details_page.dart';
import 'features/orders/presentation/pages/orders_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final isLoggedIn = _ref.read(authProvider).isLoggedIn;
    final loc = state.matchedLocation;

    final isAuthRoute =
        loc == '/login' || loc == '/otp' || loc == '/splash';

    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && (loc == '/login' || loc == '/otp')) return '/home';
    return null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/otp', builder: (context, state) => const OtpPage()),
      ShellRoute(
        builder: (context, state, child) =>
            MainScaffold(location: state.uri.toString(), child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailsPage(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/projects/:id',
        builder: (context, state) =>
            ProjectDetailPage(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/create-order',
        builder: (context, state) => const CreateOrderPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
    ],
  );
});
