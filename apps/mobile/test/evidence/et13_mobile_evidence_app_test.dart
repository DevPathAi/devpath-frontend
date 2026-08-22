import 'package:devpath_mobile/src/evidence/et13_mobile_evidence_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceSha = '1234567890abcdef1234567890abcdef12345678';

void main() {
  final fixtures = <String, Type>{
    'mobile-today-available': MobileTodayProjection,
    'mobile-content-reading': MobileContentProjection,
  };

  for (final fixture in fixtures.entries) {
    testWidgets(
      '${fixture.key} renders a ready web-safe production projection',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          Et13MobileEvidenceApp(
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
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  test('fixture IDs are ordered and unknown IDs fail closed', () {
    expect(Et13MobileEvidenceApp.fixtureIds, fixtures.keys);
    expect(
      () => buildEt13MobileFixture('unknown-fixture'),
      throwsArgumentError,
    );
  });
}
