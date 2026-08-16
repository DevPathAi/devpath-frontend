import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tools/et13_evidence.dart' as et13;

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

Uint8List _pngHeader(int width, int height) {
  final bytes = Uint8List(24)
    ..setRange(0, 8, const [137, 80, 78, 71, 13, 10, 26, 10])
    ..setRange(12, 16, const [73, 72, 68, 82]);
  void writeUint32(int offset, int value) {
    bytes[offset] = (value >> 24) & 0xff;
    bytes[offset + 1] = (value >> 16) & 0xff;
    bytes[offset + 2] = (value >> 8) & 0xff;
    bytes[offset + 3] = value & 0xff;
  }

  writeUint32(16, width);
  writeUint32(20, height);
  return bytes;
}

({Directory root, File manifest, Map<String, dynamic> document})
_visualResultFixture() {
  final root = Directory.systemTemp.createTempSync('et13-visual-results-');
  final generated =
      jsonDecode(
            File(
              '../../evidence/et13/generated/visual-cases.v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = <Map<String, Object?>>[];
  for (final raw in (generated['cases'] as List).cast<Map>()) {
    final relative = raw['artifact_path']! as String;
    final bytes = _pngHeader(raw['width']! as int, raw['height']! as int);
    final artifact = File.fromUri(root.uri.resolve(relative));
    artifact.parent.createSync(recursive: true);
    artifact.writeAsBytesSync(bytes);
    cases.add({
      'case_id': raw['case_id'],
      'status': 'passed',
      'artifact_path': relative,
      'sha256': sha256.convert(bytes).toString(),
      'bytes': bytes.length,
    });
  }
  final document = <String, dynamic>{
    'evidence_mode': 'diagnostic',
    'case_count': 96,
    'surface_case_counts': generated['surface_case_counts'],
    'cases': cases,
  };
  final manifest = File('${root.path}/visual-manifest.json')
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(document)}\n',
    );
  return (root: root, manifest: manifest, document: document);
}

({Directory root, File manifest, Map<String, dynamic> document})
_a11yResultFixture() {
  final root = Directory.systemTemp.createTempSync('et13-a11y-results-');
  final generated =
      jsonDecode(
            File(
              '../../evidence/et13/generated/a11y-cases.v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = <Map<String, Object?>>[];
  for (final raw in (generated['cases'] as List).cast<Map>()) {
    final relative = raw['artifact_path']! as String;
    final detail = <String, Object?>{
      'schema_version': 'leva.et13.a11y-result.v1',
      'case_id': raw['case_id'],
      'standard': 'WCAG 2.2 AA',
      'critical_violations': 0,
      'serious_violations': 0,
      'other_violations': 0,
      'passes': 1,
      'incomplete': 0,
      'violations': <Object?>[],
    };
    final artifact = File.fromUri(root.uri.resolve(relative));
    artifact.parent.createSync(recursive: true);
    artifact.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(detail)}\n',
    );
    cases.add({
      'case_id': raw['case_id'],
      'status': 'passed',
      'artifact_path': relative,
      'sha256': sha256.convert(artifact.readAsBytesSync()).toString(),
      'bytes': artifact.lengthSync(),
      'standard': 'WCAG 2.2 AA',
      'critical_violations': 0,
      'serious_violations': 0,
      'other_violations': 0,
      'passes': 1,
      'incomplete': 0,
    });
  }
  final document = <String, dynamic>{
    'evidence_mode': 'diagnostic',
    'case_count': 24,
    'surface_case_counts': generated['surface_case_counts'],
    'cases': cases,
  };
  final manifest = File('${root.path}/a11y-manifest.json')
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(document)}\n',
    );
  return (root: root, manifest: manifest, document: document);
}

void _writeManifest(File file, Map<String, dynamic> document) =>
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(document)}\n',
    );

String _fileSha(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

Object? _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalJson(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalJson).toList(growable: false);
  }
  return value;
}

String _canonicalSha(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalJson(value)))).toString();

