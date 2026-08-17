import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/auth_callback_page.dart';
import '../features/auth/presentation/forbidden_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/ads/presentation/ads_page.dart';
import '../features/auth/state/auth_state.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/shell/presentation/admin_shell.dart';
import '../features/support/presentation/support_page.dart';
import '../features/users/presentation/users_page.dart';

/// 가드: 미인증→/login, 비관리자→/forbidden, 관리자가 /login|/auth/callback이면→/dashboard.
String? adminGuard(AdminAuthState auth, String location) {
  final atLogin = location == '/login';
  final atCallback = location == '/auth/callback';
  if (auth is! AdminAuthed) return (atLogin || atCallback) ? null : '/login';
  if (!auth.isAdmin) return location == '/forbidden' ? null : '/forbidden';
  if (atLogin || atCallback) return '/dashboard';
  return null;
}

final adminRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AdminAuthState>(ref.read(adminAuthProvider));
  ref.onDispose(refresh.dispose);
  ref.listen(adminAuthProvider, (_, next) => refresh.value = next);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) =>
        adminGuard(ref.read(adminAuthProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const AdminLoginPage()),
      GoRoute(
        path: '/auth/callback',
        builder: (_, _) => const AdminAuthCallbackPage(),
      ),
      GoRoute(
        path: '/forbidden',
        builder: (_, _) => const AdminForbiddenPage(),
      ),
      ShellRoute(
        builder: (_, _, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const AdminDashboardPage(),
          ),
          GoRoute(path: '/users', builder: (_, _) => const AdminUsersPage()),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsPage()),
          GoRoute(path: '/support', builder: (_, _) => const SupportPage()),
          GoRoute(path: '/ads', builder: (_, _) => const AdminAdsPage()),
        ],
      ),
    ],
  );
});
