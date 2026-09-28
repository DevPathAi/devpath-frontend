import 'dart:ui' as ui;

import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/diagnostic/application/diagnostic_controller.dart';
import 'package:devpath_web/src/features/common/application/track_catalog.dart';
import 'package:devpath_web/src/features/diagnostic/presentation/diagnostic_page.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_continuation.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _preview = AssessmentResult(diagnosedLevel: 'MID', confidenceWeight: 0.8);

class _UnauthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

class _FixedDiagnosticController extends DiagnosticController {
  _FixedDiagnosticController(this.initial);

  final DiagnosticState initial;
  int saveCalls = 0;
  int handoffCalls = 0;
  int retryPathCalls = 0;
  int retryAnswerCalls = 0;
  int resumeCalls = 0;
  int retryAdvanceCalls = 0;
  int restartCalls = 0;
  final selectedTracks = <String>[];
  final guestStarts = <String>[];

  @override
  DiagnosticState build() => initial;

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  Future<void> retryAdvance() async => retryAdvanceCalls++;

  @override
  void selectTrack(String track) {
    selectedTracks.add(track);
    state = state.copyWith(track: track);
  }

  @override
  Future<void> startAsGuest(String track) async => guestStarts.add(track);

  @override
  Future<void> saveAndContinue() async => saveCalls++;

  @override
  void completePathHandoff() => handoffCalls++;

  @override
  Future<void> retryPathProbe() async => retryPathCalls++;

  @override
  Future<void> retryLastAnswer() async => retryAnswerCalls++;

  @override
  void restart() => restartCalls++;
}

Widget _host(
  _FixedDiagnosticController controller, {
  bool router = false,
  bool missionSpineEnabled = true,
  TextScaler? textScaler,
}) {
  Widget scaledBuilder(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  );
  final child = router
      ? MaterialApp.router(
          theme: DpTheme.light(),
          builder: textScaler == null ? null : scaledBuilder,
          routerConfig: GoRouter(
            initialLocation: '/diagnostic',
            routes: [
              GoRoute(
                path: '/diagnostic',
                builder: (_, _) => const DiagnosticPage(),
              ),
              GoRoute(path: '/path', builder: (_, _) => const Text('PATH')),
            ],
          ),
        )
      : MaterialApp(
          theme: DpTheme.light(),
          builder: textScaler == null ? null : scaledBuilder,
          home: const DiagnosticPage(),
        );
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(
          baseUrl: 'https://test.devpath.ai',
          useMock: true,
          missionSpineEnabled: missionSpineEnabled,
        ),
      ),
      authControllerProvider.overrideWith(_UnauthController.new),
      diagnosticControllerProvider.overrideWith(() => controller),
    ],
    child: child,
  );
}

DiagnosticState _previewState({
  DiagnosticContinuationPhase phase = DiagnosticContinuationPhase.preview,
  bool saved = false,
  DiagnosticPathBranch branch = DiagnosticPathBranch.unknown,
  DiagnosticFailure? failure,
  bool busy = false,
}) => DiagnosticState(
  phase: phase,
  track: 'BACKEND_SPRING',
  guestId: '123e4567-e89b-42d3-a456-426614174000',
  preview: _preview,
  saved: saved,
  pathBranch: branch,
  failure: failure,
  busy: busy,
);

