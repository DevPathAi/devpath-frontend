import 'package:devpath_admin/src/features/dashboard/data/dashboard_source.dart';
import 'package:devpath_admin/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = <String, int>{
  // Deliberately shuffled: the UI contract owns the display order.
  'aiCalls': 9421,
  'openReports': 2,
  'dau': 1280,
  'newUsers': 64,
};

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  Map<String, int> stats = _stats,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminStatsFetchProvider.overrideWithValue(() async => stats)],
      child: MaterialApp(
        theme: DpTheme.light(),
        home: const AdminDashboardPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (width, columns) in const [
    (320.0, 1),
    (600.0, 2),
    (840.0, 4),
    (1240.0, 4),
  ]) {
    testWidgets('$width px uses $columns KPI column(s)', (tester) async {
      await _pump(tester, width: width);

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, columns);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('uses DpKpiCard in canonical order with zero count-up duration', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, width: 1240);

    final cards = tester.widgetList<DpKpiCard>(find.byType(DpKpiCard)).toList();
    expect(cards.map((card) => card.label), [
      'DAU',
      '신규 가입',
      '미처리 신고',
      'AI 호출',
    ]);
    expect(cards.map((card) => card.value), [1280, 64, 2, 9421]);
    expect(
      cards.map((card) => card.countUpDuration),
      everyElement(Duration.zero),
    );
    expect(find.bySemanticsLabel('DAU 1280'), findsOneWidget);
    expect(find.bySemanticsLabel('미처리 신고 2'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'empty stats render an honest empty state instead of blank cards',
    (tester) async {
      await _pump(tester, width: 840, stats: const {});

      expect(find.byType(DpEmpty), findsOneWidget);
      expect(find.byType(DpKpiCard), findsNothing);
    },
  );
}
