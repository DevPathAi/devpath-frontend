import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fixtureIds = <String>[
  'web-today-available',
  'web-path-current-week',
  'web-content-reading',
  'web-workspace-idle',
  'web-review-loaded',
  'web-mentor-context-preview',
  'admin-kpi-dashboard',
  'admin-support-long-wire',
  'mobile-today-available',
  'mobile-content-reading',
  'dp-design-mission-ledger',
  'dp-design-context-payload-preview',
];

void main() {
  final catalogFile = File('../../evidence/et13/catalog.v1.json');
  final visualFile = File('../../evidence/et13/generated/visual-cases.v1.json');
  final a11yFile = File('../../evidence/et13/generated/a11y-cases.v1.json');

  test('approved ET13 v1 fixture catalog exists', () {
    expect(
      catalogFile.existsSync(),
      isTrue,
      reason: 'The approved catalog must be committed before generation.',
    );
  });

  test('approved fixture order and exact 96/24 expansions are immutable', () {
    if (!catalogFile.existsSync()) return;
    final catalog = jsonDecode(catalogFile.readAsStringSync()) as Map;
    final fixtures = (catalog['fixtures'] as List).cast<Map>();
    expect(fixtures.map((fixture) => fixture['id']), _fixtureIds);

    final visual = (catalog['visual_matrix'] as Map).cast<String, Object?>();
    expect(visual['widths'], [320, 600, 840, 1240]);
    expect(visual['themes'], ['light', 'dark']);
    expect(visual['height'], 900);
    expect(visual['device_pixel_ratio'], 1);
    expect(visual['text_scale_percent'], 100);
    expect(visual['locale'], 'ko-KR');
    expect(visual['timezone'], 'UTC');
    expect(visual['reduced_motion'], true);

    final a11y = (catalog['a11y_matrix'] as List).cast<Map>();
    expect(a11y, [
      {'width': 320, 'theme': 'light', 'text_scale_percent': 200},
      {'width': 1240, 'theme': 'dark', 'text_scale_percent': 200},
    ]);
    expect(fixtures.length * 4 * 2, 96);
    expect(fixtures.length * a11y.length, 24);
  });

  test('generated catalogs preserve exact case order and surface counts', () {
    expect(visualFile.existsSync(), isTrue);
    expect(a11yFile.existsSync(), isTrue);
    final visual = jsonDecode(visualFile.readAsStringSync()) as Map;
    final a11y = jsonDecode(a11yFile.readAsStringSync()) as Map;

    expect(visual['schema_version'], 'leva.et13.visual-cases.v1');
    expect(a11y['schema_version'], 'leva.et13.a11y-cases.v1');
    expect(visual['case_catalog_version'], 'leva.et13.catalog.v1');
    expect(a11y['case_catalog_version'], 'leva.et13.catalog.v1');
    expect(visual['fixture_ids'], _fixtureIds);
    expect(a11y['fixture_ids'], _fixtureIds);
    expect(visual['case_count'], 96);
    expect(a11y['case_count'], 24);
    expect(visual['surface_case_counts'], {
      'web': 48,
      'admin': 16,
      'mobile': 16,
      'dp_design': 16,
    });
    expect(a11y['surface_case_counts'], {
      'web': 12,
      'admin': 4,
      'mobile': 4,
      'dp_design': 4,
    });

    final visualCases = (visual['cases'] as List).cast<Map>();
    final a11yCases = (a11y['cases'] as List).cast<Map>();
    expect(visualCases.take(8).map((entry) => entry['case_id']), [
      for (final width in [320, 600, 840, 1240])
        for (final theme in ['light', 'dark'])
          'web-today-available--visual--w$width--$theme',
    ]);
    expect(a11yCases.take(2).map((entry) => entry['case_id']), [
      'web-today-available--a11y--w320--light--text200',
      'web-today-available--a11y--w1240--dark--text200',
    ]);
  });

  test('schemas, exact provenance locks, and vendored Monaco are present', () {
    for (final path in [
      '../../evidence/et13/catalog.schema.json',
      '../../evidence/et13/manifest.schema.json',
      '../../evidence/et13/assets.lock.json',
      '../../evidence/et13/renderer.lock.json',
      '../../tools/et13_evidence.dart',
      'web/vendor/monaco/vs/loader.js',
      'web/vendor/monaco/LICENSE',
      'web/vendor/monaco/ThirdPartyNotices.txt',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    final schema =
        jsonDecode(
              File(
                '../../evidence/et13/catalog.schema.json',
              ).readAsStringSync(),
            )
            as Map;
    expect(schema['additionalProperties'], isFalse);
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('vendor/monaco/vs/loader.js'));
    expect(index, contains("paths: { vs: 'vendor/monaco/vs' }"));
    expect(index, isNot(contains('cdnjs.cloudflare.com/ajax/libs/monaco')));
  });
}