Map<String, dynamic> _fullManifest(String kind, Map<String, dynamic> result) {
  final visual = kind == 'visual';
  final catalogPath = '../../evidence/et13/catalog.v1.json';
  final casePath =
      '../../evidence/et13/generated/${visual ? 'visual' : 'a11y'}-cases.v1.json';
  final assetsPath = '../../evidence/et13/assets.lock.json';
  final rendererPath = '../../evidence/et13/renderer.lock.json';
  final catalog = jsonDecode(File(catalogPath).readAsStringSync()) as Map;
  final generated = jsonDecode(File(casePath).readAsStringSync()) as Map;
  final renderer = jsonDecode(File(rendererPath).readAsStringSync()) as Map;
  return <String, dynamic>{
    'schema_version': visual
        ? 'leva.et13.visual-manifest.v1'
        : 'leva.et13.a11y-manifest.v1',
    'evidence_mode': 'diagnostic',
    'case_catalog_version': 'leva.et13.catalog.v1',
    'case_catalog_schema_version': visual
        ? 'leva.et13.visual-cases.v1'
        : 'leva.et13.a11y-cases.v1',
    'fixture_ids': generated['fixture_ids'],
    'source_sha': '1234567890abcdef1234567890abcdef12345678',
    'catalog_sha256': _fileSha(catalogPath),
    'case_catalog_sha256': _fileSha(casePath),
    'projection_contract_sha256': catalog['projection_contract_sha256'],
    'assets_lock_sha256': _fileSha(assetsPath),
    'renderer_lock_sha256': _fileSha(rendererPath),
    'input_provenance_sha256':
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'renderer_image': renderer['image'],
    'renderer_image_digest': renderer['manifest_digest'],
    'capture_network': 'none',
    'unexpected_request_policy': 'fail',
    'capture_surface': 'flutter_web_release_projection',
    'device_evidence': false,
    'external_accessibility_status': 'not_satisfied',
    if (visual) ...{
      'baseline_status': 'pending_external_review',
      'baseline_set_sha256': null,
      'baseline_approval_sha256': null,
    },
    'case_count': result['case_count'],
    'surface_case_counts': result['surface_case_counts'],
    'cases': result['cases'],
  };
}

