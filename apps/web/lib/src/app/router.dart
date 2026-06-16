import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/state/auth_state.dart';
import '../features/content/presentation/content_page.dart';
import '../features/community/presentation/community_home_page.dart';
import '../features/community/presentation/qna_detail_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/mentor/presentation/mentor_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/path/presentation/path_page.dart';
import '../features/sandbox/presentation/sandbox_page.dart';
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
  if (atLogin) return '/dashboard';
  // ENG-REVIEW: 완료 유저의 /onboarding 재진입은 게이트에서 직접 /path로 —
  // 진단 화면 재노출 회귀 차단(null 방치 대신).
  if (atOnboarding) return '/path';
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
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/path', builder: (_, _) => const PathPage()),
          GoRoute(
            path: '/content/:id',
            builder: (_, state) =>
                ContentPage(contentId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/sandbox', builder: (_, _) => const SandboxPage()),
          GoRoute(path: '/mentor', builder: (_, _) => const MentorPage()),
          GoRoute(
            path: '/community',
            builder: (_, _) => const CommunityHomePage(),
          ),
          GoRoute(
            path: '/community/:id',
            builder: (_, state) =>
                QnaDetailPage(postId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});
