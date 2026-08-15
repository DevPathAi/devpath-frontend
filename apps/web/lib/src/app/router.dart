import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/auth_callback_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/state/auth_state.dart';
import '../features/beta/presentation/beta_pending_page.dart';
import '../features/consent/presentation/consent_page.dart';
import '../features/content/presentation/content_page.dart';
import '../features/community/presentation/community_home_page.dart';
import '../features/community/presentation/post_create_page.dart';
import '../features/community/presentation/post_detail_page.dart';
import '../features/community/presentation/qna_detail_page.dart';
import '../features/community/presentation/question_create_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/mentor/presentation/mentor_page.dart';
import '../features/mission/presentation/mission_content_route_resolver.dart';
import '../features/mission/presentation/mission_sandbox_route_resolver.dart';
import '../features/diagnostic/presentation/diagnostic_page.dart';
import '../features/diagnostic/application/diagnostic_controller.dart';
import '../features/diagnostic/state/diagnostic_state.dart';
import '../features/path/application/path_controller.dart';
import '../features/path/presentation/path_page.dart';
import '../features/sandbox/presentation/sandbox_page.dart';
import '../features/mypage/presentation/mypage_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/shell/presentation/app_shell.dart';
import '../providers/api_providers.dart';

/// 게이트 판정(순수): 미인증→/login, 인증·동의미완→/consent(온보딩보다 앞),
/// 인증·온보딩미완→/diagnostic, 그 외 통과.
/// /auth/callback은 미인증이어도 통과(bootstrapFromCallback 진행 중이므로).
///
/// I-1 정책: [AuthLoading]은 어느 경로에서도 null(보류)을 반환한다.
/// - [AuthLoading] 체크를 `/auth/callback` 경로 체크보다 먼저 배치하여 우선순위를 명확히 한다.
///   (둘 다 null이라 결과는 무해하지만, 의도를 코드로 명시한다.)
/// - [AuthAuthenticated] 상태인 유저가 앱 재방문 시 build()의 bootstrapSession()이
///   재실행되지 않도록 bootstrapSession() 내부에서 이미 인증됨을 확인 후 조기 반환한다.
String? gateRedirect(
  AuthState auth,
  String location, {
  bool missionSpineEnabled = false,
  bool hasDiagnosticContinuation = false,
  bool diagnosticPathHandoffRequested = false,
}) {
  // I-1: 세션 복원 판정 중(AuthLoading)이면 어느 경로든 redirect 보류.
  // 이 체크가 /auth/callback 통과 로직보다 먼저 와야 우선순위가 명확하다.
  // (AuthLoading + /auth/callback도 null이므로 결과는 동일하나, 정책 명시 목적.)
  if (auth is AuthLoading) return null;

  final atLogin = location == '/login';
  final atDiagnostic = location == '/diagnostic';
  final atBetaPending = location == '/beta-pending';
  final atCallback = location == '/auth/callback';
  final atPath = location == '/path';

  if (auth is! AuthAuthenticated) {
    // 비회원 guest 진단 진입 + 미승인자 대기 페이지(/beta-pending) 허용.
    if (atLogin || atDiagnostic || atBetaPending || atCallback) return null;
    return '/login';
  }
  // 인증(토큰 보유=승인)된 유저가 대기 페이지에 오면 정상 게이트로 흡수.
  if (atBetaPending) return '/dashboard';
  final consentDone = auth.user.consentStatus == ConsentStatus.done;
  final onboardingDone = auth.user.onboardingStatus == OnboardingStatus.done;
  final atConsent = location == '/consent';
  // 동의(consent) 게이트가 온보딩(진단)보다 앞선다: 필수 동의 미완이면 /consent로.
  if (!consentDone) {
    return atConsent ? null : '/consent';
  }
  // OAuth/consent/claim 도중 auth refresh가 onboardingStatus를 갱신해도, 동일한
  // preview로 돌아와 사용자가 명시적으로 다음 CTA를 누르기 전에는 덮지 않는다.
  if (missionSpineEnabled && hasDiagnosticContinuation) {
    if (atPath && diagnosticPathHandoffRequested) return null;
    return atDiagnostic ? null : '/diagnostic';
  }
  // 동의 완료 유저가 consent 페이지에 재진입하면 onboarding 게이트로 위임한다.
  if (atConsent) {
    return onboardingDone ? '/path' : '/diagnostic';
  }
  if (!onboardingDone) {
    return atDiagnostic ? null : '/diagnostic'; // 온보딩 게이트 = 진단
  }
  if (atCallback) return '/dashboard';
  if (atLogin) return '/dashboard';
  if (atDiagnostic) return '/path';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final missionSpineEnabled = ref.watch(
    appConfigProvider.select((config) => config.missionSpineEnabled),
  );
  // auth와 continuation 변화가 같은 redirect 판정에서 원자적으로 다시 읽힌다.
  final refresh = ValueNotifier<int>(0);
  var legacyHandoffScheduled = false;
  ref.onDispose(refresh.dispose);
  void notify() => refresh.value++;
  ref.listen(authControllerProvider, (previous, next) {
    final previousUserId = switch (previous) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    final nextUserId = switch (next) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    if (previousUserId != null && previousUserId != nextUserId) {
      // PathState는 user-scoped다. logout/direct account switch에서 이전 계정의
      // complete result가 다음 계정에 재사용되지 않도록 소유 router가 폐기한다.
      ref.read(pathControllerProvider.notifier).reset();
    }
    notify();
  });
  ref.listen(diagnosticControllerProvider, (_, next) {
    if (!missionSpineEnabled &&
        next.saved &&
        !next.busy &&
        next.failure == null &&
        next.pathBranch != DiagnosticPathBranch.unknown &&
        !next.pathHandoffRequested &&
        !legacyHandoffScheduled) {
      // OFF artifact keeps the legacy automatic transition while reusing the
      // owner-safe claim/path state machine. New-path generation is still
      // requested exactly once so its completion can clear the continuation.
      // Defer until the controller's claim/complete async stack has finished;
      // clearing an existing-path continuation synchronously would invalidate
      // its owner check before onboardingCompleted is emitted.
      legacyHandoffScheduled = true;
      Timer.run(() {
        if (!ref.mounted) return;
        legacyHandoffScheduled = false;
        final current = ref.read(diagnosticControllerProvider);
        if (current.saved &&
            !current.busy &&
            current.failure == null &&
            current.pathBranch != DiagnosticPathBranch.unknown &&
            !current.pathHandoffRequested) {
          ref.read(diagnosticControllerProvider.notifier).completePathHandoff();
        }
        notify();
      });
    }
    notify();
  });
  ref.listen(pathControllerProvider, (_, next) {
    if (!ref.read(diagnosticControllerProvider).pathHandoffRequested) return;
    final diagnostic = ref.read(diagnosticControllerProvider.notifier);
    switch (next.phase) {
      case PathPhase.complete:
        diagnostic.completeSuccessfulPathHandoff();
        return;
      case PathPhase.partial || PathPhase.failed || PathPhase.killSwitch:
        diagnostic.markPathGenerationFailure(next.error);
        return;
      case PathPhase.idle || PathPhase.streaming:
        return;
    }
  });

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) => gateRedirect(
      ref.read(authControllerProvider),
      state.matchedLocation,
      missionSpineEnabled: missionSpineEnabled,
      hasDiagnosticContinuation: ref
          .read(diagnosticControllerProvider.notifier)
          .hasRestorableContinuation,
      diagnosticPathHandoffRequested: ref
          .read(diagnosticControllerProvider)
          .pathHandoffRequested,
    ),
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/beta-pending',
        builder: (_, _) => const BetaPendingPage(),
      ),
      GoRoute(path: '/consent', builder: (_, _) => const ConsentPage()),
      GoRoute(path: '/diagnostic', builder: (_, _) => const DiagnosticPage()),
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
          GoRoute(
            path: '/path/:pathId/today',
            builder: (_, _) => const DashboardPage(),
          ),
          GoRoute(path: '/path', builder: (_, _) => const PathPage()),
          GoRoute(
            path: '/mission/:taskId/content/:contentId',
            builder: (_, state) => MissionContentRouteResolver(
              taskId: state.pathParameters['taskId'],
              contentId: state.pathParameters['contentId'],
            ),
          ),
          GoRoute(
            path: '/content/:id',
            builder: (_, state) =>
                ContentPage(contentId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/mission/:taskId/sandbox',
            builder: (_, state) => MissionSandboxRouteResolver(
              taskId: state.pathParameters['taskId'],
            ),
          ),
          GoRoute(path: '/sandbox', builder: (_, _) => const SandboxPage()),
          GoRoute(path: '/mentor', builder: (_, _) => const MentorPage()),
          GoRoute(
            path: '/community',
            builder: (_, state) => CommunityHomePage(
              initialBoard: state.uri.queryParameters['board'],
              initialQuery: state.uri.queryParameters['q'],
            ),
          ),
          // '/community/new'는 '/community/:id'보다 먼저 — 선언 순서 매칭에서 'new'가
          // id로 잡히지 않도록(int.parse('new') 회피).
          GoRoute(
            path: '/community/new',
            builder: (_, _) => const QuestionCreatePage(),
          ),
          // 일반 게시글 작성(FREE/FEEDBACK) — ?board= 프리셋.
          GoRoute(
            path: '/community/new/post',
            builder: (_, state) => PostCreatePage(
              board: state.uri.queryParameters['board'] ?? 'FREE',
            ),
          ),
          // 일반 게시글(FREE/FEEDBACK) 상세 — '/community/:id'(Q&A)보다 먼저 선언해
          // '/community/post/:id'가 :id로 흡수되지 않도록 한다.
          GoRoute(
            path: '/community/post/:id',
            builder: (_, state) =>
                PostDetailPage(postId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/community/:id',
            builder: (_, state) =>
                QnaDetailPage(postId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          GoRoute(path: '/mypage', builder: (_, _) => const MyPagePage()),
        ],
      ),
    ],
  );
});
