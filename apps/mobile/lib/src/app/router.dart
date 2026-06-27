import 'package:dp_core/dp_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/state/auth_state.dart';
import '../features/community/presentation/community_page.dart';
import '../features/community/presentation/qna_detail_page.dart';
import '../features/community/presentation/quick_capture_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/learning/presentation/content_viewer_page.dart';
import '../features/learning/presentation/learn_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/shell/presentation/mobile_shell.dart';

/// 모바일 라우터 게이트.
/// - AuthLoading: 모든 리다이렉트 보류(부팅 세션 복원 중).
/// - 미인증: /login 외 모든 경로 → /login.
/// - 인증 + onboardingStatus != DONE: /onboarding 강제(온보딩 미완료).
/// - 인증 + 온보딩 완료 + /login·/onboarding: → /home.
String? gateRedirect(AuthState auth, String location) {
  if (auth is AuthLoading) return null;
  final atLogin = location == '/login';
  if (auth is! AuthAuthenticated) {
    return atLogin ? null : '/login';
  }
  final atOnboarding = location == '/onboarding';
  if (auth.user.onboardingStatus != OnboardingStatus.done) {
    return atOnboarding ? null : '/onboarding';
  }
  if (atLogin || atOnboarding) return '/home';
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
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
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
                builder: (_, _) => const LearnPage(),
                routes: [
                  GoRoute(
                    path: 'content/:slug',
                    builder: (_, state) =>
                        ContentViewerPage(slug: state.pathParameters['slug']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (_, _) => const CommunityPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, _) => const QuickCapturePage(),
                  ),
                  GoRoute(
                    path: 'posts/:id',
                    builder: (_, state) =>
                        QnaDetailPage(postId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (_, _) => const NotificationsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
