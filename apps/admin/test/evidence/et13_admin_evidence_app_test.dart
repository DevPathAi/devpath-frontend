import 'package:devpath_admin/src/evidence/et13_admin_evidence_app.dart';
import 'package:flutter/material.dart';
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
}
