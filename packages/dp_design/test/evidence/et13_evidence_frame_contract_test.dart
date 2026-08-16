import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceSha = '1234567890abcdef1234567890abcdef12345678';

void main() {
  test('launch config rejects bad URI axes and invalid source identity', () {
    expect(
      () => DpEt13EvidenceLaunchConfig.fromUri(
        uri: Uri.parse('/?fixture=fixture-a&unexpected=true'),
        allowedFixtureIds: const ['fixture-a'],
        sourceSha: _sourceSha,
      ),
      throwsArgumentError,
    );
    expect(
      () => DpEt13EvidenceLaunchConfig.fromUri(
        uri: Uri.parse('/?fixture=fixture-b'),
        allowedFixtureIds: const ['fixture-a'],
        sourceSha: _sourceSha,
      ),
      throwsArgumentError,
    );
    expect(
      () => DpEt13EvidenceLaunchConfig.fromUri(
        uri: Uri.parse('/?fixture=fixture-a'),
        allowedFixtureIds: const ['fixture-a'],
        sourceSha: '0000000000000000000000000000000000000000',
      ),
      throwsArgumentError,
    );
    expect(
      () => DpEt13EvidenceLaunchConfig.fromUri(
        uri: Uri.parse('/?fixture=fixture-a'),
        allowedFixtureIds: const ['fixture-a'],
        sourceSha: 'not-a-source-sha',
      ),
      throwsArgumentError,
    );
  });

  testWidgets('ready marker is paired with exact runtime capture axes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      DpEt13EvidenceFrame(
        fixtureId: 'fixture-a',
        brightness: Brightness.dark,
        textScale: 2,
        sourceSha: _sourceSha,
        waitForFonts: () async {},
        child: const Scaffold(body: Text('fixture')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Leva ET13 Evidence',
      reason: 'the release renderer must not clear the browser document title',
    );
    expect(
      find.bySemanticsLabel(
        'ET13_RUNTIME_PROFILE:fixture=fixture-a;width=320;height=900;dpr=1;brightness=dark;textScalePercent=200',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
