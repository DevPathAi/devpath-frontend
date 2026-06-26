import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/state/auth_state.dart';
import '../features/common/presentation/placeholder_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/shell/presentation/mobile_shell.dart';

/// 모바일 라우터 게이트.
/// - AuthLoading: 모든 리다이렉트 보류(부팅 세션 복원 중).
/// - 미인증: /login 외 모든 경로 → /login.
/// - 인증 + /login: → /home.
/// 온보딩 게이트는 후속(모바일은 post-onboarding 진입; 목 사용자 onboardingStatus=DONE).
String? gateRedirect(AuthState auth, String location) {
  if (auth is AuthLoading) return null;
  final atLogin = location == '/login';
  if (auth is! AuthAuthenticated) {
    return atLogin ? null : '/login';
  }
  if (atLogin) return '/home';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, next) => refresh.value = next);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) =>
        gateRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MobileShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const DashboardPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/learn',
                builder: (_, _) => const PlaceholderPage(title: '학습'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (_, _) => const PlaceholderPage(title: '커뮤니티'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
