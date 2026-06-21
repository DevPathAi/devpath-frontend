import 'package:devpath_web/src/features/path/presentation/path_plan_view.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _host(LearningPath plan) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: PathPlanView(plan: plan)),
);

void main() {
  testWidgets('milestones 기반 진단 요약·이번 주 과제·로드맵을 렌더', (tester) async {
    final plan = LearningPath.fromJson({
      'pathId': 101,
      'track': 'BACKEND',
      'totalWeeks': 12,
      'rationale': '비동기 보강이 필요해요.',
      'diagnosis': {
        'diagnosedLevel': 'MID',
        'strengthConcepts': ['HTTP'],
        'weaknessConcepts': ['트랜잭션'],
      },
      'milestones': [
        {
          'weekNum': 1,
          'title': '비동기 기초',
          'goalDescription': 'Future와 Stream을 이해합니다.',
          'targetSkills': ['Future', 'Stream'],
          'estimatedHours': 4,
          'whyThisOrder': '먼저 약점을 보강합니다.',
          'expectedOutcome': '비동기 API를 안정적으로 작성할 수 있어요.',
          'locked': false,
          'tasks': [
            {
              'orderNum': 1,
              'taskType': 'READ',
              'title': 'Future 정리',
              'required': true,
              'contentId': 1,
              'contentSlug': 'future',
              'completed': false,
            },
            {
              'orderNum': 2,
              'taskType': 'PRACTICE',
              'title': 'Stream 구독 실습',
              'required': true,
              'contentId': 2,
              'contentSlug': 'stream',
              'completed': false,
            },
            {
              'orderNum': 3,
              'taskType': 'QUIZ',
              'title': '비동기 퀴즈',
              'required': false,
              'contentId': null,
              'contentSlug': null,
              'completed': false,
            },
          ],
        },
        {
          'weekNum': 2,
          'title': '트랜잭션 심화',
          'goalDescription': '트랜잭션 경계를 이해합니다.',
          'targetSkills': ['Transaction'],
          'estimatedHours': 3,
          'whyThisOrder': '비동기 이후 영속성을 다룹니다.',
          'expectedOutcome': '경계를 설명할 수 있어요.',
          'locked': true,
          'tasks': <Map<String, dynamic>>[],
        },
      ],
    });

    await tester.pumpWidget(_host(plan));

    expect(find.text('현재 수준 MID'), findsOneWidget);
    expect(find.text('HTTP'), findsOneWidget);
    expect(find.text('트랜잭션'), findsOneWidget);
    expect(find.text('비동기 API를 안정적으로 작성할 수 있어요.'), findsOneWidget);
    expect(find.text('Future 정리'), findsOneWidget);
    expect(find.text('Stream 구독 실습'), findsOneWidget);
    expect(find.text('비동기 퀴즈'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('트랜잭션 심화'), findsOneWidget);
  });

  testWidgets('contentSlug가 있으면 slug 기반 content route로 이동한다', (tester) async {
    await tester.pumpWidget(
      _routerHost(
        _planWithTask(title: 'Future 정리', contentId: 1, contentSlug: 'future'),
      ),
    );

    await tester.tap(find.text('Future 정리'));
    await tester.pumpAndSettle();

    expect(find.text('content future'), findsOneWidget);
  });

  testWidgets('contentSlug가 없으면 contentId 기반 content route로 이동한다', (
    tester,
  ) async {
    await tester.pumpWidget(
      _routerHost(
        _planWithTask(title: 'ID 콘텐츠', contentId: 3, contentSlug: null),
      ),
    );

    await tester.tap(find.text('ID 콘텐츠'));
    await tester.pumpAndSettle();

    expect(find.text('content 3'), findsOneWidget);
  });

  testWidgets('content target이 없으면 이동하지 않는다', (tester) async {
    await tester.pumpWidget(
      _routerHost(
        _planWithTask(title: '이동 없음', contentId: null, contentSlug: null),
      ),
    );

    await tester.tap(find.text('이동 없음'));
    await tester.pumpAndSettle();

    expect(find.text('이동 없음'), findsOneWidget);
    expect(find.textContaining('content '), findsNothing);
  });
}

Widget _routerHost(LearningPath plan) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: PathPlanView(plan: plan)),
      ),
      GoRoute(
        path: '/content/:id',
        builder: (_, state) => Text('content ${state.pathParameters['id']}'),
      ),
    ],
  );

  return MaterialApp.router(theme: DpTheme.light(), routerConfig: router);
}

LearningPath _planWithTask({
  required String title,
  required int? contentId,
  required String? contentSlug,
}) => LearningPath.fromJson({
  'pathId': 101,
  'track': 'BACKEND',
  'totalWeeks': 12,
  'rationale': '경로',
  'milestones': [
    {
      'weekNum': 1,
      'title': '1주차',
      'goalDescription': '목표',
      'targetSkills': <String>[],
      'estimatedHours': 4,
      'whyThisOrder': '순서',
      'expectedOutcome': '결과',
      'locked': false,
      'tasks': [
        {
          'orderNum': 1,
          'taskType': 'READ',
          'title': title,
          'required': true,
          'contentId': contentId,
          'contentSlug': contentSlug,
          'completed': false,
        },
      ],
    },
  ],
});
