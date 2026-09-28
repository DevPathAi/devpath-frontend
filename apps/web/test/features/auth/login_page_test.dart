import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/application/oauth_launcher.dart';
import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnauthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

class _LoadingAuthController extends AuthController {
  @override
  AuthState build() => const AuthLoading();
}

class _ErrorAuthController extends AuthController {
  _ErrorAuthController(this.message);
  final String message;
  @override
  AuthState build() => AuthUnauthenticated(error: message);
}

/// 테스트 전용 Fake Launcher — 실제 window 이동 없이 URL을 기록.
class _FakeOAuthLauncher implements OAuthLauncher {
  String? launchedUrl;

  @override
  void launch(String url) {
    launchedUrl = url;
  }
}

/// 시안 `.login` 레이아웃 테스트용 호스트. 폭 의존은 `tester.view.physicalSize`
/// 로 준다 — `MaterialApp` 이 뷰에서 자기 MediaQuery 를 만들어 바깥
/// `MediaQuery` 를 덮는다.
Widget _app(WidgetTester tester, {required Size size}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_UnauthController.new),
      appConfigProvider.overrideWithValue(
        const AppConfig(
          baseUrl: 'https://test.devpath.ai/api/v1',
          useMock: false,
        ),
      ),
    ],
    child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
  );
}

void main() {
  testWidgets('로그인 버튼 탭 → Launcher 호출(OAuth 리다이렉트 시작)', (tester) async {
    final fakeLauncher = _FakeOAuthLauncher();
    // useMock=false로 설정해 실제 OAuth 리다이렉트 경로(login())를 검증한다.
    final container = ProviderContainer(
      overrides: [
        // 실제 컨트롤러는 시작 시 세션 복원(AuthLoading)을 먼저 보이므로,
        // 이 테스트는 미인증 상태를 직접 주입해 버튼 → 런처 배선만 검증한다.
        authControllerProvider.overrideWith(_UnauthController.new),
        oauthLauncherProvider.overrideWithValue(fakeLauncher),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://test.devpath.ai/api/v1',
            useMock: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
      ),
    );

    // useMock=false → "(목)" 접미사 없음
    expect(find.text('GitHub로 계속하기'), findsOneWidget);

    await tester.tap(find.text('GitHub로 계속하기'));
    await tester.pumpAndSettle();

    // login()은 OAuth 리다이렉트이므로 상태는 여전히 미인증.
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    // Launcher가 OAuth URL로 호출됐음을 검증.
    expect(fakeLauncher.launchedUrl, isNotNull);
    expect(fakeLauncher.launchedUrl, contains('/oauth2/authorization/github'));
  });

  testWidgets('세션 복원 중(AuthLoading)에는 로그인 버튼 대신 확인 중 상태를 보인다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_LoadingAuthController.new),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://test.devpath.ai/api/v1',
            useMock: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
      ),
    );
    expect(find.bySemanticsLabel('세션을 확인하는 중'), findsOneWidget);
    expect(find.text('GitHub로 계속하기'), findsNothing);
  });

  testWidgets('로그인 오류는 인라인 알림으로 표시되고 버튼은 유지된다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _ErrorAuthController('로그인 세션이 만료됐어요.'),
        ),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://test.devpath.ai/api/v1',
            useMock: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
      ),
    );
    expect(find.byKey(const ValueKey('dp-inline-notice')), findsOneWidget);
    expect(find.text('로그인 세션이 만료됐어요.'), findsOneWidget);
    expect(find.text('GitHub로 계속하기'), findsOneWidget);
  });

  testWidgets('로그인: expanded 이상에서 스토리 | 로그인 패널 2열로 배치한다', (tester) async {
    await tester.pumpWidget(_app(tester, size: const Size(1280, 900)));
    await tester.pumpAndSettle();

    // 시안 `.flow` 는 칩 나열이 아니라 제목 + 설명 2열 목록이다.
    expect(find.byType(DpListLines), findsOneWidget);
    expect(find.text('15문항 진단과 GitHub 분석으로 12주 계획을 만듭니다.'), findsOneWidget);

    final story = tester.getRect(find.text('맞춤 학습 경로'));
    final panel = tester.getRect(find.text('GitHub로 계속하기'));
    expect(panel.left, greaterThan(story.left));
  });

  testWidgets('로그인: 장식 원과 그라디언트를 쓰지 않는다', (tester) async {
    await tester.pumpWidget(_app(tester, size: const Size(1280, 900)));
    await tester.pumpAndSettle();

    // 장식 컨테이너가 남아 있으면 시안과 어긋난다(시안의 면 구분은 1px 테두리뿐).
    // 브랜드 로고(`leva-brand-mark`)는 제외한다 — 제품 로고이고 셸 전체가 쓰는
    // dp_design 위젯이라 이 화면의 장식이 아니다.
    final gradients = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) {
          final d = c.decoration;
          return d is BoxDecoration &&
              d.gradient != null &&
              c.key != const ValueKey('leva-brand-mark');
        });
    expect(gradients, isEmpty);
  });

  testWidgets('로그인: medium 에서 스토리 위 · 로그인 패널 아래 한 열이 된다', (tester) async {
    await tester.pumpWidget(_app(tester, size: const Size(800, 900)));
    await tester.pumpAndSettle();

    final story = tester.getRect(find.text('맞춤 학습 경로'));
    final panel = tester.getRect(find.text('GitHub로 계속하기'));
    expect(panel.top, greaterThan(story.top));
  });
}
