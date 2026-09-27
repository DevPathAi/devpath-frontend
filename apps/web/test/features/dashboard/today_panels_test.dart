import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/dashboard/presentation/widgets/today_panels.dart';

/// 이번 주 과제 3개 — 1개 완료, 2번째가 다음, 3번째 대기.
CurrentMission _mission({List<Map<String, Object?>>? tasks}) {
  final items =
      tasks ??
      <Map<String, Object?>>[
        {
          'taskId': 11,
          'orderNum': 1,
          'taskType': 'READ',
          'title': 'Future/async-await 정리',
          'required': true,
          'contentId': 5,
          'contentSlug': 'future-async-await',
          'completed': true,
          'completedAt': '2026-09-26T02:00:00.000Z',
        },
        {
          'taskId': 12,
          'orderNum': 2,
          'taskType': 'PRACTICE',
          'title': 'Stream 구독 실습',
          'required': true,
          'contentId': 6,
          'contentSlug': 'stream-subscription',
          'completed': false,
          'completedAt': null,
        },
        {
          'taskId': 13,
          'orderNum': 3,
          'taskType': 'QUIZ',
          'title': '에러 처리 패턴 적용',
          'required': true,
          'contentId': null,
          'contentSlug': null,
          'completed': false,
          'completedAt': null,
        },
      ];
  return CurrentMission.fromJson({
    'outcome': 'AVAILABLE',
    'pathId': 301,
    'weekNum': 1,
    'tasks': items,
    'nextTask': items.length > 1 ? items[1] : null,
    'pathCompleted': false,
  });
}

Widget _host(Widget child, {Size size = const Size(1280, 900)}) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: size.width,
        child: SingleChildScrollView(child: child),
      ),
    ),
  ),
);

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('TodayTasksPanel: 과제 3개를 상태와 함께 표로 그린다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(TodayTasksPanel(mission: _mission(), onOpenTask: (_) {})),
    );

    expect(find.text('이번 주 과제'), findsOneWidget);
    expect(find.text('Future/async-await 정리'), findsOneWidget);
    expect(find.text('Stream 구독 실습'), findsOneWidget);
    expect(find.text('에러 처리 패턴 적용'), findsOneWidget);
    expect(find.text('✓ 완료'), findsOneWidget);
    expect(find.text('● 다음'), findsOneWidget);
    expect(find.text('대기'), findsOneWidget);
  });

  testWidgets('TodayTasksPanel: 제목 링크를 누르면 그 과제를 넘긴다', (tester) async {
    _view(tester, const Size(1280, 900));
    WeeklyTask? opened;
    await tester.pumpWidget(
      _host(
        TodayTasksPanel(mission: _mission(), onOpenTask: (t) => opened = t),
      ),
    );

    await tester.tap(find.text('Stream 구독 실습'));
    await tester.pump();

    expect(opened?.taskId, 12);
  });

  testWidgets('TodayTasksPanel: compact 에서 유형 칼럼을 감춘다', (tester) async {
    _view(tester, const Size(390, 900));
    await tester.pumpWidget(
      _host(
        TodayTasksPanel(mission: _mission(), onOpenTask: (_) {}),
        size: const Size(390, 900),
      ),
    );

    expect(find.text('유형'), findsNothing);
    expect(find.text('과제'), findsOneWidget);
  });

  testWidgets('TodayTasksPanel: 과제가 없으면 빈 상태를 말한다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        TodayTasksPanel(
          mission: _mission(tasks: const []),
          onOpenTask: (_) {},
        ),
      ),
    );

    expect(find.text('이번 주 과제가 아직 없어요'), findsOneWidget);
  });

  testWidgets('TodayProgressPanel: 옛 KPI·도넛·배지의 숫자를 키-값으로 모은다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        TodayProgressPanel(
          summary: const DashboardSummary(
            streakDays: 7,
            progressPercent: 33,
            completedContentCount: 2,
            badges: ['첫 경로', '7일 연속'],
          ),
          mission: _mission(),
        ),
      ),
    );

    expect(find.text('진행'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget); // 이번 주
    expect(find.text('1주차'), findsOneWidget); // 현재 주차
    expect(find.text('33%'), findsOneWidget); // 옛 도넛
    expect(find.text('7일'), findsOneWidget); // 옛 KPI 연속 학습
    expect(find.text('2개'), findsOneWidget); // 옛 KPI 완료 콘텐츠
    expect(find.text('첫 경로'), findsOneWidget); // 옛 배지 스트립
  });

  testWidgets('TodayProgressPanel: 280px 패널 + 200% 배율에서 오버플로가 없다', (
    tester,
  ) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          theme: DpTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 280,
                child: TodayProgressPanel(
                  summary: const DashboardSummary(
                    streakDays: 7,
                    progressPercent: 33,
                    completedContentCount: 2,
                    badges: ['첫 경로', '7일 연속'],
                  ),
                  mission: _mission(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('TodayHelpPanel: 멘토·Q/A 링크 둘을 구분선 목록으로 그린다', (tester) async {
    _view(tester, const Size(1280, 900));
    var mentor = 0;
    var qna = 0;
    await tester.pumpWidget(
      _host(
        TodayHelpPanel(onOpenMentor: () => mentor++, onOpenQna: () => qna++),
      ),
    );

    expect(find.text('막히면'), findsOneWidget);
    await tester.tap(find.text('AI 멘토에게 이 과제 물어보기'));
    await tester.tap(find.text('Q/A 에서 비슷한 질문 찾기'));
    await tester.pump();
    expect(mentor, 1);
    expect(qna, 1);
  });

  testWidgets('TodayWhyPanel: 근거 문장과 경로 전체 보기 링크를 그린다', (tester) async {
    _view(tester, const Size(1280, 900));
    var opened = 0;
    await tester.pumpWidget(
      _host(
        TodayWhyPanel(
          why: '서버가 정한 이번 주의 첫 미완료 과제예요.',
          onOpenPath: () => opened++,
        ),
      ),
    );

    expect(find.text('왜 이 순서인가요'), findsOneWidget);
    expect(find.text('서버가 정한 이번 주의 첫 미완료 과제예요.'), findsOneWidget);
    await tester.tap(find.text('경로 전체 보기'));
    await tester.pump();
    expect(opened, 1);
  });
}
