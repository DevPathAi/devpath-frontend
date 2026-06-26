import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/auth_callback_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/state/auth_state.dart';
import '../features/content/presentation/content_page.dart';
import '../features/community/presentation/community_home_page.dart';
import '../features/community/presentation/qna_detail_page.dart';
import '../features/community/presentation/question_create_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/mentor/presentation/mentor_page.dart';
import '../features/diagnostic/presentation/diagnostic_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/path/presentation/path_page.dart';
import '../features/sandbox/presentation/sandbox_page.dart';
import '../features/shell/presentation/app_shell.dart';

/// 게이트 판정(순수): 미인증→/login, 인증·온보딩미완→/onboarding, 그 외 통과.
/// /auth/callback은 미인증이어도 통과(bootstrapFromCallback 진행 중이므로).
///
/// I-1 정책: [AuthLoading]은 어느 경로에서도 null(보류)을 반환한다.
/// - [AuthLoading] 체크를 `/auth/callback` 경로 체크보다 먼저 배치하여 우선순위를 명확히 한다.
///   (둘 다 null이라 결과는 무해하지만, 의도를 코드로 명시한다.)
/// - [AuthAuthenticated] 상태인 유저가 앱 재방문 시 build()의 bootstrapSession()이
///   재실행되지 않도록 bootstrapSession() 내부에서 이미 인증됨을 확인 후 조기 반환한다.
String? gateRedirect(AuthState auth, String location) {
  // I-1: 세션 복원 판정 중(AuthLoading)이면 어느 경로든 redirect 보류.
  // 이 체크가 /auth/callback 통과 로직보다 먼저 와야 우선순위가 명확하다.
  // (AuthLoading + /auth/callback도 null이므로 결과는 동일하나, 정책 명시 목적.)
  if (auth is AuthLoading) return null;

  // OAuth 콜백 경로는 세션 복원 전이므로 게이트를 통과시킨다.
  if (location == '/auth/callback') return null;

  final atLogin = location == '/login';
  final atDiagnostic = location == '/diagnostic';

  if (auth is! AuthAuthenticated) {
    if (atLogin || atDiagnostic) return null; // 비회원 guest 진단 진입 허용
    return '/login';
  }
  final onboardingDone = auth.user.onboardingStatus == OnboardingStatus.done;
  if (!onboardingDone) {
    return atDiagnostic ? null : '/diagnostic'; // 온보딩 게이트 = 진단
  }
  if (atLogin) return '/dashboard';
  if (atDiagnostic) return '/path';
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
      GoRoute(path: '/diagnostic', builder: (_, _) => const DiagnosticPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      // OAuth 콜백: platform이 이 URL로 리다이렉트. bootstrapFromCallback() 호출 후
      // 게이트가 인증 상태에 따라 분기한다.
      GoRoute(
        path: '/auth/callback',
        builder: (_, _) => const AuthCallbackPage(),
      ),
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
          // '/community/new'는 '/community/:id'보다 먼저 — 선언 순서 매칭에서 'new'가
          // id로 잡히지 않도록(int.parse('new') 회피).
          GoRoute(
            path: '/community/new',
            builder: (_, _) => const QuestionCreatePage(),
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
