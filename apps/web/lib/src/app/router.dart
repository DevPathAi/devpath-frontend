import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/state/auth_state.dart';
import '../features/common/presentation/placeholder_page.dart';
import '../features/onboarding/presentation/onboarding_placeholder.dart';
import '../features/shell/presentation/app_shell.dart';

/// 게이트 판정(순수): 미인증→/login, 인증·온보딩미완→/onboarding, 그 외 통과.
String? gateRedirect(AuthState auth, String location) {
  final atLogin = location == '/login';
  final atOnboarding = location == '/onboarding';

  if (auth is! AuthAuthenticated) {
    return atLogin ? null : '/login';
  }
  final onboardingDone = auth.user.onboardingStatus == OnboardingStatus.done;
  if (!onboardingDone) {
    return atOnboarding ? null : '/onboarding';
  }
  if (atLogin || atOnboarding) return '/dashboard';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // auth 변화 → refreshListenable 발화 → redirect 재평가.
  final refresh = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, next) => refresh.value = next);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) =>
        gateRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingPlaceholder(),
      ),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) =>
                const PlaceholderPage(title: '대시보드', icon: DpIcons.dashboard),
          ),
          GoRoute(
            path: '/path',
            builder: (_, _) =>
                const PlaceholderPage(title: '학습 경로', icon: DpIcons.path),
          ),
          GoRoute(
            path: '/mentor',
            builder: (_, _) =>
                const PlaceholderPage(title: 'AI 멘토', icon: DpIcons.mentor),
          ),
          GoRoute(
            path: '/community',
            builder: (_, _) =>
                const PlaceholderPage(title: '커뮤니티', icon: DpIcons.community),
          ),
        ],
      ),
    ],
  );
});
