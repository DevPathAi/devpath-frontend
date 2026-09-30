// `.design-sync/conventions.md` is prepended verbatim to `ds-bundle/README.md`
// (`.design-sync/config.json` `readmeHeader`, consumed by `.design-sync/scripts/build_ds_readme.py`),
// and that README is the artifact uploaded to the Claude Design project `Leva Design Tokens`.
// A token name that drifts in this file therefore ships to designers as a live instruction, and a
// CSS custom property that does not exist fails silently — no console error, no build failure.
// 2026-09-24 (contract 2.0.0): the `rail*` → `header*` rename left six dead `--dp-color-rail-*`
// names, a 44×44 accessibility floor and contract-1.0.0 layout numbers in this file. Nothing tested
// it, so the drift reached the published design system. This test is that gate.
import 'dart:io';

import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Names the design-sync dump adds on top of the manifest projection
/// (`test/theme/dp_semantic_tokens_dump_test.dart` builds the same set).
const _dumpOnly = {
  '--dp-layout-content-max',
  '--dp-layout-readable-max',
  '--dp-layout-header-height',
  '--dp-layout-rail',
  '--dp-layout-rail-collapsed',
  '--dp-breakpoint-medium',
  '--dp-breakpoint-expanded',
  '--dp-breakpoint-large',
};

void main() {
  final file = File('../../.design-sync/conventions.md');
  final text = file.existsSync() ? file.readAsStringSync() : '';

  setUp(() {
    expect(file.existsSync(), isTrue, reason: file.absolute.path);
  });

  test(
    'every --dp-* name it teaches is a custom property the contract actually projects',
    () {
      final projected = <String>{
        ...DpSemanticTokenManifest.cssCustomProperties(Brightness.light).keys,
        ..._dumpOnly,
      };
      // `--dp-state-{default,hover,…}-{background,…}` is a brace pattern, not a name: the match stops
      // at the brace and ends in a hyphen. Those placeholders are the only legitimate partial names.
      final mentioned = RegExp(r'--dp-[a-z0-9-]+')
          .allMatches(text)
          .map((match) => match[0]!)
          .where((name) => !name.endsWith('-'))
          .toSet();
      expect(mentioned, isNotEmpty);
      expect(
        mentioned.difference(projected),
        isEmpty,
        reason:
            'conventions.md names custom properties the manifest does not project',
      );
    },
  );

  test(
    'it teaches every token family the contract publishes, including density',
    () {
      for (final name in const [
        '--dp-density-control-height',
        '--dp-density-row-padding',
        '--dp-density-min-target',
        '--dp-layout-header-height',
      ]) {
        expect(
          text,
          contains(name),
          reason: '$name is missing from conventions.md',
        );
      }
    },
  );

  test('its accessibility floor and layout numbers match contract 2.0.0', () {
    expect(text, contains('24×24'));
    expect(text, isNot(contains('44×44')));
    expect(text, isNot(contains('minHeight: 44')));
    // Contract 1.0.0 layout numbers that survived two contract bumps in this file.
    for (final stale in const ['1440px', '880px', '256px', '72px', '1360px']) {
      expect(
        text,
        isNot(contains(stale)),
        reason: '$stale is a superseded layout value',
      );
    }
    expect(text, contains('1120px'));
    expect(text, contains('760px'));
  });
}
