import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/pending_deep_link_controller.dart';
import '../features/auth/application/web_activation_launcher.dart';
import '../features/auth/presentation/activation_handoff_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/session_unavailable_page.dart';
import '../features/auth/state/auth_state.dart';
import '../features/community/presentation/community_page.dart';
import '../features/community/presentation/qna_detail_page.dart';
import '../features/community/presentation/quick_capture_page.dart';
import '../features/dashboard/application/dashboard_controller.dart';
import '../features/learning/presentation/content_viewer_page.dart';
import '../features/learning/application/content_controller.dart';
import '../features/learning/application/learn_controller.dart';
import '../features/learning/presentation/learn_page.dart';
import '../features/mission/presentation/mobile_mission_route_resolvers.dart';
import '../features/mission/state/mobile_mission_route.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/shell/presentation/mobile_shell.dart';
import '../features/today/presentation/today_page.dart';

/// 모바일 라우터 게이트.
/// - AuthLoading: 모든 리다이렉트 보류(부팅 세션 복원 중).
/// - 미인증: /login 외 모든 경로 → /login.
/// - 인증 + 필수 동의 미완료: /consent.
/// - 동의 완료 + 진단/경로 미완료: native 진단 대신 /activation 웹 handoff.
/// - 모든 gate 완료: 로그인 전에 보존한 canonical deep link를 복구.
String? gateRedirect(
  AuthState auth,
  String location, {
  String? pendingLocation,
}) {
  if (auth is AuthLoading) return null;
  final atLogin = location == '/login';
  final atSessionUnavailable = location == '/session-unavailable';
  if (auth is AuthSessionUnavailable) {
    return atSessionUnavailable ? null : '/session-unavailable';
  }
  if (auth is! AuthAuthenticated) {
    return atLogin ? null : '/login';
  }

  final atConsent = location == '/consent';
  final atActivation = location == '/activation';
  if (auth.user.consentStatus != ConsentStatus.done) {
    return atConsent ? null : '/consent';
  }
  if (auth.user.onboardingStatus != OnboardingStatus.done) {
    return atActivation ? null : '/activation';
  }
  if (pendingLocation != null && location != pendingLocation) {
    return pendingLocation;
  }
  if (atLogin || atConsent || atActivation || atSessionUnavailable) {
    return '/home';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  var pendingConsumeScheduled = false;
  ref.onDispose(refresh.dispose);
  void notify() => refresh.value++;
  ref.listen(authControllerProvider, (previous, next) {
    final previousOwner = switch (previous) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    final nextOwner = switch (next) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    if (previousOwner != null && previousOwner != nextOwner) {
      ref.invalidate(contentControllerProvider);
      ref.invalidate(learnControllerProvider);
      ref.invalidate(dashboardControllerProvider);
    }
    notify();
  });
  ref.listen(pendingDeepLinkProvider, (_, _) => notify());

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final canonical = MobileMissionRoute.tryParse(location);
      final pending = ref.read(pendingDeepLinkProvider);
      if (auth is! AuthAuthenticated &&
          canonical != null &&
          pending != canonical.location) {
        unawaited(
          ref
              .read(pendingDeepLinkProvider.notifier)
              .capture(canonical.location),
        );
      }
      final redirect = gateRedirect(auth, location, pendingLocation: pending);
      if (redirect == null &&
          pending == location &&
          auth is AuthAuthenticated &&
          auth.user.consentStatus == ConsentStatus.done &&
          auth.user.onboardingStatus == OnboardingStatus.done &&
          !pendingConsumeScheduled) {
        pendingConsumeScheduled = true;
        scheduleMicrotask(() {
          pendingConsumeScheduled = false;
          if (ref.mounted) {
            ref.read(pendingDeepLinkProvider.notifier).consume();
          }
        });
      }
      return redirect;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/consent',
        builder: (_, _) =>
            const ActivationHandoffPage(step: WebActivationStep.consent),
      ),
      GoRoute(
        path: '/activation',
        builder: (_, _) =>
            const ActivationHandoffPage(step: WebActivationStep.diagnostic),
      ),
      GoRoute(
        path: '/session-unavailable',
        builder: (_, _) => const SessionUnavailablePage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MobileShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const TodayPage()),
              GoRoute(
                path: '/path/:pathId/today',
                builder: (_, state) => MobileTodayRouteResolver(
                  pathId: state.pathParameters['pathId'],
                ),
              ),
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
              GoRoute(
                path: '/mission/:taskId/content/:contentId',
                builder: (_, state) => MobileMissionContentRouteResolver(
                  taskId: state.pathParameters['taskId'],
                  contentId: state.pathParameters['contentId'],
                ),
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
