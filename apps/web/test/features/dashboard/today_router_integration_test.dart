import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/content/presentation/content_page.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
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
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('에러 처리 패턴 적용'), findsOneWidget);
    await tester.tap(find.text('미션 열기'));
    await tester.pumpAndSettle();

    expect(find.byType(ContentPage), findsOneWidget);
    expect(find.text('에러 처리 패턴 적용'), findsWidgets);
    expect(find.textContaining('불러오지 못했'), findsNothing);
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
