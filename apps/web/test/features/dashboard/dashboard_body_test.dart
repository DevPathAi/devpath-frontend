import 'package:devpath_web/src/features/dashboard/presentation/widgets/dashboard_body.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _host(DashboardSummary s) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: DashboardBody(summary: s)),
      ),
      GoRoute(path: '/path', builder: (_, _) => const SizedBox()),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

Widget _supportingDashboardHost(DashboardSummary s) => ProviderScope(
  child: MaterialApp(
    theme: DpTheme.light(),
    home: Builder(
      builder: (context) {
        return Scaffold(body: DashboardBody.supportingContent(context, s));
      },
    ),
  ),
);

const _summary = DashboardSummary(
  streakDays: 7,
  progressPercent: 62,
  nextTaskTitle: '비동기 프로그래밍 기초',
  badges: ['첫걸음', '3일 연속'],
  completedContentCount: 12,
  weeklyActivity: [
    DailyActivity(date: '2026-07-30', completedCount: 1),
    DailyActivity(date: '2026-07-31', completedCount: 3),
  ],
  progressHistory: [
    ProgressPoint(date: '2026-07-30', percent: 40),
    ProgressPoint(date: '2026-07-31', percent: 62),
  ],
);

void main() {
  testWidgets('DashboardBody: 스트릭·진행률·완료·CTA·배지 렌더(Expanded 폭)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(_summary));
    await tester.pumpAndSettle();

    expect(find.text('7일'), findsOneWidget); // 스트릭 KPI
    expect(find.text('62%'), findsOneWidget); // 진행률 도넛
    expect(find.text('12'), findsWidgets); // 완료 콘텐츠 KPI
    expect(find.text('이어서 학습'), findsOneWidget); // 히어로 CTA
    expect(find.textContaining('첫걸음'), findsOneWidget); // 배지
  });

  testWidgets('DashboardBody: Compact 폭에서도 핵심 요소 렌더', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(_summary));
    await tester.pumpAndSettle();

    expect(find.text('이어서 학습'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
  });

  testWidgets('DashboardBody: 시계열 카드 2개 렌더(Expanded 폭)', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(_summary));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekly-activity-card')), findsOneWidget);
    expect(find.byKey(const Key('progress-trend-card')), findsOneWidget);
  });

  testWidgets('Today 보조 지표는 이번 주 진행을 스트릭보다 먼저 배치한다', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_supportingDashboardHost(_summary));
    await tester.pumpAndSettle();

    final weeklyTop = tester.getTopLeft(
      find.byKey(const Key('weekly-activity-card')),
    );
    final streakTop = tester.getTopLeft(find.text('연속 학습'));
    expect(weeklyTop.dy, lessThan(streakTop.dy));
  });
}
