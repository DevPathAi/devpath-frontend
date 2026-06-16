import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/state/auth_state.dart';
import '../features/shell/presentation/admin_shell.dart';

/// 가드: 미인증→/login, 비관리자→/forbidden, 관리자가 /login이면→/dashboard.
String? adminGuard(AdminAuthState auth, String location) {
  final atLogin = location == '/login';
  if (auth is! AdminAuthed) return atLogin ? null : '/login';
  if (!auth.isAdmin) return location == '/forbidden' ? null : '/forbidden';
  if (atLogin) return '/dashboard';
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
      GoRoute(path: '/login', builder: (_, __) => const AdminLoginPage()),
      GoRoute(
          path: '/forbidden',
          builder: (_, __) => const Scaffold(
              body: Center(child: Text('권한이 없습니다 (ADMIN/OWNER 전용)')))),
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          // 각 화면은 Task 4~6에서 추가
        ],
      ),
    ],
  );
});
