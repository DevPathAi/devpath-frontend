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
Widget _app(WidgetTester tester, {required Size size, String? intent}) {
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
    child: MaterialApp(
      theme: DpTheme.light(),
      home: LoginPage(intent: intent),
    ),
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
    expect(find.text('15문항으로 무엇을 알고 무엇이 비었는지 확인합니다.'), findsOneWidget);

    final story = tester.getRect(find.text('진단'));
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

    final story = tester.getRect(find.text('진단'));
    final panel = tester.getRect(find.text('GitHub로 계속하기'));
    expect(panel.top, greaterThan(story.top));
  });

  testWidgets('로그인: 넓은 화면에서도 본문이 contentMaxWidth 를 넘지 않는다', (tester) async {
    await tester.pumpWidget(_app(tester, size: const Size(1920, 1200)));
    await tester.pumpAndSettle();

    // 로그인은 셸 밖 bare 라우트라 폭을 줄 셸이 없다 — 화면이 직접 캡을 둔다.
    final box = tester.widget<ConstrainedBox>(
      find.byKey(const ValueKey('login-content')),
    );
    expect(box.constraints.maxWidth, 1120);

    // 그 결과 로그인 패널이 800px 버튼으로 늘어나지 않는다.
    final panel = tester.getSize(
      find.byKey(const ValueKey('login-access-panel')),
    );
    expect(panel.width, lessThan(600));
  });

  testWidgets('로그인: medium 1열에서 로그인 패널이 readable 760 을 넘지 않는다', (tester) async {
    await tester.pumpWidget(_app(tester, size: const Size(839, 1200)));
    await tester.pumpAndSettle();

    final panel = tester.getSize(
      find.byKey(const ValueKey('login-access-panel')),
    );
    expect(panel.width, lessThanOrEqualTo(760));
  });

  // 점검 A-1(2026-10-11): 랜딩의 「AI 멘토 초대 신청」이 로그인으로 오는데 재방문 인사
  // 「다시 만나서 반가워요」가 나왔다. 이 화면은 신규·기존 사용자가 함께 쓴다.
  group('로그인 패널 문구(intent)', () {
    testWidgets('기본은 중립적인 「로그인」이다', (tester) async {
      await tester.pumpWidget(_app(tester, size: const Size(1280, 900)));
      await tester.pumpAndSettle();

      expect(find.text('로그인'), findsOneWidget);
      expect(find.text('계정을 연결하고 학습을 이어가세요.'), findsOneWidget);
      expect(find.text('다시 만나서 반가워요'), findsNothing);
    });

    testWidgets('intent=invite 면 AI 멘토 초대 대기 명단을 안내한다', (tester) async {
      await tester.pumpWidget(
        _app(tester, size: const Size(1280, 900), intent: 'invite'),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI 멘토 초대 신청'), findsOneWidget);
      // 로그인하면 platform-svc 가 대기(WAITLISTED) 행을 만든다(ensureForLogin).
      // 승인 메일은 보내는 곳이 없어 약속하지 않는다.
      expect(
        find.text('로그인하면 초대 대기 명단에 등록됩니다. 초대되면 AI 멘토를 바로 쓸 수 있습니다.'),
        findsOneWidget,
      );
      expect(find.text('로그인'), findsNothing);
    });

    testWidgets('모르는 intent 는 기본 문구로 둔다', (tester) async {
      await tester.pumpWidget(
        _app(tester, size: const Size(1280, 900), intent: 'unknown'),
      );
      await tester.pumpAndSettle();

      expect(find.text('로그인'), findsOneWidget);
      expect(find.text('AI 멘토 초대 신청'), findsNothing);
    });

    testWidgets('약관 동의 문구는 레바 표기를 쓴다', (tester) async {
      await tester.pumpWidget(_app(tester, size: const Size(1280, 900)));
      await tester.pumpAndSettle();

      expect(find.text('계속하면 레바의 이용약관과 개인정보 처리방침에 동의하게 됩니다.'), findsOneWidget);
    });
  });

  // 점검 A-2: 좌측 카피를 랜딩 메시지(사수 없는 개발자·맥락 자동 첨부)와 맞춘다.
  // 경로 생성은 GitHub 분석을 쓰지 않으므로(ai-svc·learning-svc 실측) 그 문구를 뺀다.
  testWidgets('로그인 스토리: 랜딩과 같은 메시지를 쓰고 GitHub 분석을 말하지 않는다', (tester) async {
    await tester.pumpWidget(_app(tester, size: const Size(1280, 900)));
    await tester.pumpAndSettle();

    expect(find.text('사수 없는 0~3년차 개발자의 첫 AI 사수'), findsOneWidget);
    expect(find.text('내 상황을 처음부터 다시 설명하지 않아도 됩니다.'), findsOneWidget);
    for (final (title, body) in [
      ('진단', '15문항으로 무엇을 알고 무엇이 비었는지 확인합니다.'),
      ('12주 학습 경로', '진단 결과로 주차별 미션과 완료 조건을 만듭니다.'),
      ('AI 멘토 (순차 초대)', '학습 주제·진도·직전 오류를 질문에 자동으로 붙입니다.'),
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
      expect(find.text(body), findsOneWidget, reason: body);
    }
    expect(find.textContaining('GitHub 분석'), findsNothing);
    expect(find.text('LEARN · BUILD · GROW'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
