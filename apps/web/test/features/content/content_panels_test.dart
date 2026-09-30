import 'package:devpath_web/src/features/content/presentation/content_panels.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

LearningContent _content({double scrollPct = 0.8, bool completed = false}) =>
    LearningContent.fromJson({
      'id': 5,
      'slug': 'async-basics',
      'title': '비동기 기초',
      'track': 'BACKEND',
      'markdown': '본문',
      'conceptTags': <String>[],
      'progress': {
        'scrollPct': scrollPct,
        'dwellSec': 60,
        'completed': completed,
        'completedAt': completed ? '2026-09-01T00:00:00Z' : null,
      },
    });

CurrentMission _mission() => CurrentMission.fromJson({
  'outcome': 'AVAILABLE',
  'pathId': 101,
  'weekNum': 3,
  'tasks': [
    {
      'taskId': 301,
      'orderNum': 1,
      'taskType': 'READ',
      'title': '완료한 읽기',
      'required': true,
      'contentId': 301,
      'contentSlug': 'done',
      'completed': true,
      'completedAt': '2026-08-15T00:00:00Z',
    },
    {
      'taskId': 302,
      'orderNum': 2,
      'taskType': 'READ',
      'title': '지금 읽는 과제',
      'required': true,
      'contentId': 302,
      'contentSlug': 'current',
      'completed': false,
      'completedAt': null,
    },
    {
      'taskId': 303,
      'orderNum': 3,
      'taskType': 'PRACTICE',
      'title': '다음 실습',
      'required': true,
      'contentId': 303,
      'contentSlug': 'next',
      'completed': false,
      'completedAt': null,
    },
  ],
  'nextTask': {
    'taskId': 302,
    'orderNum': 2,
    'taskType': 'READ',
    'title': '지금 읽는 과제',
    'required': true,
    'contentId': 302,
    'contentSlug': 'current',
    'completed': false,
    'completedAt': null,
  },
  'pathCompleted': false,
});

void main() {
  testWidgets('ContentProgressPanel: 진행률과 완료 기준을 말한다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(_host(ContentProgressPanel(content: _content())));

    expect(find.text('콘텐츠 학습 진행률'), findsOneWidget);
    expect(find.textContaining('80%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('ContentProgressPanel: 완료된 콘텐츠는 완료 문구를 말한다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        ContentProgressPanel(content: _content(scrollPct: 1, completed: true)),
      ),
    );

    expect(find.textContaining('완료'), findsWidgets);
    expect(find.textContaining('끝까지 읽으면'), findsNothing);
  });

  testWidgets('ContentMissionPanel: 완료·현재·다음을 구분해 그린다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        ContentMissionPanel(
          mission: _mission(),
          currentTaskId: 302,
          onOpenTask: (_) {},
        ),
      ),
    );

    expect(find.text('현재 학습 미션'), findsOneWidget);
    expect(find.text('완료한 읽기'), findsOneWidget);
    expect(find.text('지금 읽는 과제'), findsOneWidget);
    expect(find.text('다음 실습'), findsOneWidget);
    // 완료 ✓ · 현재 ● · 아직 ·
    expect(find.byType(DpStatusText), findsNWidgets(3));
  });

  testWidgets('ContentMissionPanel: 아직 안 읽은 과제만 링크로 열 수 있다', (tester) async {
    _view(tester, const Size(1280, 900));
    WeeklyTask? opened;
    await tester.pumpWidget(
      _host(
        ContentMissionPanel(
          mission: _mission(),
          currentTaskId: 302,
          onOpenTask: (task) => opened = task,
        ),
      ),
    );

    // 지금 읽는 과제와 완료한 과제는 링크가 아니다 — 갈 곳이 지금 이 화면이다.
    expect(find.byType(DpLink), findsOneWidget);

    await tester.tap(find.text('다음 실습'));
    await tester.pump();

    expect(opened?.taskId, 303);
  });

  testWidgets('ContentMissionPanel: 미션이 없으면 아무것도 그리지 않는다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        ContentMissionPanel(
          mission: null,
          currentTaskId: null,
          onOpenTask: (_) {},
        ),
      ),
    );

    expect(find.text('현재 학습 미션'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
