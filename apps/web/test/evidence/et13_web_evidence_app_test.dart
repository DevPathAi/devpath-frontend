import 'package:devpath_web/src/evidence/et13_web_evidence_app.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceSha = '1234567890abcdef1234567890abcdef12345678';

void main() {
  final fixtures = <String, Type>{
    'web-today-available': TodayMissionSection,
    'web-path-current-week': MissionPathPlanView,
    'web-content-reading': WebContentProjection,
    'web-workspace-idle': MonacoEditorView,
    'web-review-loaded': WebReviewProjection,
    'web-mentor-context-preview': WebMentorContextProjection,
    'dp-design-mission-ledger': DpEt13MissionLedgerFixture,
    'dp-design-context-payload-preview': DpEt13ContextPayloadPreviewFixture,
  };

  for (final fixture in fixtures.entries) {
    testWidgets('${fixture.key} renders a ready production projection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(840, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        Et13WebEvidenceApp(
          fixtureId: fixture.key,
          brightness: Brightness.dark,
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
      expect(
        find.bySemanticsLabel('ET13_SOURCE_SHA:$_sourceSha'),
        findsOneWidget,
      );
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(fixture.value)),
        ).scale(1),
        2,
      );
      expect(
        Theme.of(tester.element(find.byType(fixture.value))).brightness,
        Brightness.dark,
      );
      semantics.dispose();
    });
  }

  test('fixture IDs are ordered and unknown IDs fail closed', () {
    expect(Et13WebEvidenceApp.fixtureIds, fixtures.keys);
    expect(() => buildEt13WebFixture('unknown-fixture'), throwsArgumentError);
  });
}
