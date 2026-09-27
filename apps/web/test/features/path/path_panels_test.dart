import 'package:devpath_web/src/features/path/presentation/path_panels.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _plan = LearningPath(
  pathId: 1,
  track: 'BACKEND_SPRING',
  totalWeeks: 12,
  rationale: '진단에서 비동기 흐름과 테스트 보강이 먼저 필요하다고 나왔어요.',
  diagnosis: PathDiagnosis(
    diagnosedLevel: '2',
    strengthConcepts: ['HTTP', '테스트'],
    weaknessConcepts: ['비동기', '트랜잭션'],
  ),
  milestones: [
    PathMilestone(
      weekNum: 1,
      title: '비동기 기초',
      goalDescription: 'Future와 Stream의 차이를 이해하고 작은 기능에 적용합니다.',
      estimatedHours: 6,
      whyThisOrder: '비동기가 나머지 주차의 전제다.',
      expectedOutcome: '비동기 API 호출과 Stream 구독을 안정적으로 다룰 수 있어요.',
      tasks: [
        WeeklyTask(
          taskId: 11,
          orderNum: 1,
          taskType: 'READ',
          title: '읽기 과제',
          completed: true,
        ),
        WeeklyTask(
          taskId: 12,
          orderNum: 2,
          taskType: 'PRACTICE',
          title: '실습 과제',
        ),
        WeeklyTask(taskId: 13, orderNum: 3, taskType: 'QUIZ', title: '확인 과제'),
      ],
    ),
    PathMilestone(
      weekNum: 2,
      title: '주차 2 학습',
      goalDescription: '다음 단계 역량을 차근차근 확장합니다.',
      estimatedHours: 6,
      whyThisOrder: '1주차 위에 쌓는다.',
      expectedOutcome: '확장된 역량',
    ),
  ],
);

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('PathWeeksPanel: 주차를 표로 그리고 현재 주차를 표시한다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        const PathWeeksPanel(plan: _plan, currentWeek: 1, onOpenWeek: null),
      ),
    );

    // 제목은 plan.totalWeeks 에서 온다 — 리터럴 12 를 쓰지 않는다.
    expect(find.text('12주 계획'), findsOneWidget);
    expect(find.text('비동기 기초'), findsOneWidget);
    expect(find.text('주차 2 학습'), findsOneWidget);
    expect(find.text('● 진행 중'), findsOneWidget);
    // 접혀 있던 goalDescription 이 「목표」 칼럼으로 올라온다.
    expect(find.text('Future와 Stream의 차이를 이해하고 작은 기능에 적용합니다.'), findsOneWidget);
    // 옛 접힘 목록이 감춰 두었던 expectedOutcome 도 함께 올라온다(정보 손실 없음).
    expect(find.text('비동기 API 호출과 Stream 구독을 안정적으로 다룰 수 있어요.'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    // 과제가 없는 주차는 「대기」다.
    expect(find.text('대기'), findsOneWidget);
  });

  testWidgets('PathWeeksPanel: onOpenWeek 가 null 이면 제목을 링크로 만들지 않는다', (
    tester,
  ) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        const PathWeeksPanel(plan: _plan, currentWeek: 1, onOpenWeek: null),
      ),
    );

    // 주차 상세 라우트가 없으므로 빈 콜백으로 링크처럼 보이게 하지 않는다.
    expect(find.byType(DpLink), findsNothing);
  });

  testWidgets('PathWeeksPanel: onOpenWeek 를 주면 제목 링크가 그 주차를 넘긴다', (
    tester,
  ) async {
    _view(tester, const Size(1280, 900));
    PathMilestone? opened;
    await tester.pumpWidget(
      _host(
        PathWeeksPanel(
          plan: _plan,
          currentWeek: 1,
          onOpenWeek: (m) => opened = m,
        ),
      ),
    );

    await tester.tap(find.text('주차 2 학습'));
    await tester.pump();
    expect(opened?.weekNum, 2);
  });

  testWidgets('PathWeeksPanel: compact 에서 목표 칼럼을 감춘다', (tester) async {
    _view(tester, const Size(390, 900));
    await tester.pumpWidget(
      _host(
        const PathWeeksPanel(plan: _plan, currentWeek: 1, onOpenWeek: null),
      ),
    );

    expect(find.text('목표'), findsNothing);
    expect(find.text('주제'), findsOneWidget);
  });

  testWidgets('PathDiagnosisPanel: 강점·보강·트랙·수준을 키-값으로 그린다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(_host(const PathDiagnosisPanel(plan: _plan)));

    expect(find.text('진단 요약'), findsOneWidget);
    expect(find.text('HTTP'), findsOneWidget);
    expect(find.text('비동기'), findsOneWidget);
    // 트랙은 DpLearningLabels 가 유일한 문구 출처다.
    expect(find.text('백엔드 · Spring'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('PathDiagnosisPanel: 진단이 없으면 트랙과 주차 수만 남는다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        const PathDiagnosisPanel(
          plan: LearningPath(
            pathId: 1,
            track: 'FRONTEND_REACT',
            totalWeeks: 8,
            rationale: '근거',
          ),
        ),
      ),
    );

    expect(find.text('진단 요약'), findsOneWidget);
    expect(find.text('프론트엔드 · React'), findsOneWidget);
    expect(find.text('8주'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PathWeekOutcomePanel: 완료 근거와 다음 잠금 해제를 함께 말한다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        const PathWeekOutcomePanel(
          milestone: PathMilestone(
            weekNum: 1,
            title: '비동기 기초',
            goalDescription: '목표',
            estimatedHours: 6,
            whyThisOrder: '근거',
            expectedOutcome: '비동기 API 호출과 Stream 구독을 안정적으로 다룰 수 있어요.',
          ),
          nextUnlock: '2주차 주차 2 학습',
        ),
      ),
    );

    expect(find.text('1주차를 끝내면'), findsOneWidget);
    expect(find.text('비동기 API 호출과 Stream 구독을 안정적으로 다룰 수 있어요.'), findsOneWidget);
    expect(find.text('다음 잠금 해제 · 2주차 주차 2 학습'), findsOneWidget);
  });

  testWidgets('PathRationalePanel: 설계 근거를 그린다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(_host(const PathRationalePanel(plan: _plan)));

    expect(find.text('경로 설계 근거'), findsOneWidget);
    expect(find.text('진단에서 비동기 흐름과 테스트 보강이 먼저 필요하다고 나왔어요.'), findsOneWidget);
  });
}