Map<String, Object?> _validateManifestDocument(String kind, File file) =>
    et13.validateResultManifestDocument(
      kind: kind,
      manifestPath: file.path,
      catalogPath: '../../evidence/et13/catalog.v1.json',
      generatedCatalogPath: '../../evidence/et13/generated/$kind-cases.v1.json',
      assetsLockPath: '../../evidence/et13/assets.lock.json',
      rendererLockPath: '../../evidence/et13/renderer.lock.json',
    );

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
    const projectionDigest =
        'c66d08b6425628a06b27d07e08d648cfb3568d9db7c8d8aca2371172ccf4bde3';
    expect(visual['projection_contract_sha256'], projectionDigest);
    expect(a11y['projection_contract_sha256'], projectionDigest);
    expect(visual.containsKey('projection_contract_version'), isFalse);
    expect(a11y.containsKey('projection_contract_version'), isFalse);
    expect(visual['projection_matrix'], a11y['projection_matrix']);
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

  test(
    'every fixture declares immutable projection scope and substitutions',
    () {
      final catalog = jsonDecode(catalogFile.readAsStringSync()) as Map;
      final fixtures = (catalog['fixtures'] as List).cast<Map>();
      expect(
        catalog['projection_contract_version'],
        'leva.et13.projection-contract.v1',
      );
      expect(
        catalog['projection_contract_sha256'],
        'c66d08b6425628a06b27d07e08d648cfb3568d9db7c8d8aca2371172ccf4bde3',
      );
      final projectionMatrix = (catalog['projection_matrix'] as List)
          .cast<Map>();
      expect(projectionMatrix, hasLength(12));
      for (final fixture in fixtures) {
        expect(
          fixture.keys,
          containsAllInOrder([
            'capture_scope',
            'source_widget',
            'substitutions',
          ]),
        );
        expect(
          fixture['capture_scope'],
          isIn(['full_route', 'body_projection', 'component_projection']),
        );
        expect(fixture['source_widget'], isNotEmpty);
        expect(fixture['substitutions'], isA<List>());
        expect((fixture['substitutions'] as List), isNotEmpty);
        final row = projectionMatrix[fixtures.indexOf(fixture)];
        expect(row, {
          'fixture_id': fixture['id'],
          'capture_scope': fixture['capture_scope'],
          'source_widget': fixture['source_widget'],
          'substitutions': fixture['substitutions'],
        });
      }
      final mobile = fixtures.where(
        (fixture) => (fixture['id'] as String).startsWith('mobile-'),
      );
      for (final fixture in mobile) {
        expect(fixture['capture_scope'], 'body_projection');
        expect(
          (fixture['substitutions'] as List).join(' '),
          contains('native AppBar'),
        );
      }
    },
  );

  test('schemas, exact provenance locks, and vendored Monaco are present', () {
    for (final path in [
      '../../evidence/et13/catalog.schema.json',
      '../../evidence/et13/generated-cases.schema.json',
      '../../evidence/et13/manifest.schema.json',
      '../../evidence/et13/evidence.schema.json',
      '../../evidence/et13/baseline-approval.schema.json',
      '../../evidence/et13/release-bundle.v1.json',
      '../../evidence/et13/assets.lock.json',
      '../../evidence/et13/renderer.lock.json',
      '../../tools/et13_evidence.dart',
      '../../packages/dp_design/lib/src/evidence/et13_font_asset_ready.dart',
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

  test(
    'renderer and distribution contracts fail closed for browser evidence',
    () {
      final renderer =
          jsonDecode(
                File(
                  '../../evidence/et13/renderer.lock.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(renderer.keys, [
        'schema_version',
        'image',
        'platform',
        'index_digest',
        'manifest_digest',
        'playwright_version',
        'chromium_revision',
        'chromium_version',
        'locale',
        'timezone',
        'device_pixel_ratio',
        'reduced_motion',
        'capture_network',
        'unexpected_request_policy',
        'capture_surface',
        'device_evidence',
        'external_accessibility_status',
      ]);
      expect(renderer['capture_network'], 'none');
      expect(renderer['unexpected_request_policy'], 'fail');
      expect(renderer['capture_surface'], 'flutter_web_release_projection');
      expect(renderer['device_evidence'], isFalse);
      expect(renderer['external_accessibility_status'], 'not_satisfied');

      final attributes = File('../../.gitattributes').readAsStringSync();
      expect(attributes, contains('pubspec.lock text eol=lf'));
      expect(attributes, contains('evidence/et13/**/*.json text eol=lf'));
      expect(
        attributes,
        contains('apps/web/web/vendor/monaco/vs/** -text -diff'),
      );
      expect(
        attributes,
        isNot(contains('apps/web/web/vendor/monaco/** -text -diff')),
      );

      final lock =
          jsonDecode(
                File('../../evidence/et13/assets.lock.json').readAsStringSync(),
              )
              as Map;
      final monaco = (lock['assets'] as List).cast<Map>().singleWhere(
        (asset) => asset['id'] == 'monaco-editor',
      );
      expect(monaco['path'], 'apps/web/web/vendor/monaco');
      expect(monaco['file_count'], 105);
      expect(monaco['license_sha256'], hasLength(64));
      expect(monaco['notices_sha256'], hasLength(64));

      final manifestSchema =
          jsonDecode(
                File(
                  '../../evidence/et13/manifest.schema.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(manifestSchema['additionalProperties'], isFalse);
      expect(
        manifestSchema['required'],
        containsAll([
          'input_provenance_sha256',
          'capture_surface',
          'device_evidence',
          'case_count',
          'surface_case_counts',
          'cases',
        ]),
      );
      final laneContract = (manifestSchema['allOf'] as List).first as Map;
      final visualCases =
          ((laneContract['then'] as Map)['properties'] as Map)['cases'] as Map;
      final a11yCases =
          ((laneContract['else'] as Map)['properties'] as Map)['cases'] as Map;
      expect(visualCases['minItems'], 96);
      expect(visualCases['maxItems'], 96);
      expect(a11yCases['minItems'], 24);
      expect(a11yCases['maxItems'], 24);
      final a11yResultCase =
          ((manifestSchema[r'$defs'] as Map)['a11yCase'] as Map);
      final a11yResultProperties = a11yResultCase['properties'] as Map;
      expect(
        (a11yResultProperties['case_id'] as Map)['pattern'],
        r'^[a-z0-9-]+--a11y--w(?:320--light|1240--dark)--text200$',
      );
      expect(a11yResultProperties['critical_violations'], {'const': 0});
      expect(a11yResultProperties['serious_violations'], {'const': 0});
    },
  );

  test('fixture mode suppresses AdSense before any network request', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains("has('fixture')"));
    expect(index, contains('document.createElement(\'script\')'));
    expect(index, isNot(contains('<script async src="https://pagead2')));
  });

  test('renderer mutation is rejected, not accepted as a new pin', () {
    final temp = Directory.systemTemp.createTempSync('et13-renderer-mutation-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final renderer =
        jsonDecode(
              File('../../evidence/et13/renderer.lock.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    renderer['chromium_revision'] = '1188';
    final mutated = File('${temp.path}/renderer.lock.json')
      ..writeAsStringSync(jsonEncode(renderer));

    expect(
      () => et13.validateRendererLock(mutated.path),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'generated case mutation is rejected instead of becoming a baseline',
    () {
      final temp = Directory.systemTemp.createTempSync('et13-case-mutation-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final visual = jsonDecode(visualFile.readAsStringSync()) as Map;
      ((visual['cases'] as List).first as Map)['case_id'] =
          'web-today-available--visual--w320--dark';
      final visualMutation = File('${temp.path}/visual.json')
        ..writeAsStringSync(jsonEncode(visual));
      final a11yCopy = File('${temp.path}/a11y.json');
      a11yFile.copySync(a11yCopy.path);

      expect(
        () => et13.validateGeneratedCatalogs(
          visualPath: visualMutation.path,
          a11yPath: a11yCopy.path,
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('sealed visual manifest rejects empty or truncated result rows', () {
    final fixture = _visualResultFixture();
    addTearDown(() => fixture.root.deleteSync(recursive: true));
    final full = _fullManifest('visual', fixture.document);
    _writeManifest(fixture.manifest, full);
    expect(
      () => _validateManifestDocument('visual', fixture.manifest),
      returnsNormally,
    );

    full['cases'] = <Object?>[];
    _writeManifest(fixture.manifest, full);
    expect(
      () => _validateManifestDocument('visual', fixture.manifest),
      throwsA(isA<FormatException>()),
    );
  });

  test('sealed a11y manifest rejects a serious violation row', () {
    final fixture = _a11yResultFixture();
    addTearDown(() => fixture.root.deleteSync(recursive: true));
    final full = _fullManifest('a11y', fixture.document);
    _writeManifest(fixture.manifest, full);
    expect(
      () => _validateManifestDocument('a11y', fixture.manifest),
      returnsNormally,
    );

    ((full['cases'] as List).first as Map)['serious_violations'] = 1;
    _writeManifest(fixture.manifest, full);
    expect(
      () => _validateManifestDocument('a11y', fixture.manifest),
      throwsA(isA<FormatException>()),
    );
  });

  test('packaged provenance recomputes its canonical self-digest', () {
    final temp = Directory.systemTemp.createTempSync('et13-provenance-doc-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final catalogPath = '../../evidence/et13/catalog.v1.json';
    final casePath = '../../evidence/et13/generated/a11y-cases.v1.json';
    final assetsPath = '../../evidence/et13/assets.lock.json';
    final rendererPath = '../../evidence/et13/renderer.lock.json';
    final catalog = jsonDecode(File(catalogPath).readAsStringSync()) as Map;
    final renderer = jsonDecode(File(rendererPath).readAsStringSync()) as Map;
    final unsigned = <String, Object?>{
      'schema_version': 'leva.et13.input-provenance.v1',
      'kind': 'a11y',
      'source_sha': '1234567890abcdef1234567890abcdef12345678',
      'catalog_sha256': _fileSha(catalogPath),
      'case_catalog_sha256': _fileSha(casePath),
      'projection_contract_sha256': catalog['projection_contract_sha256'],
      'assets_lock_sha256': _fileSha(assetsPath),
      'renderer_lock_sha256': _fileSha(rendererPath),
      'renderer_image_digest': renderer['manifest_digest'],
      'build_marker_sha256':
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    };
    final document = <String, Object?>{
      ...unsigned,
      'input_provenance_sha256': _canonicalSha(unsigned),
    };
    final file = File('${temp.path}/provenance.v1.json');
    _writeManifest(file, document);
    expect(
      () => et13.validateInputProvenanceDocument(
        kind: 'a11y',
        provenancePath: file.path,
        catalogPath: catalogPath,
        generatedCatalogPath: casePath,
        assetsLockPath: assetsPath,
        rendererLockPath: rendererPath,
      ),
      returnsNormally,
    );

    document['input_provenance_sha256'] =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    _writeManifest(file, document);
    expect(
      () => et13.validateInputProvenanceDocument(
        kind: 'a11y',
        provenancePath: file.path,
        catalogPath: catalogPath,
        generatedCatalogPath: casePath,
        assetsLockPath: assetsPath,
        rendererLockPath: rendererPath,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('visual result set reconciles all 96 ordered files exactly', () {
    final fixture = _visualResultFixture();
    addTearDown(() => fixture.root.deleteSync(recursive: true));
    expect(
      () => et13.validateResultArtifacts(
        kind: 'visual',
        manifestPath: fixture.manifest.path,
        artifactRoot: fixture.root.path,
        generatedCatalogPath:
            '../../evidence/et13/generated/visual-cases.v1.json',
      ),
      returnsNormally,
    );

    final cases = (fixture.document['cases'] as List).cast<Map>();
    cases.first['status'] = 'failed';
    _writeManifest(fixture.manifest, fixture.document);
    expect(
      () => et13.validateResultArtifacts(
        kind: 'visual',
        manifestPath: fixture.manifest.path,
        artifactRoot: fixture.root.path,
        generatedCatalogPath:
            '../../evidence/et13/generated/visual-cases.v1.json',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('visual result rejects reordered IDs and unmanifested files', () {
    final fixture = _visualResultFixture();
    addTearDown(() => fixture.root.deleteSync(recursive: true));
    final cases = (fixture.document['cases'] as List).cast<Map>();
    final first = cases[0];
    cases[0] = cases[1];
    cases[1] = first;
    _writeManifest(fixture.manifest, fixture.document);
    expect(
      () => et13.validateResultArtifacts(
        kind: 'visual',
        manifestPath: fixture.manifest.path,
        artifactRoot: fixture.root.path,
        generatedCatalogPath:
            '../../evidence/et13/generated/visual-cases.v1.json',
      ),
      throwsA(isA<FormatException>()),
    );

    cases[1] = cases[0];
    cases[0] = first;
    _writeManifest(fixture.manifest, fixture.document);
    final extra = File.fromUri(
      fixture.root.uri.resolve('visual/web/extra.png'),
    );
    extra.parent.createSync(recursive: true);
    extra.writeAsBytesSync(_pngHeader(320, 900));
    expect(
      () => et13.validateResultArtifacts(
        kind: 'visual',
        manifestPath: fixture.manifest.path,
        artifactRoot: fixture.root.path,
        generatedCatalogPath:
            '../../evidence/et13/generated/visual-cases.v1.json',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('visual result authenticates PNG IHDR axes, not just file hash', () {
    final fixture = _visualResultFixture();
    addTearDown(() => fixture.root.deleteSync(recursive: true));
    final first = (fixture.document['cases'] as List).first as Map;
    final artifact = File.fromUri(
      fixture.root.uri.resolve(first['artifact_path']! as String),
    );
    final wrongAxes = _pngHeader(321, 900);
    artifact.writeAsBytesSync(wrongAxes);
    first['sha256'] = sha256.convert(wrongAxes).toString();
    first['bytes'] = wrongAxes.length;
    _writeManifest(fixture.manifest, fixture.document);
    expect(
      () => et13.validateResultArtifacts(
        kind: 'visual',
        manifestPath: fixture.manifest.path,
        artifactRoot: fixture.root.path,
        generatedCatalogPath:
            '../../evidence/et13/generated/visual-cases.v1.json',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('a11y result reconciles counters with exact detail bytes', () {
    final fixture = _a11yResultFixture();
    addTearDown(() => fixture.root.deleteSync(recursive: true));
    expect(
      () => et13.validateResultArtifacts(
        kind: 'a11y',
        manifestPath: fixture.manifest.path,
        artifactRoot: fixture.root.path,
        generatedCatalogPath:
            '../../evidence/et13/generated/a11y-cases.v1.json',
      ),
      returnsNormally,
    );

    final first = (fixture.document['cases'] as List).first as Map;
    final artifact = File.fromUri(
      fixture.root.uri.resolve(first['artifact_path']! as String),
    );
    final detail = jsonDecode(artifact.readAsStringSync()) as Map;
    detail['critical_violations'] = 1;
    artifact.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(detail)}\n',
    );
    first['critical_violations'] = 1;
    first['sha256'] = sha256.convert(artifact.readAsBytesSync()).toString();
    first['bytes'] = artifact.lengthSync();
    _writeManifest(fixture.manifest, fixture.document);
    expect(
      () => et13.validateResultArtifacts(
        kind: 'a11y',
        manifestPath: fixture.manifest.path,
        artifactRoot: fixture.root.path,
        generatedCatalogPath:
            '../../evidence/et13/generated/a11y-cases.v1.json',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('pinned CI runs the strict ET13 validator', () {
    final workflow = File(
      '../../.github/workflows/et13-evidence.yml',
    ).readAsStringSync();
    expect(
      workflow,
      contains('actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803'),
    );
    expect(
      workflow,
      contains(
        'subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2',
      ),
    );
    expect(workflow, contains('dart run tools/et13_evidence.dart validate'));
    expect(workflow, isNot(contains('update-snapshot')));
  });

  test('arbitrary or all-zero source SHA cannot produce provenance', () async {
    final result = await Process.run(
      'dart',
      [
        'run',
        'tools/et13_evidence.dart',
        'provenance',
        '--kind=visual',
        '--source-sha=0000000000000000000000000000000000000000',
      ],
      workingDirectory: '../..',
      runInShell: true,
    );
    expect(result.exitCode, isNonZero);
  });
}
