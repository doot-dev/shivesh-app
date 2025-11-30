import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/otp_page.dart';
import 'features/common/presentation/widgets/main_scaffold.dart';
import 'features/create_order/presentation/pages/create_order_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/notifications/presentation/pages/notifications_page.dart';
import 'features/orders/presentation/pages/order_details_page.dart';
import 'features/orders/presentation/pages/orders_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(
          location: state.uri.toString(),
          child: child,
        ),
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
