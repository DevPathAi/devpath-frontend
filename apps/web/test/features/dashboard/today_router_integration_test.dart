// S3-P2: 셸이 상단 헤더(56) + 고정 푸터(약 41)로 바뀌어 기본 800x600 테스트 화면에서는
// Today 의 CTA 가 접힌 아래로 내려간다. 대시보드는 CustomScrollView 라 실제 사용자는
// 스크롤로 닿는다 — 이 테스트들은 스크롤하지 않으므로 세로만 키운다.
// 폭은 800 을 유지한다: 1200 으로 키우면 샌드박스가 >=1024 의 2페인 분기로 들어가고
// 그 분기는 1033px 높이(옛 셸의 세로 예산)에서도 39px 넘친다 — P2 와 무관한 선행 결함이라
// 여기서 건드리지 않는다.
import 'dart:ui' show Size;

import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/content/presentation/content_page.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:devpath_web/src/features/sandbox/presentation/sandbox_page.dart';
import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _missionSpineConfig = AppConfig(
  baseUrl: 'https://mock.devpath.ai',
  useMock: true,
  missionSpineEnabled: true,
);

class _AuthedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: 'router-user',
      email: 'router@devpath.ai',
      nickname: '라우터 사용자',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );
}

class _NoActivePathApi extends LearningPathApi {
  _NoActivePathApi() : super(ApiClient(Dio()));

  @override
  Future<CurrentMission> currentMission() async => CurrentMission.fromJson({
    'outcome': 'NO_ACTIVE_PATH',
    'pathId': null,
    'weekNum': null,
    'tasks': <Object?>[],
    'nextTask': null,
    'pathCompleted': false,
  });
}

ProviderScope _app({LearningPathApi? learningPathApi}) => ProviderScope(
  overrides: [
    appConfigProvider.overrideWithValue(_missionSpineConfig),
    authControllerProvider.overrideWith(_AuthedController.new),
    adFetchProvider.overrideWithValue((_) async => null),
    if (learningPathApi != null)
      learningPathApiProvider.overrideWithValue(learningPathApi),
  ],
  child: const DevPathWebApp(),
);

void main() {
  testWidgets('NO_ACTIVE_PATH CTA는 실제 router gate를 통과해 PathPage를 연다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(learningPathApi: _NoActivePathApi()));
    await tester.pumpAndSettle();

    expect(find.text('경로 만들기'), findsOneWidget);
    await tester.tap(find.text('경로 만들기'));
    await tester.pumpAndSettle();

    expect(find.byType(PathPage), findsOneWidget);
    expect(find.text('학습 경로'), findsWidgets);
  });

  testWidgets('Today contentId 3 CTA는 실제 ContentPage를 목 모드에서 연다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('에러 처리 패턴 적용'), findsOneWidget);
    await tester.tap(find.text('미션 열기'));
    await tester.pumpAndSettle();

    expect(find.byType(ContentPage), findsOneWidget);
    expect(find.text('에러 처리 패턴 적용'), findsWidgets);
    expect(find.textContaining('불러오지 못했'), findsNothing);

    await tester.ensureVisible(find.text('실습 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('실습 시작'));
    await tester.pumpAndSettle();

    expect(find.byType(SandboxPage), findsOneWidget);
    expect(
      tester.widget<AppShellView>(find.byType(AppShellView)).location,
      '/mission/1003/sandbox',
    );
  });

  testWidgets('실제 router가 canonical Today와 검증된 mission/content deep link를 연다', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    var context = tester.element(find.byType(DashboardPage));
    GoRouter.of(context).go('/path/101/today');
    await tester.pumpAndSettle();

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(
      tester.widget<AppShellView>(find.byType(AppShellView)).location,
      '/path/101/today',
    );

    context = tester.element(find.byType(DashboardPage));
    GoRouter.of(context).go('/mission/1003/content/3');
    await tester.pumpAndSettle();

    expect(find.byType(ContentPage), findsOneWidget);
    expect(
      tester.widget<AppShellView>(find.byType(AppShellView)).location,
      '/mission/1003/content/3',
    );
  });
}