void main() {
  /// 시안 `.steps` 단계 표시와 패널이 더해지며 결과·시작 화면이 기본 테스트
  /// 뷰포트(800x600)보다 길어졌다. 화면은 `SingleChildScrollView` 안이라 실제로는
  /// 스크롤되지만, 탭하는 테스트는 뷰포트를 키워 CTA 를 화면 안에 둔다.
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('flag OFF guest 완료는 결과를 숨기고 legacy 로그인 gate를 보인다', (
    tester,
  ) async {
    final controller = _FixedDiagnosticController(_previewState());
    await tester.pumpWidget(_host(controller, missionSpineEnabled: false));
    await tester.pump();

    expect(find.text('결과를 보려면 로그인하세요'), findsOneWidget);
    expect(find.text('GitHub로 로그인'), findsOneWidget);
    expect(find.text('진단 결과'), findsNothing);
    expect(find.textContaining('현재 레벨 MID'), findsNothing);
    expect(find.text('저장하고 계속'), findsNothing);
  });

  testWidgets('track 단계는 15문항·비회원 시작·산출물을 명시한다', (tester) async {
    final controller = _FixedDiagnosticController(const DiagnosticState());
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.text('실력 진단 15문항'), findsOneWidget);
    expect(find.textContaining('로그인 없이'), findsOneWidget);
    expect(find.textContaining('레벨과 신뢰도'), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-row')), findsOneWidget);
  });

  testWidgets('트랙 선택기는 라디오 그룹 이름을 갖고 보기 행마다 탭 동작이 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = _FixedDiagnosticController(const DiagnosticState());
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    // 그룹에 이름이 있어야 스크린리더가 「무엇을 고르는 라디오 묶음인지」 안다.
    expect(find.bySemanticsLabel(RegExp('진단할 트랙')), findsOneWidget);

    // 탭 동작은 드롭다운 버튼이 아니라 보기 행마다 있다.
    final row = tester.getSemantics(find.text('백엔드 (Spring)'));
    expect(row.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);

    semantics.dispose();
  });

  testWidgets('시작 화면은 단계·진단 설명·기대 결과·시작 행동을 하나의 온보딩 surface로 묶는다', (
    tester,
  ) async {
    final controller = _FixedDiagnosticController(const DiagnosticState());
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final surface = find.byKey(const ValueKey('diagnostic-onboarding-surface'));
    expect(surface, findsOneWidget);

    for (final label in <String>['1 트랙 선택', '2 실력 진단', '3 학습 경로']) {
      expect(
        find.descendant(of: surface, matching: find.text(label)),
        findsOneWidget,
      );
    }
    // `DpSteps` 는 커스텀 문구가 아니라 `selected` 로 현재 단계를 알린다.
    expect(
      tester.getSemantics(find.text('1 트랙 선택')),
      isSemantics(isSelected: true),
    );
    expect(
      find.descendant(of: surface, matching: find.textContaining('약 5분')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: surface, matching: find.textContaining('15문항')),
      findsWidgets,
    );

    for (final outcome in <String>['현재 레벨', '진단 신뢰도', '맞춤 학습 경로']) {
      expect(
        find.descendant(of: surface, matching: find.text(outcome)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: surface,
        matching: find.byKey(const ValueKey('diagnostic-track')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: surface,
        matching: find.widgetWithText(FilledButton, '진단 시작하기'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('390px에서 트랙 입력과 안내 문구가 화면 안에 머문다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _FixedDiagnosticController(const DiagnosticState());

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final viewport = tester.getRect(find.byType(Scaffold));
    final field = tester.getRect(
      find.byKey(const ValueKey('diagnostic-track')),
    );
    final hint = tester.getRect(
      find.byKey(const ValueKey('diagnostic-track-hint')),
    );
    expect(field.left, greaterThanOrEqualTo(viewport.left));
    expect(field.right, lessThanOrEqualTo(viewport.right));
    expect(hint.left, greaterThanOrEqualTo(viewport.left));
    expect(hint.right, lessThanOrEqualTo(viewport.right));
    expect(hint.height, greaterThanOrEqualTo(32));
  });

  testWidgets('선택한 트랙으로만 guest 진단을 시작한다', (tester) async {
    tallView(tester);
    final controller = _FixedDiagnosticController(const DiagnosticState());
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.text('DevOps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('진단 시작하기'));

    expect(controller.selectedTracks, ['DEVOPS']);
    expect(controller.guestStarts, ['DEVOPS']);
  });

  testWidgets('questions 단계는 텍스트와 bar로 진행률을 함께 보인다', (tester) async {
    final controller = _FixedDiagnosticController(
      const DiagnosticState(
        phase: DiagnosticContinuationPhase.questions,
        track: 'BACKEND_SPRING',
        nextQuestion: NextQuestion(
          question: AssessmentQuestion(
            id: 1,
            type: 'MCQ',
            content: 'Spring Bean의 기본 스코프는?',
            bloomLevel: 'REMEMBER',
            difficulty: 0.3,
          ),
          index: 3,
          total: 15,
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.textContaining('3 / 15'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Spring Bean의 기본 스코프는?'), findsOneWidget);
  });

  testWidgets('guest preview는 로그인 전에 보이고 저장 CTA 전에는 이동하지 않는다', (tester) async {
    tallView(tester);
    final controller = _FixedDiagnosticController(_previewState());
    await tester.pumpWidget(_host(controller, router: true));
    await tester.pumpAndSettle();

    expect(find.text('진단 결과'), findsOneWidget);
    expect(find.textContaining('MID'), findsOneWidget);
    expect(find.textContaining('80%'), findsOneWidget);
    expect(find.text('저장하고 계속'), findsOneWidget);
    expect(find.text('PATH'), findsNothing);

    await tester.tap(find.text('저장하고 계속'));
    await tester.pump();
    expect(controller.saveCalls, 1);
    expect(find.text('PATH'), findsNothing);
  });

  testWidgets('saved preview도 동일한 결과를 보이며 explicit CTA 뒤에만 /path로 간다', (
    tester,
  ) async {
    tallView(tester);
    final controller = _FixedDiagnosticController(
      _previewState(
        phase: DiagnosticContinuationPhase.saved,
        saved: true,
        branch: DiagnosticPathBranch.newPath,
      ),
    );
    await tester.pumpWidget(_host(controller, router: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('MID'), findsOneWidget);
    expect(find.textContaining('80%'), findsOneWidget);
    expect(find.text('학습 경로로 계속'), findsOneWidget);
    expect(find.text('진단 다시 시작'), findsNothing);
    expect(find.text('PATH'), findsNothing);

    await tester.tap(find.text('학습 경로로 계속'));
    await tester.pumpAndSettle();
    expect(controller.handoffCalls, 1);
    expect(find.text('PATH'), findsOneWidget);
  });

  testWidgets('existing path branch는 진단을 병합했다고 말하지 않는다', (tester) async {
    final controller = _FixedDiagnosticController(
      _previewState(
        phase: DiagnosticContinuationPhase.saved,
        saved: true,
        branch: DiagnosticPathBranch.existingActivePath,
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.textContaining('기존 학습 경로는 바꾸지 않았어요'), findsOneWidget);
    expect(find.text('기존 경로로 계속'), findsOneWidget);
    expect(find.textContaining('병합'), findsNothing);
  });

  testWidgets('claim/path 오류는 preview를 가리지 않고 해당 단계 retry만 제공한다', (
    tester,
  ) async {
    tallView(tester);
    final controller = _FixedDiagnosticController(
      _previewState(
        phase: DiagnosticContinuationPhase.saved,
        saved: true,
        failure: const DiagnosticFailure(
          DiagnosticFailureKind.pathGeneration,
          '결과는 저장됐지만 학습 경로 상태를 불러오지 못했어요.',
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.textContaining('MID'), findsOneWidget);
    expect(find.textContaining('결과는 저장됐지만'), findsOneWidget);
    expect(find.text('경로 상태 다시 확인'), findsOneWidget);
    await tester.tap(find.text('경로 상태 다시 확인'));
    expect(controller.retryPathCalls, 1);
  });

  testWidgets('claim 오류는 preview를 유지하고 저장 재시도라고 명확히 표시한다', (tester) async {
    tallView(tester);
    final controller = _FixedDiagnosticController(
      _previewState(
        phase: DiagnosticContinuationPhase.claim,
        failure: const DiagnosticFailure(
          DiagnosticFailureKind.claim,
          '결과를 아직 저장하지 못했어요.',
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.textContaining('MID'), findsOneWidget);
    expect(find.text('저장 다시 시도'), findsOneWidget);
    expect(find.text('결과 저장 중'), findsNothing);

    await tester.tap(find.text('저장 다시 시도'));
    expect(controller.saveCalls, 1);
  });

  testWidgets('답변 저장 뒤 next 오류는 답변 대신 다음 문항 불러오기만 재시도한다', (tester) async {
    final controller = _FixedDiagnosticController(
      const DiagnosticState(
        phase: DiagnosticContinuationPhase.questions,
        track: 'BACKEND_SPRING',
        guestId: '123e4567-e89b-42d3-a456-426614174000',
        nextQuestion: NextQuestion(
          question: AssessmentQuestion(
            id: 9,
            type: 'MCQ',
            content: '현재 문항',
            bloomLevel: 'REMEMBER',
            difficulty: 0.2,
          ),
          index: 8,
          total: 15,
        ),
        failure: DiagnosticFailure(
          DiagnosticFailureKind.initialLoad,
          '다음 문항을 불러오지 못했어요.',
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();
    expect(find.text('다음 문항 다시 불러오기'), findsOneWidget);
    expect(find.text('같은 답변 다시 저장'), findsNothing);
    expect(find.text('잘 모르겠어요'), findsNothing);

    await tester.tap(find.text('다음 문항 다시 불러오기'));
    expect(controller.retryAdvanceCalls, 1);
  });

  testWidgets('guest start 뒤 첫 next 오류는 새 진단 시작 대신 기존 진단을 재개한다', (
    tester,
  ) async {
    final controller = _FixedDiagnosticController(
      const DiagnosticState(
        phase: DiagnosticContinuationPhase.questions,
        track: 'BACKEND_SPRING',
        guestId: '123e4567-e89b-42d3-a456-426614174000',
        failure: DiagnosticFailure(
          DiagnosticFailureKind.initialLoad,
          '첫 문항을 불러오지 못했어요.',
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.text('다음 문항 다시 불러오기'), findsOneWidget);
    expect(find.text('진단 시작하기'), findsNothing);

    await tester.tap(find.text('다음 문항 다시 불러오기'));
    expect(controller.retryAdvanceCalls, 1);
    expect(controller.guestStarts, isEmpty);
  });

  testWidgets('answer 실패는 선택지와 실패한 선택을 보존하고 같은 payload retry를 제공한다', (
    tester,
  ) async {
    final controller = _FixedDiagnosticController(
      const DiagnosticState(
        phase: DiagnosticContinuationPhase.questions,
        track: 'BACKEND_SPRING',
        guestId: '123e4567-e89b-42d3-a456-426614174000',
        nextQuestion: NextQuestion(
          question: AssessmentQuestion(
            id: 9,
            type: 'MCQ',
            content: '현재 문항',
            options: '["첫 답","둘째 답"]',
            bloomLevel: 'REMEMBER',
            difficulty: 0.2,
          ),
          index: 8,
          total: 15,
        ),
        pendingAnswer: '{"correct":1}',
        failure: DiagnosticFailure(
          DiagnosticFailureKind.answer,
          '답변을 저장하지 못했어요.',
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.text('첫 답'), findsOneWidget);
    expect(find.text('둘째 답'), findsOneWidget);
    // 실패한 선택은 ✓ 글자가 아니라 라디오 선택 상태로 남는다(시안 `.opt.sel`).
    final selectedRow = tester.widget<DpOptionRow>(
      find.byKey(const ValueKey('diagnostic-option-selected-1')),
    );
    expect(selectedRow.selected, isTrue);
    await tester.tap(find.text('같은 답변 다시 저장'));
    expect(controller.retryAnswerCalls, 1);
  });

  testWidgets('saved path probe busy 동안에는 known branch handoff CTA도 비활성이다', (
    tester,
  ) async {
    final controller = _FixedDiagnosticController(
      _previewState(
        phase: DiagnosticContinuationPhase.saved,
        saved: true,
        branch: DiagnosticPathBranch.newPath,
        busy: true,
      ),
    );
    await tester.pumpWidget(_host(controller, router: true));
    await tester.pump();

    // 시안 `.next` 밴드로 옮겨 `FilledButton` 이 아니다 — 밴드의 상태로 읽는다.
    final band = tester.widget<DpNextActionBand>(find.byType(DpNextActionBand));
    expect(band.label, '학습 경로로 계속');
    expect(band.state, DpNextActionState.disabled);
    expect(band.onPressed, isNull);
    expect(find.text('PATH'), findsNothing);
  });

  testWidgets(
    '만료/ownership은 320px·200%에서도 overflow 없이 restart semantic action 하나만 둔다',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      for (final kind in <DiagnosticFailureKind>[
        DiagnosticFailureKind.guestExpired,
        DiagnosticFailureKind.ownership,
      ]) {
        final controller = _FixedDiagnosticController(
          _previewState(
            failure: DiagnosticFailure(kind, '이 결과는 안전하게 이어갈 수 없어요.'),
          ),
        );
        await tester.pumpWidget(
          _host(controller, textScaler: const TextScaler.linear(2)),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('새 진단 시작'), findsOneWidget);
        expect(find.text('진단 다시 시작'), findsNothing);
        // 밴드는 예상 결과를 접근성 이름에 함께 싣는다.
        expect(
          find.bySemanticsLabel(RegExp('^새 진단 시작, 예상 결과: ')),
          findsOneWidget,
        );
      }
      semantics.dispose();
    },
  );

  testWidgets('문항 준비 중에는 라벨 있는 접근 가능한 로딩을 보인다', (tester) async {
    final controller = _FixedDiagnosticController(
      const DiagnosticState(
        phase: DiagnosticContinuationPhase.questions,
        track: 'BACKEND_SPRING',
        busy: true,
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();
    expect(find.bySemanticsLabel('다음 문항을 불러오고 있어요'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('답변 실패는 인라인 알림으로 표시되고 문항은 유지된다', (tester) async {
    final controller = _FixedDiagnosticController(
      const DiagnosticState(
        phase: DiagnosticContinuationPhase.questions,
        track: 'BACKEND_SPRING',
        nextQuestion: NextQuestion(
          question: AssessmentQuestion(
            id: 1,
            type: 'MCQ',
            content: 'Spring Bean의 기본 스코프는?',
            bloomLevel: 'REMEMBER',
            difficulty: 0.3,
          ),
          index: 3,
          total: 15,
        ),
        failure: DiagnosticFailure(
          DiagnosticFailureKind.answer,
          '답변을 저장하지 못했어요.',
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();
    expect(find.byKey(const ValueKey('dp-inline-notice')), findsOneWidget);
    expect(find.text('답변을 저장하지 못했어요.'), findsOneWidget);
    expect(find.text('Spring Bean의 기본 스코프는?'), findsOneWidget);
  });

  // ── S3-P4c Task 16: 시안 `.steps`·`.opt`·`.next` ─────────────────────────

  const stepLabels = ['1 트랙 선택', '2 실력 진단', '3 학습 경로'];

  testWidgets('진단 시작: 시안 .steps 3단계에서 1단계가 현재다', (tester) async {
    final controller = _FixedDiagnosticController(const DiagnosticState());
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final steps = tester.widget<DpSteps>(find.byType(DpSteps));
    expect(steps.labels, stepLabels);
    expect(steps.currentIndex, 0);
  });

  testWidgets('진단 문항: 2단계가 현재이고 보기를 DpOptionRow 로 그린다', (tester) async {
    final controller = _FixedDiagnosticController(
      const DiagnosticState(
        phase: DiagnosticContinuationPhase.questions,
        track: 'BACKEND_SPRING',
        nextQuestion: NextQuestion(
          question: AssessmentQuestion(
            id: 1,
            type: 'MCQ',
            content: 'Spring Bean의 기본 스코프는?',
            bloomLevel: 'REMEMBER',
            difficulty: 0.3,
            options: '["singleton","prototype","request","session"]',
          ),
          index: 3,
          total: 15,
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final steps = tester.widget<DpSteps>(find.byType(DpSteps));
    expect(steps.currentIndex, 1);
    expect(find.byType(DpOptionRow), findsNWidgets(4));
    expect(find.text('singleton'), findsOneWidget);
  });

  testWidgets('진단 결과: 3단계가 현재이고 다음 행동을 .next 밴드로 보인다', (tester) async {
    final controller = _FixedDiagnosticController(_previewState());
    await tester.pumpWidget(_host(controller, router: true));
    await tester.pumpAndSettle();

    final steps = tester.widget<DpSteps>(find.byType(DpSteps));
    expect(steps.currentIndex, 2);
    expect(find.byType(DpNextActionBand), findsOneWidget);
    expect(find.text('저장하고 계속'), findsOneWidget);
  });

  testWidgets('진단 시작: 트랙을 보기 행으로 골라 시작한다', (tester) async {
    tallView(tester);
    final controller = _FixedDiagnosticController(const DiagnosticState());
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    // 시안 `dstart` 의 `.opt` — 드롭다운이 아니라 보이는 보기 행이다.
    expect(find.byType(DpOptionRow), findsNWidgets(trackLabels.length));
    await tester.tap(find.text('DevOps'));
    await tester.pump();
    await tester.tap(find.text('진단 시작하기'));

    expect(controller.selectedTracks, ['DEVOPS']);
    expect(controller.guestStarts, ['DEVOPS']);
  });

  testWidgets('진단 문항: 제출 중에는 보기가 잠긴다', (tester) async {
    final controller = _FixedDiagnosticController(
      const DiagnosticState(
        phase: DiagnosticContinuationPhase.questions,
        track: 'BACKEND_SPRING',
        busy: true,
        nextQuestion: NextQuestion(
          question: AssessmentQuestion(
            id: 1,
            type: 'MCQ',
            content: 'Spring Bean의 기본 스코프는?',
            bloomLevel: 'REMEMBER',
            difficulty: 0.3,
            options: '["singleton","prototype"]',
          ),
          index: 3,
          total: 15,
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final rows = tester.widgetList<DpOptionRow>(find.byType(DpOptionRow));
    expect(rows, isNotEmpty);
    expect(rows.every((r) => r.onSelect == null), isTrue);
  });

  testWidgets('진단: 390px 에서 단계 표시가 세로로 쌓이고 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _FixedDiagnosticController(const DiagnosticState());
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(tester.takeException(), isNull);
    final first = tester.getRect(find.text('1 트랙 선택'));
    final second = tester.getRect(find.text('2 실력 진단'));
    expect(second.top, greaterThan(first.bottom - 1));
    // 본문이 가로로 넘치지 않는다.
    final viewport = tester.getRect(find.byType(Scaffold));
    expect(second.right, lessThanOrEqualTo(viewport.right));
  });

  testWidgets('진단: 페이지 헤더가 본문과 같은 좌측선을 갖는다', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _FixedDiagnosticController(const DiagnosticState());
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    // 셸 밖 화면이라 헤더가 거터를 스스로 줘야 한다 — 없으면 화면 끝에 붙는다.
    expect(tester.getTopLeft(find.text('실력 진단')).dx, greaterThanOrEqualTo(16));
  });

  testWidgets('진단 시작: 트랙 묶음에 보이는 제목이 있다', (tester) async {
    tallView(tester);
    final controller = _FixedDiagnosticController(const DiagnosticState());
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    // 드롭다운의 `labelText` 가 사라진 자리를 보이는 제목이 대신한다.
    expect(find.text('진단할 트랙'), findsOneWidget);
  });

  testWidgets('진단 문항: 누르면 즉시 제출되므로 보기는 버튼 역할이다', (tester) async {
    final controller = _FixedDiagnosticController(
      const DiagnosticState(
        phase: DiagnosticContinuationPhase.questions,
        track: 'BACKEND_SPRING',
        nextQuestion: NextQuestion(
          question: AssessmentQuestion(
            id: 1,
            type: 'MCQ',
            content: 'Spring Bean의 기본 스코프는?',
            bloomLevel: 'REMEMBER',
            difficulty: 0.3,
            options: '["singleton","prototype"]',
          ),
          index: 3,
          total: 15,
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final rows = tester.widgetList<DpOptionRow>(find.byType(DpOptionRow));
    expect(rows, isNotEmpty);
    expect(rows.every((r) => r.role == DpOptionRole.button), isTrue);
  });

  testWidgets('진단 시작: 트랙 보기는 라디오 역할이다 — 고른 것이 상태로 남는다', (tester) async {
    tallView(tester);
    final controller = _FixedDiagnosticController(const DiagnosticState());
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final rows = tester.widgetList<DpOptionRow>(find.byType(DpOptionRow));
    expect(rows, isNotEmpty);
    expect(rows.every((r) => r.role == DpOptionRole.radio), isTrue);
  });

  testWidgets('진단 결과: 저장이 선행 조건임을 문구가 알린다', (tester) async {
    tallView(tester);
    final controller = _FixedDiagnosticController(_previewState());
    await tester.pumpWidget(_host(controller, router: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('저장 후'), findsOneWidget);
  });
}
