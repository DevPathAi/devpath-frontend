import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/community_home_page.dart';
import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// T1(auth·커뮤니티·LCS) 실API 계약은 소스 대조로 정합 확인됨(2026-07-03 감사,
/// docs/superpowers/reports/2026-07-03-web-realapi-contract-audit.md).
/// 이 스모크는 그 위의 **골든패스 UI/라우팅 흐름**(DONE 유저 → 대시보드 → 커뮤니티 목록)을
/// 회귀 고정한다. 목 프로파일이므로 실API 계약 회귀가 아니라 게이트 통과·화면 전이·목록
/// 렌더 회귀를 커버한다(실API 계약 회귀는 부분 bootRun 스모크의 몫).
class _DoneUserAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: 'u-done',
      email: 'learner@devpath.ai',
      nickname: '지수',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );
}

void main() {
  testWidgets('DONE 유저 → 대시보드 → 커뮤니티 탭 → 목록 렌더', (tester) async {
    tester.view.physicalSize = const Size(1200, 900); // ≥840 → NavigationRail
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_DoneUserAuthController.new),
          communityListProvider.overrideWithValue(
            ({String? board, String? tag, String? sort}) async => [
              const CommunityPostSummary(
                id: 1,
                title: '실API 골든패스 질문',
                replyCount: 2,
              ),
            ],
          ),
        ],
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    // DONE 유저 → 게이트 통과 → /dashboard(초기 위치)
    expect(find.byType(DashboardPage), findsOneWidget);

    // 셸 네비게이션: 커뮤니티 탭 → /community
    await tester.tap(find.text('커뮤니티'));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityHomePage), findsOneWidget);
    expect(find.text('실API 골든패스 질문'), findsOneWidget);
  });
}
