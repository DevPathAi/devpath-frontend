import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/diagnostic/application/diagnostic_controller.dart';
import 'package:devpath_web/src/features/diagnostic/presentation/diagnostic_page.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 미인증 상태로 고정(bootstrapSession microtask 없음)해 render만 검증.
class _UnauthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

/// DiagnosticState를 고정하는 컨트롤러. build()가 부여된 상태를 그대로 반환.
class _FixedController extends DiagnosticController {
  _FixedController(this._initial);
  final DiagnosticState _initial;

  @override
  DiagnosticState build() => _initial;
}

Widget _host() => ProviderScope(
  overrides: [authControllerProvider.overrideWith(_UnauthController.new)],
  child: MaterialApp(theme: DpTheme.light(), home: const DiagnosticPage()),
);

void main() {
  testWidgets('DiagnosticIdle: 시작 안내 + 진단 시작하기 CTA 렌더', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthController.new),
          diagnosticControllerProvider.overrideWith(
            () => _FixedController(const DiagnosticIdle()),
          ),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const DiagnosticPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('실력 진단'), findsOneWidget); // 페이지 헤더
    expect(find.text('실력 진단 15문항'), findsOneWidget);
    expect(find.text('진단 시작하기'), findsOneWidget);
  });

  testWidgets('셸 밖 화면도 헤더와 본문이 같은 좌측 축에 선다', (tester) async {
    // 넓은 폭에서만 드러난다 — 좁으면 readableMaxWidth가 화면을 꽉 채워
    // 「중앙 정렬」과 「좌측 정렬」의 차이가 사라진다.
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthController.new),
          diagnosticControllerProvider.overrideWith(
            () => _FixedController(const DiagnosticIdle()),
          ),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const DiagnosticPage(),
        ),
      ),
    );
    await tester.pump();

    final headerLeft = tester.getTopLeft(find.text('실력 진단')).dx;
    final bodyLeft = tester.getTopLeft(find.text('실력 진단 15문항')).dx;

    // 헤더는 DpSpacing.lg(16), 본문 Padding은 DpSpacing.xl(24)이라 8px 차이는
    // 정상이다. 본문이 중앙 정렬이면 그보다 훨씬 크게 벌어진다.
    expect(
      bodyLeft - headerLeft,
      lessThan(16.0),
      reason: '헤더는 좌측인데 본문만 중앙이면 시각 축이 둘로 갈린다',
    );
  });

  testWidgets('AppBar 없이 헤더로 대체 + readableMaxWidth 사용', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthController.new),
          diagnosticControllerProvider.overrideWith(
            () => _FixedController(const DiagnosticIdle()),
          ),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const DiagnosticPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '실력 진단');
    expect(header.description, '몇 문항으로 현재 수준을 파악합니다');
    final constrainedBox = tester.widget<ConstrainedBox>(
      find
          .ancestor(
            of: find.byType(DpPageHeader),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(constrainedBox.constraints.maxWidth, 880);
    // F4 회귀 가드: brandRow(context) 호출을 지워도 위 단언들은 깨지지
    // 않는다 — 셸 밖 화면의 유일한 제품 정체성 표시이므로 존재를 직접
    // 단언한다(brand_row.dart의 key로, find.text보다 견고하다).
    expect(find.byKey(const ValueKey('brand-row')), findsOneWidget);
  });

  testWidgets('DiagnosticQuestion: 진행 표시 + 문항 + 답안 제출 렌더', (tester) async {
    const q = DiagnosticQuestion(
      NextQuestion(
        question: AssessmentQuestion(
          id: 1,
          type: 'MCQ',
          content: 'Spring Bean의 기본 스코프는?',
          options: null,
          bloomLevel: 'REMEMBER',
          difficulty: 0.3,
        ),
        index: 3,
        total: 15,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthController.new),
          diagnosticControllerProvider.overrideWith(() => _FixedController(q)),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const DiagnosticPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('3 / 15'), findsOneWidget); // 진행 표시
    expect(find.text('Spring Bean의 기본 스코프는?'), findsOneWidget); // 문항
    expect(find.text('답안 제출'), findsOneWidget); // options 없음 → 단일 제출
    expect(find.text('잘 모르겠어요'), findsOneWidget); // skip
  });

  testWidgets('DiagnosticGateSignup: 로그인 안내 + GitHub 로그인 렌더', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthController.new),
          diagnosticControllerProvider.overrideWith(
            () => _FixedController(const DiagnosticGateSignup()),
          ),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const DiagnosticPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('결과를 보려면 로그인하세요'), findsOneWidget);
    expect(find.text('GitHub로 로그인'), findsOneWidget);
  });

  testWidgets('DiagnosticError: 에러 메시지 렌더(dpColors 접근)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthController.new),
          diagnosticControllerProvider.overrideWith(
            () => _FixedController(const DiagnosticError('진단을 시작할 수 없습니다')),
          ),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const DiagnosticPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('진단을 시작할 수 없습니다'), findsOneWidget);
  });

  testWidgets('기본 Idle 호스트 렌더 스모크', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.byType(DiagnosticPage), findsOneWidget);
  });
}
