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

  testWidgets('Today 보조 지표는 주간 활동 다음에 추세를 둔다', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_supportingDashboardHost(_summary));
    await tester.pumpAndSettle();

    final weeklyTop = tester.getTopLeft(
      find.byKey(const Key('weekly-activity-card')),
    );
    final trendTop = tester.getTopLeft(
      find.byKey(const Key('progress-trend-card')),
    );
    expect(weeklyTop.dy, lessThan(trendTop.dy));
    expect(find.byType(DpSide), findsOneWidget);
  });

  // S3-P4: KPI 카드·도넛·배지의 **숫자는 사라지지 않았다** — 「진행」 키-값 패널
  // (`TodayProgressPanel`)이 같은 데이터를 맡고 여기서는 차트만 남는다. 같은 숫자를
  // 한 화면에 두 번 그리지 않기 위한 분담이다.
  testWidgets('Today 보조 지표는 차트만 남기고 KPI·도넛·배지를 갖지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_supportingDashboardHost(_summary));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekly-activity-card')), findsOneWidget);
    expect(find.byKey(const Key('progress-trend-card')), findsOneWidget);
    expect(find.byType(DpKpiCard), findsNothing);
    expect(find.text('62%'), findsNothing);
    expect(find.textContaining('첫걸음'), findsNothing);
  });

  // 옛 코드는 가용 폭 440 미만에서 추세를 숨겼다. 새 사이드 칼럼은 1120 의 1/3
  // (≈373px)이라 그 게이트를 남기면 **데스크톱에서도** 추세가 사라진다 — 게이트를
  // 걷어내고 좁은 폭에서도 차트를 남긴다(차트는 폭에 맞춰 줄어든다).
  testWidgets('Today 보조 지표는 compact 에서도 두 차트를 남긴다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_supportingDashboardHost(_summary));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekly-activity-card')), findsOneWidget);
    expect(find.byKey(const Key('progress-trend-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
