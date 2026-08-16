import 'package:devpath_admin/src/evidence/et13_admin_evidence_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceSha = '1234567890abcdef1234567890abcdef12345678';

void main() {
  final fixtures = <String, Type>{
    'admin-kpi-dashboard': AdminKpiDashboardProjection,
    'admin-support-long-wire': AdminSupportDetailProjection,
  };

  for (final fixture in fixtures.entries) {
    testWidgets('${fixture.key} renders a ready production projection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        Et13AdminEvidenceApp(
          fixtureId: fixture.key,
          brightness: Brightness.light,
          textScale: 2,
          sourceSha: _sourceSha,
          waitForFonts: () async {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(fixture.value), findsOneWidget);
      expect(
        find.bySemanticsLabel('ET13_READY:${fixture.key}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  test('fixture IDs are ordered and unknown IDs fail closed', () {
    expect(Et13AdminEvidenceApp.fixtureIds, fixtures.keys);
    expect(() => buildEt13AdminFixture('unknown-fixture'), throwsArgumentError);
  });

  testWidgets(
    'overflowing KPI dashboard exposes a keyboard-focusable scroll region',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const Et13AdminEvidenceApp(
          fixtureId: 'admin-kpi-dashboard',
          brightness: Brightness.light,
          textScale: 2,
          sourceSha: _sourceSha,
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(AdminKpiDashboardProjection),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        greaterThan(0),
      );
      final focusTarget = find.byKey(
        const ValueKey('admin-kpi-dashboard-scroll-focus-target'),
      );
      expect(focusTarget, findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('운영 대시보드. 위아래 화살표로 스크롤')),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(focusTarget)
            .flagsCollection
            .isFocused
            .toBoolOrNull(),
        isNotNull,
        reason: 'a nullable focus flag means the scroll region is not tabbable',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(Focus.of(tester.element(focusTarget)).hasFocus, isTrue);
      final beforeArrow = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(beforeArrow),
      );

      final focusedDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(
                      const ValueKey('admin-kpi-dashboard-focus-ring'),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(focusedDecoration.border, isNotNull);

      semantics.dispose();
    },
  );

  testWidgets('fitting KPI dashboard has no inert keyboard scroll target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const Et13AdminEvidenceApp(
        fixtureId: 'admin-kpi-dashboard',
        brightness: Brightness.light,
        textScale: 1,
        sourceSha: _sourceSha,
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(AdminKpiDashboardProjection),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      0,
    );
    expect(
      find.byKey(const ValueKey('admin-kpi-dashboard-scroll-focus-target')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(RegExp('운영 대시보드. 위아래 화살표로 스크롤')),
      findsNothing,
    );

    semantics.dispose();
  });

  testWidgets(
    'resizing a focused dashboard clears its obsolete scroll target',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const Et13AdminEvidenceApp(
          fixtureId: 'admin-kpi-dashboard',
          brightness: Brightness.light,
          textScale: 2,
          sourceSha: _sourceSha,
        ),
      );
      await tester.pumpAndSettle();
      final focusTarget = find.byKey(
        const ValueKey('admin-kpi-dashboard-scroll-focus-target'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(Focus.of(tester.element(focusTarget)).hasFocus, isTrue);

      tester.view.physicalSize = const Size(1240, 900);
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(AdminKpiDashboardProjection),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        0,
      );
      expect(focusTarget, findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('Admin KPI dashboard scroll'),
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(
                      const ValueKey('admin-kpi-dashboard-focus-ring'),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.border, isNull);

      semantics.dispose();
    },
  );

  testWidgets(
    'overflowing support detail owns a keyboard-focusable scroll region',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const Et13AdminEvidenceApp(
          fixtureId: 'admin-support-long-wire',
          brightness: Brightness.light,
          textScale: 2,
          sourceSha: _sourceSha,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-support-detail-scroll-view')),
        findsOneWidget,
      );
      final scrollable = find
          .descendant(
            of: find.byType(AdminSupportDetailProjection),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        greaterThan(0),
      );
      final focusTarget = find.byKey(
        const ValueKey('admin-support-detail-scroll-focus-target'),
      );
      expect(focusTarget, findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('제보 상세. 위아래 화살표로 스크롤')),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(focusTarget)
            .flagsCollection
            .isFocused
            .toBoolOrNull(),
        isNotNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(Focus.of(tester.element(focusTarget)).hasFocus, isTrue);
      final beforeArrow = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(beforeArrow),
      );

      final focusedDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(
                      const ValueKey('admin-support-detail-focus-ring'),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(focusedDecoration.border, isNotNull);

      semantics.dispose();
    },
  );

  testWidgets('fitting support detail has no inert keyboard scroll target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const Et13AdminEvidenceApp(
        fixtureId: 'admin-support-long-wire',
        brightness: Brightness.dark,
        textScale: 1,
        sourceSha: _sourceSha,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-support-detail-scroll-view')),
      findsOneWidget,
    );
    final scrollable = find
        .descendant(
          of: find.byType(AdminSupportDetailProjection),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      0,
    );
    expect(
      find.byKey(const ValueKey('admin-support-detail-scroll-focus-target')),
      findsNothing,
    );
    expect(find.bySemanticsLabel(RegExp('제보 상세. 위아래 화살표로 스크롤')), findsNothing);

    semantics.dispose();
  });

  testWidgets(
    'resizing focused support detail clears its obsolete scroll target',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const Et13AdminEvidenceApp(
          fixtureId: 'admin-support-long-wire',
          brightness: Brightness.light,
          textScale: 2,
          sourceSha: _sourceSha,
        ),
      );
      await tester.pumpAndSettle();
      final focusTarget = find.byKey(
        const ValueKey('admin-support-detail-scroll-focus-target'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(Focus.of(tester.element(focusTarget)).hasFocus, isTrue);

      tester.view.physicalSize = const Size(1240, 900);
      await tester.pumpWidget(
        const Et13AdminEvidenceApp(
          fixtureId: 'admin-support-long-wire',
          brightness: Brightness.light,
          textScale: 1,
          sourceSha: _sourceSha,
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(AdminSupportDetailProjection),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        0,
      );
      expect(focusTarget, findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('Admin support detail scroll'),
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(
                      const ValueKey('admin-support-detail-focus-ring'),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.border, isNull);

      semantics.dispose();
    },
  );
}
