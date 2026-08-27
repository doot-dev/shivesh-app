import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/client_api_provider.dart';
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
import 'core/theme/app_colors.dart';
import 'features/profile/presentation/pages/profile_page.dart';

/// Slide-up + fade transition for pushed detail screens.
///
/// GoRouter's default on Android is a hard cut for custom builders; this keeps
/// navigation feeling continuous with the rest of the motion in the app.
CustomTransitionPage<void> _slidePage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppStyles.medium,
    reverseTransitionDuration: AppStyles.fast,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppStyles.curve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final isLoggedIn = _ref.read(authProvider).isLoggedIn;
    final loc = state.matchedLocation;

    // Login is 2-step: /login collects the number, /otp completes it. Both must
    // stay reachable while logged out.
    final isAuthRoute = loc == '/login' || loc == '/otp' || loc == '/splash';

    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && (loc == '/login' || loc == '/otp')) return '/home';
    return null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  final router = GoRouter(
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
        pageBuilder: (context, state) => _slidePage(
          state,
          OrderDetailsPage(orderId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/projects/:id',
        pageBuilder: (context, state) => _slidePage(
          state,
          ProjectDetailPage(projectId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/create-order',
        pageBuilder: (context, state) =>
            _slidePage(state, const CreateOrderPage()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _slidePage(state, const NotificationsPage()),
      ),
    ],
  );

  // Notification taps open the thing the notification is about.
  //
  // Both guards are deliberate: routing while signed out would land the user on
  // a screen that 401s, and the redirect would bounce them to /login anyway.
  final notifications = ref.read(notificationServiceProvider);

  final orderSub = notifications.onOrderTapped.listen((orderCode) {
    if (!ref.read(authProvider).isLoggedIn) return;
    router.push('/orders/$orderCode');
  });

  // The daily reminder has no order to open yet — send them to place one.
  final reminderSub = notifications.onReminderTapped.listen((_) {
    if (!ref.read(authProvider).isLoggedIn) return;
    router.push('/create-order');
  });

  ref.onDispose(() {
    orderSub.cancel();
    reminderSub.cancel();
  });

  return router;
});
