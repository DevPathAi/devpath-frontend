import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _catalogVersion = 'leva.et13.catalog.v1';
const _visualVersion = 'leva.et13.visual-cases.v1';
const _a11yVersion = 'leva.et13.a11y-cases.v1';
const _projectionContractVersion = 'leva.et13.projection-contract.v1';
const _projectionContractSha256 =
    'c66d08b6425628a06b27d07e08d648cfb3568d9db7c8d8aca2371172ccf4bde3';
const _pendingReview = 'pending_external_review';
const _approved = 'approved';
const _diagnostic = 'diagnostic';
const _releaseReady = 'release_ready';
const _captureSurface = 'flutter_web_release_projection';
const _externalAccessibilityStatus = 'not_satisfied';
const _a11yStandard = 'WCAG 2.2 AA';
const _workspaceLockSha =
    '0314570cb0955aab626fa61191b419c06b6f2cb06736827b48a1e88f252a34e4';
const _rendererImage =
    'mcr.microsoft.com/playwright:v1.55.0-noble@sha256:'
    'ffc33305f7b4b04057ae4a0caa70aad4fde87454fb403a1a22e7f931707dfcf9';
const _rendererManifestDigest =
    'sha256:ffc33305f7b4b04057ae4a0caa70aad4fde87454fb403a1a22e7f931707dfcf9';
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
const _visualSurfaceCounts = <String, int>{
  'web': 48,
  'admin': 16,
  'mobile': 16,
  'dp_design': 16,
};
const _a11ySurfaceCounts = <String, int>{
  'web': 12,
  'admin': 4,
  'mobile': 4,
  'dp_design': 4,
};
const _commonEvidenceKeys = <String>[
  'candidate_spec_sha256',
  'status',
  'producer_run_id',
  'producer_run_attempt',
  'repository',
  'source_sha',
  'case_catalog_sha256',
  'case_catalog_version',
  'case_catalog_schema_version',
  'projection_contract_sha256',
  'fixture_ids',
  'case_count',
  'passed_case_count',
  'failed_case_count',
  'surface_case_counts',
  'capture_surface',
  'device_evidence',
  'input_provenance_sha256',
  'input_provenance_file_sha256',
  'result_manifest_sha256',
  'evidence_mode',
];
const _visualEvidenceKeys = <String>[
  ..._commonEvidenceKeys,
  'baseline_status',
  'baseline_set_sha256',
  'baseline_approval_sha256',
  'pixel_diff_percent',
];
const _a11yEvidenceKeys = <String>[
  ..._commonEvidenceKeys,
  'standard',
  'critical_violations',
  'serious_violations',
];
const _commonManifestKeys = <String>[
  'schema_version',
  'evidence_mode',
  'case_catalog_version',
  'case_catalog_schema_version',
  'fixture_ids',
  'source_sha',
  'catalog_sha256',
  'case_catalog_sha256',
  'projection_contract_sha256',
  'assets_lock_sha256',
  'renderer_lock_sha256',
  'input_provenance_sha256',
  'renderer_image',
  'renderer_image_digest',
  'capture_network',
  'unexpected_request_policy',
  'capture_surface',
  'device_evidence',
  'external_accessibility_status',
];
const _visualManifestKeys = <String>[
  ..._commonManifestKeys,
  'baseline_status',
  'baseline_set_sha256',
  'baseline_approval_sha256',
  'case_count',
  'surface_case_counts',
  'cases',
];
const _a11yManifestKeys = <String>[
  ..._commonManifestKeys,
  'case_count',
  'surface_case_counts',
  'cases',
];
const _visualResultCaseKeys = <String>[
  'case_id',
  'status',
  'artifact_path',
  'sha256',
  'bytes',
];
const _a11yResultCaseKeys = <String>[
  ..._visualResultCaseKeys,
  'standard',
  'critical_violations',
  'serious_violations',
  'other_violations',
  'passes',
  'incomplete',
];
const _baselineAuthenticationKeys = <String>[
  'release_id',
  'repository',
  'workflow_path',
  'workflow_sha256',
  'run_id',
  'run_attempt',
  'head_sha',
  'artifact_id',
  'artifact_name',
  'artifact_archive_sha256',
  'approval_document_sha256',
  'approval_environment',
  'approval_environment_id',
  'approved_by_id',
  'approved_by',
  'approval_effective_at',
];
const _expectedAssets = <Map<String, Object?>>[
  {
    'id': 'pretendard-400',
    'kind': 'font',
    'path': 'packages/dp_design/fonts/Pretendard-Regular.otf',
    'bytes': 1574352,
    'sha256':
        '3ffbacde6ab8411f1d2db54bb9b1f0b3ee2a738932033722cf0388c06aed1c93',
    'source': 'https://github.com/orioncactus/pretendard',
    'weight': 400,
  },
  {
    'id': 'pretendard-500',
    'kind': 'font',
    'path': 'packages/dp_design/fonts/Pretendard-Medium.otf',
    'bytes': 1584068,
    'sha256':
        'd39e50e4bb52b4993b6a4eeb821a171254745bd824446af01e1f616b89fface0',
    'source': 'https://github.com/orioncactus/pretendard',
    'weight': 500,
  },
  {
    'id': 'pretendard-600',
    'kind': 'font',
    'path': 'packages/dp_design/fonts/Pretendard-SemiBold.otf',
    'bytes': 1583704,
    'sha256':
        'c89bc43027dc7cde5726e96223376f8eec09302b2fc1f8147fd5b57cfc376118',
    'source': 'https://github.com/orioncactus/pretendard',
    'weight': 600,
  },
  {
    'id': 'pretendard-700',
    'kind': 'font',
    'path': 'packages/dp_design/fonts/Pretendard-Bold.otf',
    'bytes': 1576660,
    'sha256':
        '2e91915fab54df71cc9598ebf608b2bdb54c6fe3c066ac61dff0bc44fca71cc7',
    'source': 'https://github.com/orioncactus/pretendard',
    'weight': 700,
  },
  {
    'id': 'd2coding',
    'kind': 'font',
    'path': 'packages/dp_design/fonts/D2Coding.ttf',
    'bytes': 4185844,
    'sha256':
        '8b1b23e5de4dff652fb0b938528150d2f531edfda281d3944618b655711aba84',
    'source': 'https://github.com/naver/d2codingfont',
    'weight': 400,
  },
  {
    'id': 'material-symbols-rounded',
    'kind': 'package_font',
    'path': 'lib/fonts/MaterialSymbolsRounded.ttf',
    'bytes': 14808068,
    'sha256':
        '24e0438c39c69593a11c80d80dcba68b3057933f90d642d2de1ec888c7873c78',
    'source':
        'https://pub.dev/packages/material_symbols_icons/versions/4.2928.1',
    'package': 'material_symbols_icons',
    'package_version': '4.2928.1',
    'package_sha256':
        '10a74aaa9e566c92f8aa14809d2dd78156fb93743348ebffec0345c38eb35706',
  },
  {
    'id': 'material-icons',
    'kind': 'flutter_sdk_font',
    'path': 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    'bytes': 1645184,
    'sha256':
        'd9865b671a09d683d13a863089d8825e0f61a37696ce5d7d448bc8023aa62453',
    'source':
        'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.44.1-stable.zip',
    'flutter_version': '3.44.1',
    'flutter_revision': '924134a44c189315be2148659913dda1671cbe99',
  },
  {
    'id': 'monaco-editor',
    'kind': 'vendored_tree',
    'path': 'apps/web/web/vendor/monaco',
    'bytes': 14007996,
    'sha256':
        'f60e2ed76e47203a4d01e71ac6fd09a760473552e8f544d97bc2a5b922aba289',
    'source':
        'https://registry.npmjs.org/monaco-editor/-/monaco-editor-0.52.2.tgz',
    'version': '0.52.2',
    'archive_sha256':
        'c280cdcf0b0c13d1a2bf01af958d4387ed06d7f6c918401d00c4adcae1bc72b6',
    'archive_integrity':
        'sha512-GEQWEZmfkOGLdd3XK8ryrfWz3AIP8YymVXiPHEdewrUq7mh0qrKrfHLNCXcbB6sTnMLnOZ3ztSiKcciFUkIJwQ==',
    'file_count': 105,
    'license_path': 'LICENSE',
    'license_bytes': 1098,
    'license_sha256':
        '33e4ff1a06ef62ba21788ea162564ee8165269a24a9ce6ef301837447eab0ac6',
    'notices_path': 'ThirdPartyNotices.txt',
    'notices_bytes': 63064,
    'notices_sha256':
        '790537262fc78a764e121e6b92b959bcd3f5c310b47d9d9b9e92e17fe0af5336',
  },
];

const _builtFontPaths = <String, String>{
  'pretendard-400': 'assets/packages/dp_design/fonts/Pretendard-Regular.otf',
  'pretendard-500': 'assets/packages/dp_design/fonts/Pretendard-Medium.otf',
  'pretendard-600': 'assets/packages/dp_design/fonts/Pretendard-SemiBold.otf',
  'pretendard-700': 'assets/packages/dp_design/fonts/Pretendard-Bold.otf',
  'd2coding': 'assets/packages/dp_design/fonts/D2Coding.ttf',
  'material-symbols-rounded':
      'assets/packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf',
  'material-icons': 'assets/fonts/MaterialIcons-Regular.otf',
};

Never _fail(String message) => throw FormatException(message);

void _exactKeys(Map<String, Object?> value, List<String> keys, String path) {
  final actual = value.keys.toList(growable: false);
  if (!_listEquals(actual, keys)) {
    _fail('$path keys must be exactly $keys in order; found $actual');
  }
}

bool _listEquals(List<Object?> left, List<Object?> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map) _fail('$path must be an object');
  return value.cast<String, Object?>();
}

List<Object?> _array(Object? value, String path) {
  if (value is! List) _fail('$path must be an array');
  return value.cast<Object?>();
}

String _string(Object? value, String path) {
  if (value is! String || value.isEmpty) _fail('$path must be a string');
  return value;
}

int _integer(Object? value, String path) {
  if (value is! int) _fail('$path must be an integer');
  return value;
}

String _sha256String(Object? value, String path) {
  final result = _string(value, path);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(result)) {
    _fail('$path must be 64 lowercase hexadecimal characters');
  }
  return result;
}

String _githubLogin(Object? value, String path) {
  final result = _string(value, path);
  if (!RegExp(
    r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$',
  ).hasMatch(result)) {
    _fail('$path must be an exact GitHub user login');
  }
  return result;
}

String _utcTimestamp(Object? value, String path) {
  final result = _string(value, path);
  if (!RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$',
      ).hasMatch(result) ||
      DateTime.tryParse(result)?.isUtc != true) {
    _fail('$path must be an ISO-8601 UTC Z timestamp');
  }
  return result;
}

void _exactValue(Object? actual, Object? expected, String path) {
  final equal =
      actual is List || actual is Map || expected is List || expected is Map
      ? jsonEncode(actual) == jsonEncode(expected)
      : actual == expected;
  if (!equal) _fail('$path must be $expected; found $actual');
}

Map<String, Object?> _readObject(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('missing required file: $path');
  return _object(jsonDecode(file.readAsStringSync()), path);
}

String _rawSha(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

String _pretty(Object value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

void _writePretty(String path, Object value) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(_pretty(value));
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonical(value[key]),
    };
  }
  if (value is List) return value.map(_canonical).toList(growable: false);
  return value;
}

String _canonicalSha(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

Map<String, Object?> validateCatalog({
  String path = 'evidence/et13/catalog.v1.json',
}) {
  final catalog = _readObject(path);
  _exactKeys(catalog, const [
    'schema_version',
    'fixtures',
    'projection_contract_version',
    'projection_matrix',
    'projection_contract_sha256',
    'visual_matrix',
    'a11y_matrix',
    'baseline_status',
  ], r'$catalog');
  if (catalog['schema_version'] != _catalogVersion) {
    _fail('catalog schema_version must be $_catalogVersion');
  }
  _exactValue(
    catalog['projection_contract_version'],
    _projectionContractVersion,
    r'$catalog.projection_contract_version',
  );
  if (catalog['baseline_status'] != _pendingReview) {
    _fail('baseline status must remain $_pendingReview');
  }

  final fixtures = _array(catalog['fixtures'], r'$catalog.fixtures');
  if (fixtures.length != 12) _fail('catalog must contain exactly 12 fixtures');
  final owners = <String, int>{};
  final distributions = <String, int>{};
  final actualIds = <String>[];
  for (var index = 0; index < fixtures.length; index++) {
    final fixture = _object(fixtures[index], r'$catalog.fixtures[$index]');
    _exactKeys(fixture, const [
      'id',
      'owner',
      'distribution',
      'route',
      'ready_semantics_label',
      'surface_label',
      'capture_scope',
      'source_widget',
      'substitutions',
    ], r'$catalog.fixtures[$index]');
    final id = _string(fixture['id'], 'fixture[$index].id');
    final owner = _string(fixture['owner'], 'fixture[$index].owner');
    final distribution = _string(
      fixture['distribution'],
      'fixture[$index].distribution',
    );
    actualIds.add(id);
    owners.update(owner, (count) => count + 1, ifAbsent: () => 1);
    distributions.update(distribution, (count) => count + 1, ifAbsent: () => 1);
    if (fixture['route'] != '/?fixture=$id' ||
        fixture['ready_semantics_label'] != 'ET13_READY:$id' ||
        fixture['surface_label'] != id) {
      _fail('fixture $id route/readiness/surface identity drifted');
    }
    final captureScope = _string(
      fixture['capture_scope'],
      'fixture[$index].capture_scope',
    );
    if (!const {
      'full_route',
      'body_projection',
      'component_projection',
    }.contains(captureScope)) {
      _fail('fixture $id capture scope is invalid');
    }
    _string(fixture['source_widget'], 'fixture[$index].source_widget');
    final substitutions = _array(
      fixture['substitutions'],
      'fixture[$index].substitutions',
    );
    if (substitutions.isEmpty ||
        substitutions.any((value) => value is! String || value.isEmpty)) {
      _fail('fixture $id must declare explicit substitutions');
    }
    if (owner == 'dp_design' && distribution != 'web') {
      _fail('dp_design fixtures must use the web production distribution');
    }
    if (owner != 'dp_design' && distribution != owner) {
      _fail('fixture $id must render from its owning production distribution');
    }
  }
  if (!_listEquals(actualIds, _fixtureIds)) {
    _fail('fixture order drifted: $actualIds');
  }
  const expectedOwners = <String, int>{
    'web': 6,
    'admin': 2,
    'mobile': 2,
    'dp_design': 2,
  };
  const expectedDistributions = <String, int>{
    'web': 8,
    'admin': 2,
    'mobile': 2,
  };
  if (!_mapEquals(owners, expectedOwners) ||
      !_mapEquals(distributions, expectedDistributions)) {
    _fail('fixture owner/distribution counts drifted');
  }

  final expectedProjectionMatrix = <Map<String, Object?>>[
    for (final raw in fixtures)
      {
        'fixture_id': _object(raw, 'fixture')['id'],
        'capture_scope': _object(raw, 'fixture')['capture_scope'],
        'source_widget': _object(raw, 'fixture')['source_widget'],
        'substitutions': _object(raw, 'fixture')['substitutions'],
      },
  ];
  final projectionMatrix = _array(
    catalog['projection_matrix'],
    r'$catalog.projection_matrix',
  );
  if (jsonEncode(projectionMatrix) != jsonEncode(expectedProjectionMatrix)) {
    _fail('projection matrix must exactly mirror the ordered fixture contract');
  }
  final projectionSha = _canonicalSha(projectionMatrix);
  _exactValue(
    catalog['projection_contract_sha256'],
    _projectionContractSha256,
    r'$catalog.projection_contract_sha256',
  );
  _exactValue(
    projectionSha,
    _projectionContractSha256,
    r'$catalog.canonicalProjectionMatrixSha256',
  );

  final visual = _object(catalog['visual_matrix'], r'$catalog.visual_matrix');
  _exactKeys(visual, const [
    'widths',
    'themes',
    'height',
    'device_pixel_ratio',
    'text_scale_percent',
    'locale',
    'timezone',
    'reduced_motion',
  ], r'$catalog.visual_matrix');
  if (!_listEquals(_array(visual['widths'], 'visual.widths'), const [
        320,
        600,
        840,
        1240,
      ]) ||
      !_listEquals(_array(visual['themes'], 'visual.themes'), const [
        'light',
        'dark',
      ]) ||
      visual['height'] != 900 ||
      visual['device_pixel_ratio'] != 1 ||
      visual['text_scale_percent'] != 100 ||
      visual['locale'] != 'ko-KR' ||
      visual['timezone'] != 'UTC' ||
      visual['reduced_motion'] != true) {
    _fail('visual matrix must remain the approved deterministic profile');
  }

  final a11y = _array(catalog['a11y_matrix'], r'$catalog.a11y_matrix');
  if (a11y.length != 2) _fail('a11y matrix must contain exactly two cases');
  const expectedA11y = <Map<String, Object>>[
    {'width': 320, 'theme': 'light', 'text_scale_percent': 200},
    {'width': 1240, 'theme': 'dark', 'text_scale_percent': 200},
  ];
  for (var index = 0; index < a11y.length; index++) {
    final entry = _object(a11y[index], 'a11y[$index]');
    _exactKeys(entry, const [
      'width',
      'theme',
      'text_scale_percent',
    ], 'a11y[$index]');
    if (!_mapEquals(entry, expectedA11y[index])) {
      _fail('a11y matrix entry $index drifted');
    }
  }
  return catalog;
}

bool _mapEquals(Map<Object?, Object?> left, Map<Object?, Object?> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

Map<String, Object?> _case({
  required Map<String, Object?> fixture,
  required String kind,
  required int width,
  required String theme,
  required int textScale,
}) {
  final id = fixture['id']! as String;
  final suffix = kind == 'visual'
      ? '$id--visual--w$width--$theme'
      : '$id--a11y--w$width--$theme--text200';
  final extension = kind == 'visual' ? 'png' : 'json';
  return <String, Object?>{
    'case_id': suffix,
    'fixture_id': id,
    'owner': fixture['owner'],
    'distribution': fixture['distribution'],
    'route': fixture['route'],
    'ready_semantics_label': fixture['ready_semantics_label'],
    'surface_label': fixture['surface_label'],
    'capture_scope': fixture['capture_scope'],
    'source_widget': fixture['source_widget'],
    'substitutions': fixture['substitutions'],
    'width': width,
    'height': 900,
    'device_pixel_ratio': 1,
    'theme': theme,
    'text_scale_percent': textScale,
    'locale': 'ko-KR',
    'timezone': 'UTC',
    'reduced_motion': true,
    'artifact_path': '$kind/${fixture['owner']}/$suffix.$extension',
  };
}

({Map<String, Object?> visual, Map<String, Object?> a11y}) generateCatalogs() {
  final catalog = validateCatalog();
  final catalogSha = _rawSha('evidence/et13/catalog.v1.json');
  final fixtures = _array(
    catalog['fixtures'],
    'fixtures',
  ).map((fixture) => _object(fixture, 'fixture')).toList(growable: false);
  final visualCases = <Map<String, Object?>>[];
  for (final fixture in fixtures) {
    for (final width in const [320, 600, 840, 1240]) {
      for (final theme in const ['light', 'dark']) {
        visualCases.add(
          _case(
            fixture: fixture,
            kind: 'visual',
            width: width,
            theme: theme,
            textScale: 100,
          ),
        );
      }
    }
  }
  final a11yCases = <Map<String, Object?>>[];
  for (final fixture in fixtures) {
    for (final entry in const [
      (width: 320, theme: 'light'),
      (width: 1240, theme: 'dark'),
    ]) {
      a11yCases.add(
        _case(
          fixture: fixture,
          kind: 'a11y',
          width: entry.width,
          theme: entry.theme,
          textScale: 200,
        ),
      );
    }
  }
  final visual = <String, Object?>{
    'schema_version': _visualVersion,
    'case_catalog_version': _catalogVersion,
    'catalog_sha256': catalogSha,
    'projection_contract_sha256': catalog['projection_contract_sha256'],
    'projection_matrix': catalog['projection_matrix'],
    'fixture_ids': _fixtureIds,
    'case_count': 96,
    'surface_case_counts': _visualSurfaceCounts,
    'cases': visualCases,
  };
  final a11y = <String, Object?>{
    'schema_version': _a11yVersion,
    'case_catalog_version': _catalogVersion,
    'catalog_sha256': catalogSha,
    'projection_contract_sha256': catalog['projection_contract_sha256'],
    'projection_matrix': catalog['projection_matrix'],
    'fixture_ids': _fixtureIds,
    'case_count': 24,
    'surface_case_counts': _a11ySurfaceCounts,
    'cases': a11yCases,
  };
  return (visual: visual, a11y: a11y);
}

void writeGeneratedCatalogs() {
  final generated = generateCatalogs();
  Directory('evidence/et13/generated').createSync(recursive: true);
  File(
    'evidence/et13/generated/visual-cases.v1.json',
  ).writeAsStringSync(_pretty(generated.visual));
  File(
    'evidence/et13/generated/a11y-cases.v1.json',
  ).writeAsStringSync(_pretty(generated.a11y));
}

void validateGeneratedCatalogs({
  String visualPath = 'evidence/et13/generated/visual-cases.v1.json',
  String a11yPath = 'evidence/et13/generated/a11y-cases.v1.json',
}) {
  final generated = generateCatalogs();
  final expected = <String, String>{
    visualPath: _pretty(generated.visual),
    a11yPath: _pretty(generated.a11y),
  };
  for (final entry in expected.entries) {
    final file = File(entry.key);
    if (!file.existsSync() || file.readAsStringSync() != entry.value) {
      _fail('${entry.key} is missing or not canonical; run generate');
    }
  }
}

void validateCanonicalLineEndings() {
  final paths = Directory('evidence/et13')
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .map((file) => file.path);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    if (bytes.contains(13)) {
      _fail('$path must use canonical LF bytes (CR found)');
    }
    jsonDecode(utf8.decode(bytes));
  }
  final lockBytes = File('pubspec.lock').readAsBytesSync();
  final normalizedLock = <int>[];
  for (var index = 0; index < lockBytes.length; index++) {
    if (lockBytes[index] == 13 &&
        index + 1 < lockBytes.length &&
        lockBytes[index + 1] == 10) {
      continue;
    }
    if (lockBytes[index] == 13) _fail('pubspec.lock contains a bare CR byte');
    normalizedLock.add(lockBytes[index]);
  }
  if (sha256.convert(normalizedLock).toString() != _workspaceLockSha) {
    _fail('workspace lock hash drifted from the approved LF renderer input');
  }
  final attribute = _gitOutput(['check-attr', 'eol', '--', 'pubspec.lock']);
  if (attribute != 'pubspec.lock: eol: lf') {
    _fail('pubspec.lock must be pinned as text eol=lf in .gitattributes');
  }
}

void validateContractDocuments() {
  const schemas = <String, String>{
    'evidence/et13/catalog.schema.json':
        'https://leva.ai.kr/schemas/et13/catalog.v1.json',
    'evidence/et13/generated-cases.schema.json':
        'https://leva.ai.kr/schemas/et13/generated-cases.v1.json',
    'evidence/et13/manifest.schema.json':
        'https://leva.ai.kr/schemas/et13/manifest.v1.json',
    'evidence/et13/evidence.schema.json':
        'https://leva.ai.kr/schemas/et13/evidence.v1.json',
    'evidence/et13/baseline-approval.schema.json':
        'https://leva.ai.kr/schemas/et13/baseline-approval.v1.json',
  };
  for (final entry in schemas.entries) {
    final schema = _readObject(entry.key);
    _exactValue(
      schema[r'$schema'],
      'https://json-schema.org/draft/2020-12/schema',
      '${entry.key}.\$schema',
    );
    _exactValue(schema[r'$id'], entry.value, '${entry.key}.\$id');
    _exactValue(schema['type'], 'object', '${entry.key}.type');
    _exactValue(
      schema['additionalProperties'],
      false,
      '${entry.key}.additionalProperties',
    );
  }

  final bundle = _readObject('evidence/et13/release-bundle.v1.json');
  _exactKeys(bundle, const [
    'schema_version',
    'workflow_path',
    'capture_surface',
    'device_evidence',
    'lanes',
  ], r'$releaseBundle');
  for (final entry in const <String, Object?>{
    'schema_version': 'leva.et13.release-bundle.v1',
    'workflow_path': '.github/workflows/et13-evidence.yml',
    'capture_surface': _captureSurface,
    'device_evidence': false,
  }.entries) {
    _exactValue(bundle[entry.key], entry.value, 'releaseBundle.${entry.key}');
  }
  final lanes = _array(bundle['lanes'], 'releaseBundle.lanes');
  if (lanes.length != 2) _fail('release bundle must declare two ordered lanes');
  for (var index = 0; index < lanes.length; index++) {
    final visual = index == 0;
    final kind = visual ? 'visual' : 'a11y';
    final lane = _object(lanes[index], 'releaseBundle.lanes[$index]');
    _exactKeys(lane, const [
      'kind',
      'artifact_name_template',
      'files',
      'generated_schema_version',
      'provenance_schema_version',
      'manifest_schema_version',
      'evidence_keys',
      'manifest_keys',
      'result_case_keys',
    ], 'releaseBundle.lanes[$index]');
    final label = visual ? 'visual' : 'automated-a11y';
    final manifest = visual ? 'visual' : 'a11y';
    for (final entry in <String, Object?>{
      'kind': kind,
      'artifact_name_template':
          '<release_id>-frontend-$label-run-<run_id>-attempt-<run_attempt>',
      'files': [
        'evidence.json',
        'evidence/et13/generated/$kind-cases.v1.json',
        'artifacts/et13/provenance.v1.json',
        'artifacts/et13/$manifest-manifest.v1.json',
      ],
      'generated_schema_version': visual ? _visualVersion : _a11yVersion,
      'provenance_schema_version': 'leva.et13.input-provenance.v1',
      'manifest_schema_version': visual
          ? 'leva.et13.visual-manifest.v1'
          : 'leva.et13.a11y-manifest.v1',
      'evidence_keys': visual ? _visualEvidenceKeys : _a11yEvidenceKeys,
      'manifest_keys': visual ? _visualManifestKeys : _a11yManifestKeys,
      'result_case_keys': visual ? _visualResultCaseKeys : _a11yResultCaseKeys,
    }.entries) {
      _exactValue(lane[entry.key], entry.value, '$kind.${entry.key}');
    }
  }
}

Map<String, Object?> validateRendererLock([
  String path = 'evidence/et13/renderer.lock.json',
]) {
  final renderer = _readObject(path);
  _exactKeys(renderer, const [
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
  ], r'$renderer');
  const expected = <String, Object?>{
    'schema_version': 'leva.et13.renderer-lock.v1',
    'image': _rendererImage,
    'platform': 'linux/amd64',
    'index_digest':
        'sha256:b27e719ecbfef153e13fd24e8341736733bf2658b229677eb21ff57ff5d7fb29',
    'manifest_digest': _rendererManifestDigest,
    'playwright_version': '1.55.0',
    'chromium_revision': '1187',
    'chromium_version': '140.0.7339.16',
    'locale': 'ko-KR',
    'timezone': 'UTC',
    'device_pixel_ratio': 1,
    'reduced_motion': true,
    'capture_network': 'none',
    'unexpected_request_policy': 'fail',
    'capture_surface': _captureSurface,
    'device_evidence': false,
    'external_accessibility_status': _externalAccessibilityStatus,
  };
  if (!_mapEquals(renderer, expected)) _fail('renderer lock values drifted');
  final image = renderer['image']! as String;
  final manifest = renderer['manifest_digest']! as String;
  if (!image.endsWith('@$manifest')) {
    _fail('renderer image must be bound to its linux/amd64 manifest digest');
  }
  return renderer;
}

String _treeSha(Directory directory) {
  if (!directory.existsSync())
    _fail('missing vendored tree: ${directory.path}');
  final files =
      directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  final root = directory.absolute.path;
  final lines = files.map((file) {
    final relative = file.absolute.path
        .substring(root.length + 1)
        .replaceAll('\\', '/');
    return '$relative ${sha256.convert(file.readAsBytesSync())}';
  });
  return sha256.convert(utf8.encode('${lines.join('\n')}\n')).toString();
}

Directory _packageRoot(String package) {
  final config = _readObject('.dart_tool/package_config.json');
  final packages = _array(config['packages'], 'package_config.packages');
  for (final raw in packages) {
    final entry = _object(raw, 'package');
    if (entry['name'] != package) continue;
    final rootUri = _string(entry['rootUri'], '$package.rootUri');
    return Directory.fromUri(
      File('.dart_tool/package_config.json').absolute.uri.resolve(rootUri),
    );
  }
  _fail('package $package is not resolved');
}

File _resolvedAssetFile(Map<String, Object?> asset) {
  final kind = asset['kind'];
  final path = _string(asset['path'], 'asset.path');
  if (kind == 'package_font') {
    return File.fromUri(
      _packageRoot(
        _string(asset['package'], 'asset.package'),
      ).uri.resolve(path),
    );
  }
  if (kind == 'flutter_sdk_font') {
    final flutterPackage = _packageRoot('flutter');
    final flutterRoot = flutterPackage.parent.parent;
    return File.fromUri(flutterRoot.uri.resolve(path));
  }
  return File(path);
}

void validateAssets() {
  final lock = _readObject('evidence/et13/assets.lock.json');
  _exactKeys(lock, const ['schema_version', 'assets'], r'$assets');
  if (lock['schema_version'] != 'leva.et13.assets-lock.v1') {
    _fail('asset lock schema version drifted');
  }
  final assets = _array(lock['assets'], 'assets');
  if (assets.length != _expectedAssets.length) {
    _fail('asset lock must contain exactly ${_expectedAssets.length} assets');
  }
  final actualIds = <String>[];
  for (var index = 0; index < assets.length; index++) {
    final raw = assets[index];
    final asset = _object(raw, 'asset');
    final id = _string(asset['id'], 'asset.id');
    actualIds.add(id);
    if (!_mapEquals(asset, _expectedAssets[index])) {
      _fail('asset $id metadata drifted from its exact approved pin');
    }
    final path = _string(asset['path'], '$id.path');
    final expectedBytes = _integer(asset['bytes'], '$id.bytes');
    final expectedSha = _sha256String(asset['sha256'], '$id.sha256');
    if (asset['kind'] == 'vendored_tree') {
      final directory = Directory(path);
      final files = directory
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      final bytes = files.fold<int>(
        0,
        (total, file) => total + file.lengthSync(),
      );
      if (files.length != asset['file_count'] ||
          bytes != expectedBytes ||
          _treeSha(directory) != expectedSha) {
        _fail('$id vendored tree does not match its exact lock');
      }
      for (final prefix in ['license', 'notices']) {
        final pinnedFile = File.fromUri(
          directory.uri.resolve(
            _string(asset['${prefix}_path'], '$id.${prefix}_path'),
          ),
        );
        if (!pinnedFile.existsSync() ||
            pinnedFile.lengthSync() != asset['${prefix}_bytes'] ||
            sha256.convert(pinnedFile.readAsBytesSync()).toString() !=
                asset['${prefix}_sha256']) {
          _fail('$id $prefix bytes drifted from the npm archive');
        }
      }
    } else {
      final file = _resolvedAssetFile(asset);
      if (!file.existsSync() ||
          file.lengthSync() != expectedBytes ||
          sha256.convert(file.readAsBytesSync()).toString() != expectedSha) {
        _fail('$id does not match its exact asset lock: ${file.path}');
      }
    }
  }
  final expectedIds = _expectedAssets
      .map((asset) => asset['id'])
      .toList(growable: false);
  if (!_listEquals(actualIds, expectedIds)) {
    _fail('asset order drifted: $actualIds');
  }
}

String _gitOutput(List<String> arguments, {String? workingDirectory}) {
  final result = Process.runSync(
    'git',
    arguments,
    runInShell: false,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    _fail('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

void _validateCleanHead(String sourceSha, {String? workingDirectory}) {
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sourceSha) ||
      sourceSha == '0000000000000000000000000000000000000000') {
    _fail('source SHA must be a non-zero 40-character lowercase git SHA');
  }
  final head = _gitOutput([
    'rev-parse',
    '--verify',
    'HEAD',
  ], workingDirectory: workingDirectory);
  if (sourceSha != head) {
    _fail('source SHA $sourceSha does not match clean git HEAD $head');
  }
  final trackedStatus = _gitOutput([
    'status',
    '--porcelain=v1',
    '--untracked-files=all',
  ], workingDirectory: workingDirectory);
  if (trackedStatus.isNotEmpty) {
    _fail('source tree must be clean before provenance is computed');
  }
}

void validateSourceTreeClean(String sourceSha, {String? workingDirectory}) =>
    _validateCleanHead(sourceSha, workingDirectory: workingDirectory);

List<Map<String, Object?>> _lockedBuiltFontMarker() {
  return <Map<String, Object?>>[
    for (final path in _builtFontPaths.entries)
      () {
        final expected = _expectedAssets.singleWhere(
          (asset) => asset['id'] == path.key,
        );
        return <String, Object?>{
          'id': path.key,
          'artifact_path': path.value,
          'sha256': expected['sha256'],
          'bytes': expected['bytes'],
        };
      }(),
  ];
}

List<Map<String, Object?>> _builtFontMarker(String artifactRoot) {
  final root = Directory(artifactRoot);
  final locked = _lockedBuiltFontMarker();
  for (final font in locked) {
    final relative = _string(font['artifact_path'], 'font.artifact_path');
    final file = File.fromUri(root.uri.resolve(relative));
    if (!file.existsSync() ||
        file.lengthSync() != font['bytes'] ||
        _rawSha(file.path) != font['sha256']) {
      _fail(
        '$artifactRoot/$relative is absent, tree-shaken, or differs '
        'from the exact ET13 font lock',
      );
    }
  }
  return locked;
}

/// Validates the immutable build-marker document without reopening producer
/// build trees. Approval jobs use this boundary because their authenticated
/// raw-review artifact intentionally contains only review evidence bytes.
Map<String, Object?> validateBuildMarkerDocument({
  required String sourceSha,
  required String buildMarkerPath,
}) {
  final marker = _readObject(buildMarkerPath);
  _exactKeys(marker, const [
    'schema_version',
    'source_sha',
    'capture_surface',
    'device_evidence',
    'distributions',
  ], r'$buildMarker');
  _exactValue(
    marker['schema_version'],
    'leva.et13.build-marker.v1',
    'buildMarker.schema_version',
  );
  _exactValue(marker['source_sha'], sourceSha, 'buildMarker.source_sha');
  _exactValue(
    marker['capture_surface'],
    _captureSurface,
    'buildMarker.capture_surface',
  );
  _exactValue(marker['device_evidence'], false, 'buildMarker.device_evidence');
  final distributions = _array(
    marker['distributions'],
    'buildMarker.distributions',
  );
  if (distributions.length != 3) {
    _fail('build marker must bind exactly three Flutter Web distributions');
  }
  const expected = <String, String>{
    'web': 'apps/web/lib/et13_evidence_main.dart',
    'admin': 'apps/admin/lib/et13_evidence_main.dart',
    'mobile': 'apps/mobile/lib/et13_evidence_main.dart',
  };
  for (var index = 0; index < distributions.length; index++) {
    final distribution = _object(
      distributions[index],
      'buildMarker.distributions[$index]',
    );
    _exactKeys(distribution, const [
      'id',
      'entrypoint',
      'artifact_root',
      'main_dart_js_sha256',
      'font_assets',
    ], 'buildMarker.distributions[$index]');
    final id = _string(distribution['id'], 'distribution.id');
    if (id != expected.keys.elementAt(index) ||
        distribution['entrypoint'] != expected[id]) {
      _fail('build marker distribution order/entrypoint drifted at $index');
    }
    final artifactRoot = _string(
      distribution['artifact_root'],
      '$id.artifact_root',
    );
    if (artifactRoot.isEmpty || artifactRoot.contains('\\')) {
      _fail('$id build marker artifact root must be a canonical path');
    }
    _sha256String(
      distribution['main_dart_js_sha256'],
      '$id.main_dart_js_sha256',
    );
    if (jsonEncode(distribution['font_assets']) !=
        jsonEncode(_lockedBuiltFontMarker())) {
      _fail('$id build marker font assets drifted from the exact lock');
    }
  }
  return marker;
}

void validateSourceIdentity(String sourceSha, String buildMarkerPath) {
  _validateCleanHead(sourceSha);
  final marker = validateBuildMarkerDocument(
    sourceSha: sourceSha,
    buildMarkerPath: buildMarkerPath,
  );
  for (final raw in _array(
    marker['distributions'],
    'buildMarker.distributions',
  )) {
    final distribution = _object(raw, 'buildMarker.distribution');
    final id = _string(distribution['id'], 'distribution.id');
    final artifactRoot = _string(
      distribution['artifact_root'],
      '$id.artifact_root',
    );
    final main = File.fromUri(
      Directory(artifactRoot).uri.resolve('main.dart.js'),
    );
    final expectedMainSha = _sha256String(
      distribution['main_dart_js_sha256'],
      '$id.main_dart_js_sha256',
    );
    if (!main.existsSync() || _rawSha(main.path) != expectedMainSha) {
      _fail('$id build marker does not match its main.dart.js bytes');
    }
    _builtFontMarker(artifactRoot);
  }
}

Map<String, Object?> writeBuildMarker({
  required String sourceSha,
  required String outputPath,
  required String webRoot,
  required String adminRoot,
  required String mobileRoot,
}) {
  _validateCleanHead(sourceSha);
  final roots = <String, String>{
    'web': webRoot,
    'admin': adminRoot,
    'mobile': mobileRoot,
  };
  const entrypoints = <String, String>{
    'web': 'apps/web/lib/et13_evidence_main.dart',
    'admin': 'apps/admin/lib/et13_evidence_main.dart',
    'mobile': 'apps/mobile/lib/et13_evidence_main.dart',
  };
  final distributions = <Map<String, Object?>>[];
  for (final id in entrypoints.keys) {
    final root = roots[id]!;
    final main = File.fromUri(Directory(root).uri.resolve('main.dart.js'));
    if (!main.existsSync()) _fail('$id release build is missing main.dart.js');
    distributions.add({
      'id': id,
      'entrypoint': entrypoints[id],
      'artifact_root': root.replaceAll('\\', '/'),
      'main_dart_js_sha256': _rawSha(main.path),
      'font_assets': _builtFontMarker(root),
    });
  }
  final marker = <String, Object?>{
    'schema_version': 'leva.et13.build-marker.v1',
    'source_sha': sourceSha,
    'capture_surface': _captureSurface,
    'device_evidence': false,
    'distributions': distributions,
  };
  _writePretty(outputPath, marker);
  validateSourceIdentity(sourceSha, outputPath);
  return marker;
}

Map<String, Object?>? _validateBaselineAuthentication(
  Object? value, {
  required String sourceSha,
}) {
  if (value == null) return null;
  final authentication = _object(value, 'baselineAuthentication');
  _exactKeys(
    authentication,
    _baselineAuthenticationKeys,
    r'$baselineAuthentication',
  );
  final releaseId = _string(
    authentication['release_id'],
    'baselineAuthentication.release_id',
  );
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(releaseId)) {
    _fail('baseline authentication release ID is invalid');
  }
  _exactValue(
    authentication['repository'],
    'DevPathAi/devpath-frontend',
    'baselineAuthentication.repository',
  );
  _exactValue(
    authentication['workflow_path'],
    '.github/workflows/et13-baseline-approval.yml',
    'baselineAuthentication.workflow_path',
  );
  for (final key in [
    'workflow_sha256',
    'artifact_archive_sha256',
    'approval_document_sha256',
  ]) {
    _sha256String(authentication[key], 'baselineAuthentication.$key');
  }
  for (final key in [
    'run_id',
    'run_attempt',
    'artifact_id',
    'approval_environment_id',
    'approved_by_id',
  ]) {
    if (_integer(authentication[key], 'baselineAuthentication.$key') < 1) {
      _fail('baselineAuthentication.$key must be positive');
    }
  }
  _exactValue(
    authentication['head_sha'],
    sourceSha,
    'baselineAuthentication.head_sha',
  );
  final runId = _integer(
    authentication['run_id'],
    'baselineAuthentication.run_id',
  );
  final runAttempt = _integer(
    authentication['run_attempt'],
    'baselineAuthentication.run_attempt',
  );
  _exactValue(
    authentication['artifact_name'],
    '$releaseId-frontend-visual-approved-baseline-run-$runId-attempt-'
        '$runAttempt',
    'baselineAuthentication.artifact_name',
  );
  _exactValue(
    authentication['approval_environment'],
    'et13-baseline-approval',
    'baselineAuthentication.approval_environment',
  );
  _githubLogin(
    authentication['approved_by'],
    'baselineAuthentication.approved_by',
  );
  _utcTimestamp(
    authentication['approval_effective_at'],
    'baselineAuthentication.approval_effective_at',
  );
  return authentication;
}

Map<String, Object?>? _validateProvenanceMode(
  Map<String, Object?> provenance,
  String mode,
) {
  final authentication = provenance['baseline_authentication'];
  if (mode == _releaseReady && authentication == null) {
    _fail('release-ready provenance requires baseline authentication');
  }
  if (mode == _diagnostic && authentication != null) {
    _fail('diagnostic provenance must not carry baseline authentication');
  }
  return authentication == null
      ? null
      : _object(authentication, 'provenance.baseline_authentication');
}

Map<String, Object?> inputProvenance(
  String kind,
  String sourceSha,
  String buildMarkerPath, {
  Map<String, Object?>? baselineAuthentication,
}) {
  validateSourceIdentity(sourceSha, buildMarkerPath);
  validateGeneratedCatalogs();
  validateAssets();
  final renderer = validateRendererLock();
  final casePath = kind == 'visual'
      ? 'evidence/et13/generated/visual-cases.v1.json'
      : kind == 'a11y'
      ? 'evidence/et13/generated/a11y-cases.v1.json'
      : _fail('kind must be visual or a11y');
  final inputs = <String, Object?>{
    'schema_version': 'leva.et13.input-provenance.v1',
    'kind': kind,
    'source_sha': sourceSha,
    'catalog_sha256': _rawSha('evidence/et13/catalog.v1.json'),
    'case_catalog_sha256': _rawSha(casePath),
    'projection_contract_sha256':
        validateCatalog()['projection_contract_sha256'],
    'assets_lock_sha256': _rawSha('evidence/et13/assets.lock.json'),
    'renderer_lock_sha256': _rawSha('evidence/et13/renderer.lock.json'),
    'renderer_image_digest': renderer['manifest_digest'],
    'build_marker_sha256': _rawSha(buildMarkerPath),
    'baseline_authentication': _validateBaselineAuthentication(
      baselineAuthentication,
      sourceSha: sourceSha,
    ),
  };
  return <String, Object?>{
    ...inputs,
    'input_provenance_sha256': _canonicalSha(inputs),
  };
}

Map<String, Object?> writeInputProvenance({
  required String kind,
  required String sourceSha,
  required String buildMarkerPath,
  required String outputPath,
  Map<String, Object?>? baselineAuthentication,
}) {
  final provenance = inputProvenance(
    kind,
    sourceSha,
    buildMarkerPath,
    baselineAuthentication: baselineAuthentication,
  );
  _writePretty(outputPath, provenance);
  return provenance;
}

void _validateA11yResult(
  Map<String, Object?> result,
  Map<String, Object?> manifestCase,
) {
  _exactKeys(result, const [
    'schema_version',
    'case_id',
    'standard',
    'critical_violations',
    'serious_violations',
    'other_violations',
    'passes',
    'incomplete',
    'violations',
  ], r'$a11yResult');
  _exactValue(
    result['schema_version'],
    'leva.et13.a11y-result.v1',
    'a11yResult.schema_version',
  );
  for (final key in [
    'case_id',
    'standard',
    'critical_violations',
    'serious_violations',
    'other_violations',
    'passes',
    'incomplete',
  ]) {
    _exactValue(result[key], manifestCase[key], 'a11yResult.$key');
  }
  if (result['standard'] != 'WCAG 2.2 AA') {
    _fail('a11y result standard must be WCAG 2.2 AA');
  }
  final counts = <String, int>{
    'critical': 0,
    'serious': 0,
    'moderate': 0,
    'minor': 0,
  };
  final violations = _array(result['violations'], 'a11yResult.violations');
  final ruleIds = <String>{};
  for (var index = 0; index < violations.length; index++) {
    final violation = _object(violations[index], 'violations[$index]');
    _exactKeys(violation, const [
      'id',
      'impact',
      'description',
      'node_count',
    ], 'violations[$index]');
    final id = _string(violation['id'], 'violations[$index].id');
    if (!ruleIds.add(id)) _fail('duplicate a11y rule ID: $id');
    final impact = _string(violation['impact'], 'violations[$index].impact');
    if (!counts.containsKey(impact)) {
      _fail('unsupported a11y impact: $impact');
    }
    final nodeCount = _integer(
      violation['node_count'],
      'violations[$index].node_count',
    );
    if (nodeCount < 1) _fail('a11y violation node_count must be positive');
    _string(violation['description'], 'violations[$index].description');
    counts[impact] = counts[impact]! + 1;
  }
  _exactValue(
    result['critical_violations'],
    counts['critical'],
    'a11yResult.critical_violations',
  );
  _exactValue(
    result['serious_violations'],
    counts['serious'],
    'a11yResult.serious_violations',
  );
  _exactValue(
    result['other_violations'],
    counts['moderate']! + counts['minor']!,
    'a11yResult.other_violations',
  );
  for (final key in ['passes', 'incomplete']) {
    if (_integer(result[key], 'a11yResult.$key') < 0) {
      _fail('a11yResult.$key must be non-negative');
    }
  }
  if (counts['critical'] != 0 || counts['serious'] != 0) {
    _fail('critical or serious automated a11y violations fail the run');
  }
}

String _mode(Object? value, String path) {
  final mode = _string(value, path);
  if (mode != _diagnostic && mode != _releaseReady) {
    _fail('$path must be $_diagnostic or $_releaseReady');
  }
  return mode;
}

Map<String, Object?> validateInputProvenanceFile({
  required String kind,
  required String sourceSha,
  required String buildMarkerPath,
  required String provenancePath,
}) {
  final file = File(provenancePath);
  if (!file.existsSync()) {
    _fail('input provenance must exist');
  }
  final actual = _readObject(provenancePath);
  final expected = inputProvenance(
    kind,
    sourceSha,
    buildMarkerPath,
    baselineAuthentication: actual['baseline_authentication'] == null
        ? null
        : _object(
            actual['baseline_authentication'],
            'provenance.baseline_authentication',
          ),
  );
  if (!file.existsSync() || file.readAsStringSync() != _pretty(expected)) {
    _fail('input provenance must be the exact canonical producer output');
  }
  return expected;
}

/// Validates packaged provenance without needing the producer's build tree.
/// The self-digest excludes only [input_provenance_sha256], matching the
/// canonical producer calculation.
Map<String, Object?> validateInputProvenanceDocument({
  required String kind,
  required String provenancePath,
  String catalogPath = 'evidence/et13/catalog.v1.json',
  String? generatedCatalogPath,
  String assetsLockPath = 'evidence/et13/assets.lock.json',
  String rendererLockPath = 'evidence/et13/renderer.lock.json',
}) {
  final visual = kind == 'visual';
  if (!visual && kind != 'a11y') _fail('kind must be visual or a11y');
  final provenance = _readObject(provenancePath);
  _exactKeys(provenance, const [
    'schema_version',
    'kind',
    'source_sha',
    'catalog_sha256',
    'case_catalog_sha256',
    'projection_contract_sha256',
    'assets_lock_sha256',
    'renderer_lock_sha256',
    'renderer_image_digest',
    'build_marker_sha256',
    'baseline_authentication',
    'input_provenance_sha256',
  ], r'$provenance');
  final casePath =
      generatedCatalogPath ??
      'evidence/et13/generated/${visual ? 'visual' : 'a11y'}-cases.v1.json';
  final catalog = validateCatalog(path: catalogPath);
  final renderer = validateRendererLock(rendererLockPath);
  final sourceSha = _string(provenance['source_sha'], 'provenance.source_sha');
  if (!RegExp(r'^(?!0{40}$)[0-9a-f]{40}$').hasMatch(sourceSha)) {
    _fail('provenance source SHA must be a non-zero lowercase git SHA');
  }
  for (final entry in <String, Object?>{
    'schema_version': 'leva.et13.input-provenance.v1',
    'kind': kind,
    'catalog_sha256': _rawSha(catalogPath),
    'case_catalog_sha256': _rawSha(casePath),
    'projection_contract_sha256': catalog['projection_contract_sha256'],
    'assets_lock_sha256': _rawSha(assetsLockPath),
    'renderer_lock_sha256': _rawSha(rendererLockPath),
    'renderer_image_digest': renderer['manifest_digest'],
  }.entries) {
    _exactValue(provenance[entry.key], entry.value, 'provenance.${entry.key}');
  }
  _sha256String(
    provenance['build_marker_sha256'],
    'provenance.build_marker_sha256',
  );
  _validateBaselineAuthentication(
    provenance['baseline_authentication'],
    sourceSha: sourceSha,
  );
  final unsigned = <String, Object?>{
    for (final entry in provenance.entries)
      if (entry.key != 'input_provenance_sha256') entry.key: entry.value,
  };
  _exactValue(
    provenance['input_provenance_sha256'],
    _canonicalSha(unsigned),
    'provenance.input_provenance_sha256',
  );
  return provenance;
}

String visualArtifactSetSha(
  String artifactRoot, {
  String generatedCatalogPath = 'evidence/et13/generated/visual-cases.v1.json',
}) {
  final generated = _readObject(generatedCatalogPath);
  final cases = _array(generated['cases'], 'visualCases.cases');
  final root = Directory(artifactRoot).absolute;
  final rootPrefix = '${root.path}${Platform.pathSeparator}';
  final expectedPaths = <String>{};
  final lines = <String>[];
  for (var index = 0; index < cases.length; index++) {
    final entry = _object(cases[index], 'visualCases[$index]');
    final relative = _string(entry['artifact_path'], 'visualCases.path');
    final file = File.fromUri(root.uri.resolve(relative)).absolute;
    if (!file.path.startsWith(rootPrefix) || !file.existsSync()) {
      _fail('visual baseline is missing $relative or escapes its root');
    }
    expectedPaths.add(relative);
    lines.add('$relative ${_rawSha(file.path)}');
  }
  final visualRoot = Directory.fromUri(root.uri.resolve('visual/'));
  final actualPaths = visualRoot.existsSync()
      ? visualRoot
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .map(
              (file) => file.absolute.path
                  .substring(rootPrefix.length)
                  .replaceAll('\\', '/'),
            )
            .toSet()
      : <String>{};
  if (!_setEquals(expectedPaths, actualPaths)) {
    _fail('visual baseline set has missing or unexpected files');
  }
  return sha256.convert(utf8.encode('${lines.join('\n')}\n')).toString();
}

Map<String, Object?> validateBaselineApproval({
  required String approvalPath,
  required String baselineRoot,
  required String reviewCandidatePath,
  bool requireExactBundle = false,
  String catalogPath = 'evidence/et13/catalog.v1.json',
  String generatedCatalogPath = 'evidence/et13/generated/visual-cases.v1.json',
  String approvalWorkflowPath = '.github/workflows/et13-baseline-approval.yml',
  String rawReviewWorkflowPath = '.github/workflows/et13-evidence.yml',
}) {
  final approval = _readObject(approvalPath);
  _exactKeys(approval, const [
    'schema_version',
    'status',
    'source_sha',
    'catalog_sha256',
    'case_catalog_sha256',
    'review_candidate_sha256',
    'fixture_ids',
    'case_count',
    'candidate_set_sha256',
    'approval_repository',
    'approval_workflow_path',
    'approval_workflow_sha256',
    'approval_run_id',
    'approval_run_attempt',
    'approval_head_sha',
    'approval_environment',
    'approval_environment_id',
    'approved_by_id',
    'approved_by',
    'approval_effective_at',
    'raw_review_workflow_sha256',
    'raw_review_run_id',
    'raw_review_run_attempt',
    'raw_review_head_sha',
    'raw_review_artifact_id',
    'raw_review_artifact_name',
    'raw_review_artifact_digest',
  ], r'$baselineApproval');
  _exactValue(
    approval['schema_version'],
    'leva.et13.baseline-approval.v1',
    'baselineApproval.schema_version',
  );
  _exactValue(approval['status'], _approved, 'baselineApproval.status');
  final sourceSha = _string(
    approval['source_sha'],
    'baselineApproval.source_sha',
  );
  if (!RegExp(r'^(?!0{40}$)[0-9a-f]{40}$').hasMatch(sourceSha)) {
    _fail('baseline approval source SHA is invalid');
  }
  _exactValue(
    approval['catalog_sha256'],
    _rawSha(catalogPath),
    'baselineApproval.catalog_sha256',
  );
  _exactValue(
    approval['case_catalog_sha256'],
    _rawSha(generatedCatalogPath),
    'baselineApproval.case_catalog_sha256',
  );
  _exactValue(
    approval['review_candidate_sha256'],
    _rawSha(reviewCandidatePath),
    'baselineApproval.review_candidate_sha256',
  );
  final reviewCandidate = _readObject(reviewCandidatePath);
  _exactKeys(reviewCandidate, const [
    'schema_version',
    'kind',
    'evidence_mode',
    'producer_run_id',
    'producer_run_attempt',
    'repository',
    'source_sha',
    'case_catalog_sha256',
    'case_catalog_version',
    'case_catalog_schema_version',
    'projection_contract_sha256',
    'fixture_ids',
    'case_count',
    'surface_case_counts',
    'capture_surface',
    'device_evidence',
    'input_provenance_sha256',
    'input_provenance_file_sha256',
    'baseline_status',
    'baseline_set_sha256',
    'baseline_approval_sha256',
  ], r'$reviewCandidate');
  final visualGenerated = _readObject(generatedCatalogPath);
  for (final entry in <String, Object?>{
    'schema_version': 'leva.et13.candidate-spec.v1',
    'kind': 'visual',
    'evidence_mode': _diagnostic,
    'source_sha': sourceSha,
    'case_catalog_sha256': _rawSha(generatedCatalogPath),
    'case_catalog_version': _catalogVersion,
    'case_catalog_schema_version': _visualVersion,
    'projection_contract_sha256': validateCatalog(
      path: catalogPath,
    )['projection_contract_sha256'],
    'fixture_ids': _fixtureIds,
    'case_count': 96,
    'surface_case_counts': visualGenerated['surface_case_counts'],
    'capture_surface': _captureSurface,
    'device_evidence': false,
    'baseline_status': _pendingReview,
    'baseline_set_sha256': null,
    'baseline_approval_sha256': null,
  }.entries) {
    _exactValue(
      reviewCandidate[entry.key],
      entry.value,
      'reviewCandidate.${entry.key}',
    );
  }
  _repository(
    _string(reviewCandidate['repository'], 'reviewCandidate.repository'),
  );
  _exactValue(
    reviewCandidate['repository'],
    'DevPathAi/devpath-frontend',
    'reviewCandidate.repository',
  );
  for (final key in ['producer_run_id', 'producer_run_attempt']) {
    if (_integer(reviewCandidate[key], 'reviewCandidate.$key') < 1) {
      _fail('reviewCandidate.$key must be positive');
    }
  }
  for (final key in [
    'input_provenance_sha256',
    'input_provenance_file_sha256',
  ]) {
    _sha256String(reviewCandidate[key], 'reviewCandidate.$key');
  }
  if (!_listEquals(
    _array(approval['fixture_ids'], 'baselineApproval.fixture_ids'),
    _fixtureIds,
  )) {
    _fail('baseline approval fixture order drifted');
  }
  _exactValue(approval['case_count'], 96, 'baselineApproval.case_count');
  _exactValue(
    approval['approval_repository'],
    'DevPathAi/devpath-frontend',
    'baselineApproval.approval_repository',
  );
  _exactValue(
    approval['approval_workflow_path'],
    '.github/workflows/et13-baseline-approval.yml',
    'baselineApproval.approval_workflow_path',
  );
  _exactValue(
    approval['approval_workflow_sha256'],
    _rawSha(approvalWorkflowPath),
    'baselineApproval.approval_workflow_sha256',
  );
  _exactValue(
    approval['raw_review_workflow_sha256'],
    _rawSha(rawReviewWorkflowPath),
    'baselineApproval.raw_review_workflow_sha256',
  );
  for (final key in [
    'approval_run_id',
    'approval_run_attempt',
    'approval_environment_id',
    'approved_by_id',
    'raw_review_run_id',
    'raw_review_run_attempt',
    'raw_review_artifact_id',
  ]) {
    if (_integer(approval[key], 'baselineApproval.$key') < 1) {
      _fail('baselineApproval.$key must be positive');
    }
  }
  _exactValue(
    approval['approval_head_sha'],
    sourceSha,
    'baselineApproval.approval_head_sha',
  );
  _exactValue(
    approval['raw_review_head_sha'],
    sourceSha,
    'baselineApproval.raw_review_head_sha',
  );
  _exactValue(
    approval['approval_environment'],
    'et13-baseline-approval',
    'baselineApproval.approval_environment',
  );
  _githubLogin(approval['approved_by'], 'baselineApproval.approved_by');
  _utcTimestamp(
    approval['approval_effective_at'],
    'baselineApproval.approval_effective_at',
  );
  final rawReviewRunId = _integer(
    approval['raw_review_run_id'],
    'baselineApproval.raw_review_run_id',
  );
  final rawReviewRunAttempt = _integer(
    approval['raw_review_run_attempt'],
    'baselineApproval.raw_review_run_attempt',
  );
  _exactValue(
    approval['raw_review_artifact_name'],
    'et13-unsealed-raw-review-run-$rawReviewRunId-attempt-'
        '$rawReviewRunAttempt',
    'baselineApproval.raw_review_artifact_name',
  );
  final rawReviewDigest = _string(
    approval['raw_review_artifact_digest'],
    'baselineApproval.raw_review_artifact_digest',
  );
  if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(rawReviewDigest)) {
    _fail('baseline approval raw review artifact digest is invalid');
  }
  _exactValue(
    approval['candidate_set_sha256'],
    visualArtifactSetSha(
      baselineRoot,
      generatedCatalogPath: generatedCatalogPath,
    ),
    'baselineApproval.candidate_set_sha256',
  );
  if (requireExactBundle) {
    _validateExactApprovedBaselineBundle(
      baselineRoot: baselineRoot,
      approvalPath: approvalPath,
      reviewCandidatePath: reviewCandidatePath,
      generatedCatalogPath: generatedCatalogPath,
    );
  }
  return approval;
}

Map<String, Object?> buildBaselineAuthentication({
  required String releaseId,
  required String sourceSha,
  required String baselineRoot,
  required String approvalPath,
  required int runId,
  required int runAttempt,
  required int artifactId,
  required String artifactName,
  required String artifactArchiveSha256,
  required String workflowSha256,
  String catalogPath = 'evidence/et13/catalog.v1.json',
  String generatedCatalogPath = 'evidence/et13/generated/visual-cases.v1.json',
  String approvalWorkflowPath = '.github/workflows/et13-baseline-approval.yml',
  String rawReviewWorkflowPath = '.github/workflows/et13-evidence.yml',
}) {
  final approval = validateBaselineApproval(
    approvalPath: approvalPath,
    baselineRoot: baselineRoot,
    reviewCandidatePath: File.fromUri(
      Directory(baselineRoot).absolute.uri.resolve('review-candidate.v1.json'),
    ).path,
    requireExactBundle: true,
    catalogPath: catalogPath,
    generatedCatalogPath: generatedCatalogPath,
    approvalWorkflowPath: approvalWorkflowPath,
    rawReviewWorkflowPath: rawReviewWorkflowPath,
  );
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(releaseId)) {
    _fail('baseline authentication release ID is invalid');
  }
  for (final entry in <String, Object?>{
    'source_sha': sourceSha,
    'approval_repository': 'DevPathAi/devpath-frontend',
    'approval_workflow_path': '.github/workflows/et13-baseline-approval.yml',
    'approval_workflow_sha256': workflowSha256,
    'approval_run_id': runId,
    'approval_run_attempt': runAttempt,
    'approval_head_sha': sourceSha,
  }.entries) {
    _exactValue(
      approval[entry.key],
      entry.value,
      'baselineApproval.${entry.key}',
    );
  }
  if (runId < 1 || runAttempt < 1 || artifactId < 1) {
    _fail('baseline authentication coordinates must be positive');
  }
  _sha256String(workflowSha256, 'baselineAuthentication.workflow_sha256');
  _sha256String(
    artifactArchiveSha256,
    'baselineAuthentication.artifact_archive_sha256',
  );
  final expectedName =
      '$releaseId-frontend-visual-approved-baseline-run-$runId-attempt-'
      '$runAttempt';
  _exactValue(
    artifactName,
    expectedName,
    'baselineAuthentication.artifact_name',
  );
  final authentication = <String, Object?>{
    'release_id': releaseId,
    'repository': 'DevPathAi/devpath-frontend',
    'workflow_path': '.github/workflows/et13-baseline-approval.yml',
    'workflow_sha256': workflowSha256,
    'run_id': runId,
    'run_attempt': runAttempt,
    'head_sha': sourceSha,
    'artifact_id': artifactId,
    'artifact_name': artifactName,
    'artifact_archive_sha256': artifactArchiveSha256,
    'approval_document_sha256': _rawSha(approvalPath),
    'approval_environment': approval['approval_environment'],
    'approval_environment_id': approval['approval_environment_id'],
    'approved_by_id': approval['approved_by_id'],
    'approved_by': approval['approved_by'],
    'approval_effective_at': approval['approval_effective_at'],
  };
  return _validateBaselineAuthentication(authentication, sourceSha: sourceSha)!;
}

void _validateExactApprovedBaselineBundle({
  required String baselineRoot,
  required String approvalPath,
  required String reviewCandidatePath,
  required String generatedCatalogPath,
}) {
  final root = Directory(baselineRoot).absolute;
  final approval = File(approvalPath).absolute;
  final reviewCandidate = File(reviewCandidatePath).absolute;
  final expectedApproval = File.fromUri(
    root.uri.resolve('baseline-approval.v1.json'),
  ).absolute;
  final expectedReview = File.fromUri(
    root.uri.resolve('review-candidate.v1.json'),
  ).absolute;
  if (approval.path != expectedApproval.path ||
      reviewCandidate.path != expectedReview.path) {
    _fail('approved baseline metadata must use the two canonical root paths');
  }
  final generated = _readObject(generatedCatalogPath);
  final expectedFiles = <String>{
    'baseline-approval.v1.json',
    'review-candidate.v1.json',
    for (final raw in _array(generated['cases'], 'visualCases.cases'))
      _string(_object(raw, 'visualCase')['artifact_path'], 'visualCase.path'),
  };
  final expectedDirectories = <String>{};
  for (final file in expectedFiles) {
    var parent = File(file).parent.path.replaceAll('\\', '/');
    while (parent != '.' && parent.isNotEmpty) {
      expectedDirectories.add(parent);
      parent = File(parent).parent.path.replaceAll('\\', '/');
    }
  }
  final actualFiles = <String>{};
  final actualDirectories = <String>{};
  final prefix = '${root.path}${Platform.pathSeparator}';
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    final relative = entity.absolute.path
        .substring(prefix.length)
        .replaceAll('\\', '/');
    final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      _fail('approved baseline bundle may not contain symbolic links');
    }
    if (type == FileSystemEntityType.file) actualFiles.add(relative);
    if (type == FileSystemEntityType.directory) {
      actualDirectories.add(relative);
    }
  }
  if (!_setEquals(expectedFiles, actualFiles) ||
      !_setEquals(expectedDirectories, actualDirectories)) {
    _fail(
      'approved baseline bundle must contain exactly 96 PNGs and two metadata files',
    );
  }
}

({String? setSha, String? approvalSha}) _baselineDigests({
  required bool visual,
  required String mode,
  required String sourceSha,
  String? baselineRoot,
  String? approvalPath,
}) {
  if (!visual) return (setSha: null, approvalSha: null);
  if (mode == _diagnostic) {
    if (baselineRoot != null || approvalPath != null) {
      _fail('diagnostic mode must not consume approved baseline inputs');
    }
    return (setSha: null, approvalSha: null);
  }
  if (baselineRoot == null || approvalPath == null) {
    _fail('release-ready visual evidence requires baseline and approval');
  }
  final approval = validateBaselineApproval(
    approvalPath: approvalPath,
    baselineRoot: baselineRoot,
    reviewCandidatePath: File.fromUri(
      Directory(baselineRoot).absolute.uri.resolve('review-candidate.v1.json'),
    ).path,
    requireExactBundle: true,
  );
  _exactValue(approval['source_sha'], sourceSha, 'baselineApproval.source_sha');
  return (
    setSha: visualArtifactSetSha(baselineRoot),
    approvalSha: _rawSha(approvalPath),
  );
}

/// Validates the complete ordered bytes-on-disk result set independently of
/// checkout/provenance validation. [validateResultManifest] always calls this
/// after authenticating the producer inputs; exposing the byte validator also
/// lets contract tests exercise fail-closed mutations without weakening the
/// production entry point.
void validateResultArtifacts({
  required String kind,
  required String manifestPath,
  required String artifactRoot,
  String? generatedCatalogPath,
  String? baselineRoot,
}) {
  final visual = kind == 'visual';
  if (!visual && kind != 'a11y') _fail('kind must be visual or a11y');
  final manifest = _readObject(manifestPath);
  final mode = _mode(manifest['evidence_mode'], 'manifest.evidence_mode');
  if (mode == _releaseReady && visual && baselineRoot == null) {
    _fail('release-ready visual artifact validation requires a baseline root');
  }
  final casePath =
      generatedCatalogPath ??
      (visual
          ? 'evidence/et13/generated/visual-cases.v1.json'
          : 'evidence/et13/generated/a11y-cases.v1.json');
  final generated = _readObject(casePath);
  final expectedCases = _array(generated['cases'], 'generated.cases');
  final expectedCount = visual ? 96 : 24;
  final expectedSurfaceCounts = visual
      ? _visualSurfaceCounts
      : _a11ySurfaceCounts;
  _exactValue(manifest['case_count'], expectedCount, 'manifest.case_count');
  if (!_mapEquals(
    _object(manifest['surface_case_counts'], 'manifest.surface_case_counts'),
    expectedSurfaceCounts,
  )) {
    _fail('manifest surface case counts drifted');
  }
  final cases = _array(manifest['cases'], 'manifest.cases');
  if (cases.length != expectedCount || cases.length != expectedCases.length) {
    _fail('manifest must contain exactly $expectedCount ordered cases');
  }
  final root = Directory(artifactRoot).absolute;
  final rootPrefix = '${root.path}${Platform.pathSeparator}';
  final ids = <String>{};
  final paths = <String>{};
  for (var index = 0; index < cases.length; index++) {
    final result = _object(cases[index], 'manifest.cases[$index]');
    final expected = _object(expectedCases[index], 'generated.cases[$index]');
    _exactKeys(
      result,
      visual ? _visualResultCaseKeys : _a11yResultCaseKeys,
      'manifest.cases[$index]',
    );
    _exactValue(result['status'], 'passed', 'case[$index].status');
    final id = _string(result['case_id'], 'case[$index].case_id');
    final relativePath = _string(
      result['artifact_path'],
      'case[$index].artifact_path',
    );
    if (!ids.add(id) || !paths.add(relativePath)) {
      _fail('manifest case IDs and artifact paths must be unique');
    }
    _exactValue(id, expected['case_id'], 'case[$index].case_id');
    _exactValue(
      relativePath,
      expected['artifact_path'],
      'case[$index].artifact_path',
    );
    if (visual != relativePath.endsWith('.png')) {
      _fail('case[$index] artifact extension does not match $kind');
    }
    final artifact = File.fromUri(root.uri.resolve(relativePath)).absolute;
    if (!artifact.path.startsWith(rootPrefix) || !artifact.existsSync()) {
      _fail('case[$index] artifact is missing or escapes artifact root');
    }
    final bytes = _integer(result['bytes'], 'case[$index].bytes');
    final artifactSha = _sha256String(result['sha256'], 'case[$index].sha256');
    if (bytes < 1 ||
        artifact.lengthSync() != bytes ||
        _rawSha(artifact.path) != artifactSha) {
      _fail('case[$index] bytes/hash do not match the artifact');
    }
    if (visual) {
      const pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
      final prefix = artifact.openSync()..setPositionSync(0);
      final header = prefix.readSync(24);
      prefix.closeSync();
      if (header.length != 24 ||
          !_listEquals(header.take(8).toList(), pngSignature)) {
        _fail('case[$index] is not a PNG artifact');
      }
      int readUint32(int offset) =>
          (header[offset] << 24) |
          (header[offset + 1] << 16) |
          (header[offset + 2] << 8) |
          header[offset + 3];
      final expectedWidth =
          _integer(expected['width'], 'generated[$index].width') *
          _integer(
            expected['device_pixel_ratio'],
            'generated[$index].device_pixel_ratio',
          );
      final expectedHeight =
          _integer(expected['height'], 'generated[$index].height') *
          _integer(
            expected['device_pixel_ratio'],
            'generated[$index].device_pixel_ratio',
          );
      if (readUint32(16) != expectedWidth || readUint32(20) != expectedHeight) {
        _fail('case[$index] PNG IHDR axes differ from its catalog case');
      }
      if (mode == _releaseReady) {
        final baselineArtifact = File.fromUri(
          Directory(baselineRoot!).absolute.uri.resolve(relativePath),
        );
        if (!baselineArtifact.existsSync() ||
            _rawSha(baselineArtifact.path) != artifactSha) {
          _fail('case[$index] differs from the approved baseline bytes');
        }
      }
    } else {
      for (final key in [
        'critical_violations',
        'serious_violations',
        'other_violations',
        'passes',
        'incomplete',
      ]) {
        if (_integer(result[key], 'case[$index].$key') < 0) {
          _fail('case[$index].$key must be non-negative');
        }
      }
      _validateA11yResult(
        _object(jsonDecode(artifact.readAsStringSync()), relativePath),
        result,
      );
    }
  }
  final kindRoot = Directory.fromUri(root.uri.resolve('$kind/'));
  final actualPaths = kindRoot.existsSync()
      ? kindRoot
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .map(
              (file) => file.absolute.path
                  .substring(rootPrefix.length)
                  .replaceAll('\\', '/'),
            )
            .toSet()
      : <String>{};
  if (!_setEquals(actualPaths, paths)) {
    _fail('$kind artifact set contains missing or unmanifested files');
  }
}

/// Validates the complete result-manifest document without requiring the raw
/// capture set or build marker. This is the strict trust boundary used when a
/// four-file sealed package is re-opened independently of the producer job.
Map<String, Object?> validateResultManifestDocument({
  required String kind,
  required String manifestPath,
  String catalogPath = 'evidence/et13/catalog.v1.json',
  String? generatedCatalogPath,
  String assetsLockPath = 'evidence/et13/assets.lock.json',
  String rendererLockPath = 'evidence/et13/renderer.lock.json',
}) {
  final visual = kind == 'visual';
  if (!visual && kind != 'a11y') _fail('kind must be visual or a11y');
  final manifest = _readObject(manifestPath);
  _exactKeys(
    manifest,
    visual ? _visualManifestKeys : _a11yManifestKeys,
    r'$manifest',
  );
  final casePath =
      generatedCatalogPath ??
      'evidence/et13/generated/${visual ? 'visual' : 'a11y'}-cases.v1.json';
  final generated = _readObject(casePath);
  final expectedCases = _array(generated['cases'], 'generated.cases');
  final expectedCount = visual ? 96 : 24;
  final expectedSurfaceCounts = visual
      ? _visualSurfaceCounts
      : _a11ySurfaceCounts;
  final expectedSchema = visual
      ? 'leva.et13.visual-manifest.v1'
      : 'leva.et13.a11y-manifest.v1';
  final expectedCaseSchema = visual ? _visualVersion : _a11yVersion;
  final mode = _mode(manifest['evidence_mode'], 'manifest.evidence_mode');
  final sourceSha = _string(manifest['source_sha'], 'manifest.source_sha');
  if (!RegExp(r'^(?!0{40}$)[0-9a-f]{40}$').hasMatch(sourceSha)) {
    _fail('manifest source SHA must be a non-zero lowercase git SHA');
  }
  final catalog = validateCatalog(path: catalogPath);
  final renderer = validateRendererLock(rendererLockPath);
  for (final entry in <String, Object?>{
    'schema_version': expectedSchema,
    'case_catalog_version': _catalogVersion,
    'case_catalog_schema_version': expectedCaseSchema,
    'fixture_ids': _fixtureIds,
    'catalog_sha256': _rawSha(catalogPath),
    'case_catalog_sha256': _rawSha(casePath),
    'projection_contract_sha256': catalog['projection_contract_sha256'],
    'assets_lock_sha256': _rawSha(assetsLockPath),
    'renderer_lock_sha256': _rawSha(rendererLockPath),
    'renderer_image': renderer['image'],
    'renderer_image_digest': renderer['manifest_digest'],
    'capture_network': 'none',
    'unexpected_request_policy': 'fail',
    'capture_surface': _captureSurface,
    'device_evidence': false,
    'external_accessibility_status': _externalAccessibilityStatus,
    'case_count': expectedCount,
    'surface_case_counts': expectedSurfaceCounts,
  }.entries) {
    _exactValue(manifest[entry.key], entry.value, 'manifest.${entry.key}');
  }
  _sha256String(
    manifest['input_provenance_sha256'],
    'manifest.input_provenance_sha256',
  );
  if (visual) {
    _exactValue(
      manifest['baseline_status'],
      mode == _releaseReady ? _approved : _pendingReview,
      'manifest.baseline_status',
    );
    for (final key in ['baseline_set_sha256', 'baseline_approval_sha256']) {
      if (mode == _releaseReady) {
        _sha256String(manifest[key], 'manifest.$key');
      } else {
        _exactValue(manifest[key], null, 'manifest.$key');
      }
    }
  }
  final actualCases = _array(manifest['cases'], 'manifest.cases');
  if (actualCases.length != expectedCount ||
      expectedCases.length != expectedCount) {
    _fail('manifest must contain exactly $expectedCount ordered cases');
  }
  for (var index = 0; index < expectedCount; index++) {
    final actual = _object(actualCases[index], 'manifest.cases[$index]');
    final expected = _object(expectedCases[index], 'generated.cases[$index]');
    _exactKeys(
      actual,
      visual ? _visualResultCaseKeys : _a11yResultCaseKeys,
      'manifest.cases[$index]',
    );
    _exactValue(
      actual['case_id'],
      expected['case_id'],
      'manifest.cases[$index].case_id',
    );
    _exactValue(
      actual['artifact_path'],
      expected['artifact_path'],
      'manifest.cases[$index].artifact_path',
    );
    _exactValue(actual['status'], 'passed', 'manifest.cases[$index].status');
    _sha256String(actual['sha256'], 'manifest.cases[$index].sha256');
    if (_integer(actual['bytes'], 'manifest.cases[$index].bytes') < 1) {
      _fail('manifest.cases[$index].bytes must be positive');
    }
    if (!visual) {
      _exactValue(
        actual['standard'],
        _a11yStandard,
        'manifest.cases[$index].standard',
      );
      for (final key in ['critical_violations', 'serious_violations']) {
        _exactValue(actual[key], 0, 'manifest.cases[$index].$key');
      }
      for (final key in ['other_violations', 'passes', 'incomplete']) {
        if (_integer(actual[key], 'manifest.cases[$index].$key') < 0) {
          _fail('manifest.cases[$index].$key must be non-negative');
        }
      }
    }
  }
  return manifest;
}

void validateResultManifest({
  required String kind,
  required String manifestPath,
  required String artifactRoot,
  required String buildMarkerPath,
  required String provenancePath,
  String? baselineRoot,
  String? baselineApprovalPath,
}) {
  final visual = kind == 'visual';
  if (!visual && kind != 'a11y') _fail('kind must be visual or a11y');
  final manifest = validateResultManifestDocument(
    kind: kind,
    manifestPath: manifestPath,
  );

  final casePath = visual
      ? 'evidence/et13/generated/visual-cases.v1.json'
      : 'evidence/et13/generated/a11y-cases.v1.json';
  final expectedCount = visual ? 96 : 24;
  final expectedSurfaceCounts = visual
      ? _visualSurfaceCounts
      : _a11ySurfaceCounts;
  final expectedSchema = visual
      ? 'leva.et13.visual-manifest.v1'
      : 'leva.et13.a11y-manifest.v1';
  final expectedCaseSchema = visual ? _visualVersion : _a11yVersion;
  _exactValue(manifest['schema_version'], expectedSchema, 'manifest.schema');
  final mode = _mode(manifest['evidence_mode'], 'manifest.evidence_mode');
  _exactValue(
    manifest['case_catalog_version'],
    _catalogVersion,
    'manifest.case_catalog_version',
  );
  _exactValue(
    manifest['case_catalog_schema_version'],
    expectedCaseSchema,
    'manifest.case_catalog_schema_version',
  );
  if (!_listEquals(
    _array(manifest['fixture_ids'], 'manifest.fixture_ids'),
    _fixtureIds,
  )) {
    _fail('manifest fixture order drifted');
  }
  _exactValue(manifest['case_count'], expectedCount, 'manifest.case_count');
  if (!_mapEquals(
    _object(manifest['surface_case_counts'], 'manifest.surface_case_counts'),
    expectedSurfaceCounts,
  )) {
    _fail('manifest surface case counts drifted');
  }
  _exactValue(
    manifest['catalog_sha256'],
    _rawSha('evidence/et13/catalog.v1.json'),
    'manifest.catalog_sha256',
  );
  _exactValue(
    manifest['case_catalog_sha256'],
    _rawSha(casePath),
    'manifest.case_catalog_sha256',
  );
  _exactValue(
    manifest['projection_contract_sha256'],
    validateCatalog()['projection_contract_sha256'],
    'manifest.projection_contract_sha256',
  );
  _exactValue(
    manifest['assets_lock_sha256'],
    _rawSha('evidence/et13/assets.lock.json'),
    'manifest.assets_lock_sha256',
  );
  _exactValue(
    manifest['renderer_lock_sha256'],
    _rawSha('evidence/et13/renderer.lock.json'),
    'manifest.renderer_lock_sha256',
  );
  final sourceSha = _string(manifest['source_sha'], 'manifest.source_sha');
  final provenance = validateInputProvenanceFile(
    kind: kind,
    sourceSha: sourceSha,
    buildMarkerPath: buildMarkerPath,
    provenancePath: provenancePath,
  );
  final baselineAuthentication = _validateProvenanceMode(provenance, mode);
  _exactValue(
    manifest['input_provenance_sha256'],
    provenance['input_provenance_sha256'],
    'manifest.input_provenance_sha256',
  );
  final renderer = validateRendererLock();
  for (final entry in <String, Object?>{
    'renderer_image': renderer['image'],
    'renderer_image_digest': renderer['manifest_digest'],
    'capture_network': 'none',
    'unexpected_request_policy': 'fail',
    'capture_surface': _captureSurface,
    'device_evidence': false,
    'external_accessibility_status': _externalAccessibilityStatus,
  }.entries) {
    _exactValue(manifest[entry.key], entry.value, 'manifest.${entry.key}');
  }
  final baseline = _baselineDigests(
    visual: visual,
    mode: mode,
    sourceSha: sourceSha,
    baselineRoot: baselineRoot,
    approvalPath: baselineApprovalPath,
  );
  if (visual && mode == _releaseReady) {
    _exactValue(
      baselineAuthentication!['approval_document_sha256'],
      baseline.approvalSha,
      'provenance.baseline_authentication.approval_document_sha256',
    );
  }
  if (visual) {
    _exactValue(
      manifest['baseline_status'],
      mode == _releaseReady ? _approved : _pendingReview,
      'manifest.baseline_status',
    );
    _exactValue(
      manifest['baseline_set_sha256'],
      baseline.setSha,
      'manifest.baseline_set_sha256',
    );
    _exactValue(
      manifest['baseline_approval_sha256'],
      baseline.approvalSha,
      'manifest.baseline_approval_sha256',
    );
  }
  validateResultArtifacts(
    kind: kind,
    manifestPath: manifestPath,
    artifactRoot: artifactRoot,
    generatedCatalogPath: casePath,
    baselineRoot: baselineRoot,
  );
}

/// Re-opens an authenticated diagnostic review bundle on a fresh approval
/// runner. This validates the packaged marker, provenance, manifest, and
/// capture bytes without requiring the producer-only Flutter build trees.
/// [validateResultManifest] remains the producer boundary that additionally
/// re-opens every release build and the clean source checkout.
void validateReviewManifest({
  required String kind,
  required String manifestPath,
  required String artifactRoot,
  required String buildMarkerPath,
  required String provenancePath,
}) {
  final manifest = validateResultManifestDocument(
    kind: kind,
    manifestPath: manifestPath,
  );
  final mode = _mode(manifest['evidence_mode'], 'manifest.evidence_mode');
  _exactValue(mode, _diagnostic, 'manifest.evidence_mode');
  final sourceSha = _string(manifest['source_sha'], 'manifest.source_sha');
  validateBuildMarkerDocument(
    sourceSha: sourceSha,
    buildMarkerPath: buildMarkerPath,
  );
  final provenance = validateInputProvenanceDocument(
    kind: kind,
    provenancePath: provenancePath,
  );
  _validateProvenanceMode(provenance, mode);
  _exactValue(
    provenance['build_marker_sha256'],
    _rawSha(buildMarkerPath),
    'provenance.build_marker_sha256',
  );
  for (final key in [
    'source_sha',
    'catalog_sha256',
    'case_catalog_sha256',
    'projection_contract_sha256',
    'assets_lock_sha256',
    'renderer_lock_sha256',
    'renderer_image_digest',
    'input_provenance_sha256',
  ]) {
    _exactValue(manifest[key], provenance[key], 'manifest.$key');
  }
  validateResultArtifacts(
    kind: kind,
    manifestPath: manifestPath,
    artifactRoot: artifactRoot,
  );
}

int _positiveInteger(String value, String path) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 1) _fail('$path must be a positive integer');
  return parsed;
}

String _repository(String value) {
  if (!RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(value)) {
    _fail('repository must be an owner/name slug');
  }
  return value;
}

Map<String, Object?> _validateCaptureSummary({
  required String path,
  required String sourceSha,
  required String mode,
}) {
  final summary = _readObject(path);
  _exactKeys(summary, const [
    'schema_version',
    'source_sha',
    'evidence_mode',
    'capture_surface',
    'device_evidence',
    'case_count',
    'cases',
  ], r'$captureSummary');
  _exactValue(
    summary['schema_version'],
    'leva.et13.capture-summary.v1',
    'captureSummary.schema_version',
  );
  _exactValue(summary['source_sha'], sourceSha, 'captureSummary.source_sha');
  _exactValue(summary['evidence_mode'], mode, 'captureSummary.evidence_mode');
  _exactValue(
    summary['capture_surface'],
    _captureSurface,
    'captureSummary.capture_surface',
  );
  _exactValue(summary['device_evidence'], false, 'captureSummary.device');
  _exactValue(summary['case_count'], 120, 'captureSummary.case_count');
  final actual = _array(summary['cases'], 'captureSummary.cases');
  final expected = <Map<String, Object?>>[
    for (final lane in ['visual', 'a11y'])
      for (final raw in _array(
        _readObject('evidence/et13/generated/$lane-cases.v1.json')['cases'],
        '$lane.cases',
      ))
        _object(raw, '$lane.case'),
  ];
  if (actual.length != expected.length) {
    _fail('capture summary must contain exactly 120 ordered cases');
  }
  for (var index = 0; index < actual.length; index++) {
    final result = _object(actual[index], 'captureSummary.cases[$index]');
    final expectedCase = expected[index];
    final visual = index < 96;
    _exactKeys(
      result,
      visual
          ? const [
              'case_id',
              'lane',
              'status',
              'artifact_path',
              'pixel_diff_percent',
            ]
          : const ['case_id', 'lane', 'status', 'artifact_path'],
      'captureSummary.cases[$index]',
    );
    _exactValue(
      result['case_id'],
      expectedCase['case_id'],
      'captureSummary.cases[$index].case_id',
    );
    _exactValue(
      result['artifact_path'],
      expectedCase['artifact_path'],
      'captureSummary.cases[$index].artifact_path',
    );
    _exactValue(result['lane'], visual ? 'visual' : 'a11y', 'summary.lane');
    _exactValue(result['status'], 'passed', 'summary.status');
    if (visual) {
      _exactValue(
        result['pixel_diff_percent'],
        mode == _releaseReady ? 0 : null,
        'summary.pixel_diff_percent',
      );
    }
  }
  return summary;
}

Map<String, Object?> writeCandidateSpec({
  required String kind,
  required String sourceSha,
  required String buildMarkerPath,
  required String provenancePath,
  required String mode,
  required String producerRunId,
  required String producerRunAttempt,
  required String repository,
  required String outputPath,
  String? baselineRoot,
  String? baselineApprovalPath,
}) {
  final visual = kind == 'visual';
  if (!visual && kind != 'a11y') _fail('kind must be visual or a11y');
  _mode(mode, 'candidate.evidence_mode');
  final provenance = validateInputProvenanceFile(
    kind: kind,
    sourceSha: sourceSha,
    buildMarkerPath: buildMarkerPath,
    provenancePath: provenancePath,
  );
  final baselineAuthentication = _validateProvenanceMode(provenance, mode);
  final baseline = _baselineDigests(
    visual: visual,
    mode: mode,
    sourceSha: sourceSha,
    baselineRoot: baselineRoot,
    approvalPath: baselineApprovalPath,
  );
  if (visual && mode == _releaseReady) {
    _exactValue(
      baselineAuthentication!['approval_document_sha256'],
      baseline.approvalSha,
      'provenance.baseline_authentication.approval_document_sha256',
    );
  }
  final casePath =
      'evidence/et13/generated/${visual ? 'visual' : 'a11y'}-cases.v1.json';
  final generated = _readObject(casePath);
  final candidate = <String, Object?>{
    'schema_version': 'leva.et13.candidate-spec.v1',
    'kind': kind,
    'evidence_mode': mode,
    'producer_run_id': _positiveInteger(producerRunId, 'producer_run_id'),
    'producer_run_attempt': _positiveInteger(
      producerRunAttempt,
      'producer_run_attempt',
    ),
    'repository': _repository(repository),
    'source_sha': sourceSha,
    'case_catalog_sha256': _rawSha(casePath),
    'case_catalog_version': _catalogVersion,
    'case_catalog_schema_version': visual ? _visualVersion : _a11yVersion,
    'projection_contract_sha256':
        validateCatalog()['projection_contract_sha256'],
    'fixture_ids': _fixtureIds,
    'case_count': visual ? 96 : 24,
    'surface_case_counts': generated['surface_case_counts'],
    'capture_surface': _captureSurface,
    'device_evidence': false,
    'input_provenance_sha256': provenance['input_provenance_sha256'],
    'input_provenance_file_sha256': _rawSha(provenancePath),
    if (visual) ...{
      'baseline_status': mode == _releaseReady ? _approved : _pendingReview,
      'baseline_set_sha256': baseline.setSha,
      'baseline_approval_sha256': baseline.approvalSha,
    },
  };
  _writePretty(outputPath, candidate);
  return candidate;
}

void validateCandidateProvenanceIdentity({
  required Map<String, Object?> candidate,
  required Map<String, Object?> provenance,
}) {
  for (final key in ['source_sha', 'input_provenance_sha256']) {
    _exactValue(candidate[key], provenance[key], 'candidate.$key');
  }
}

Map<String, Object?> _validateCandidateSpec({
  required String kind,
  required String candidatePath,
  required String provenancePath,
}) {
  final visual = kind == 'visual';
  final candidate = _readObject(candidatePath);
  _exactKeys(candidate, [
    'schema_version',
    'kind',
    'evidence_mode',
    'producer_run_id',
    'producer_run_attempt',
    'repository',
    'source_sha',
    'case_catalog_sha256',
    'case_catalog_version',
    'case_catalog_schema_version',
    'projection_contract_sha256',
    'fixture_ids',
    'case_count',
    'surface_case_counts',
    'capture_surface',
    'device_evidence',
    'input_provenance_sha256',
    'input_provenance_file_sha256',
    if (visual) ...[
      'baseline_status',
      'baseline_set_sha256',
      'baseline_approval_sha256',
    ],
  ], r'$candidate');
  _exactValue(
    candidate['schema_version'],
    'leva.et13.candidate-spec.v1',
    'candidate.schema_version',
  );
  _exactValue(candidate['kind'], kind, 'candidate.kind');
  _mode(candidate['evidence_mode'], 'candidate.evidence_mode');
  if (_integer(candidate['producer_run_id'], 'candidate.run_id') < 1 ||
      _integer(candidate['producer_run_attempt'], 'candidate.run_attempt') <
          1) {
    _fail('candidate producer run identity must be positive integers');
  }
  _repository(_string(candidate['repository'], 'candidate.repository'));
  final casePath =
      'evidence/et13/generated/${visual ? 'visual' : 'a11y'}-cases.v1.json';
  final generated = _readObject(casePath);
  for (final entry in <String, Object?>{
    'case_catalog_sha256': _rawSha(casePath),
    'case_catalog_version': _catalogVersion,
    'case_catalog_schema_version': visual ? _visualVersion : _a11yVersion,
    'projection_contract_sha256':
        validateCatalog()['projection_contract_sha256'],
    'case_count': visual ? 96 : 24,
    'capture_surface': _captureSurface,
    'device_evidence': false,
    'input_provenance_file_sha256': _rawSha(provenancePath),
  }.entries) {
    _exactValue(candidate[entry.key], entry.value, 'candidate.${entry.key}');
  }
  if (!_listEquals(
    _array(candidate['fixture_ids'], 'candidate.fixture_ids'),
    _fixtureIds,
  )) {
    _fail('candidate fixture order drifted');
  }
  if (!_mapEquals(
    _object(candidate['surface_case_counts'], 'candidate.surface_counts'),
    _object(generated['surface_case_counts'], 'generated.surface_counts'),
  )) {
    _fail('candidate surface counts drifted');
  }
  final provenance = validateInputProvenanceDocument(
    kind: kind,
    provenancePath: provenancePath,
  );
  final baselineAuthentication = _validateProvenanceMode(
    provenance,
    _string(candidate['evidence_mode'], 'candidate.evidence_mode'),
  );
  validateCandidateProvenanceIdentity(
    candidate: candidate,
    provenance: provenance,
  );
  if (visual) {
    final mode = candidate['evidence_mode'];
    _exactValue(
      candidate['baseline_status'],
      mode == _releaseReady ? _approved : _pendingReview,
      'candidate.baseline_status',
    );
    for (final key in ['baseline_set_sha256', 'baseline_approval_sha256']) {
      if (mode == _releaseReady) {
        _sha256String(candidate[key], 'candidate.$key');
      } else {
        _exactValue(candidate[key], null, 'candidate.$key');
      }
    }
    if (mode == _releaseReady) {
      _exactValue(
        baselineAuthentication!['approval_document_sha256'],
        candidate['baseline_approval_sha256'],
        'candidate.baseline_approval_sha256',
      );
    }
  }
  return candidate;
}

/// Authenticates the exact raw canonical GitOps candidate bytes and the ET13
/// lane prebindings consumed by this producer. The protected GitOps workflow
/// owns the surrounding full candidate schema, so this validator deliberately
/// reads only the immutable fields the frontend producer must enforce.
String validateCanonicalReleaseCandidateForLane({
  required String kind,
  required String canonicalCandidatePath,
  required String expectedCandidateSha256,
  required String releaseId,
  required String sourceSha,
  required Map<String, Object?> laneBinding,
  String catalogPath = 'evidence/et13/catalog.v1.json',
}) {
  final visual = kind == 'visual';
  if (!visual && kind != 'a11y') _fail('kind must be visual or a11y');
  final expectedSha = _sha256String(
    expectedCandidateSha256,
    'canonicalCandidate.expectedSha256',
  );
  final actualSha = _rawSha(canonicalCandidatePath);
  _exactValue(actualSha, expectedSha, 'canonicalCandidate.rawSha256');
  final candidate = _readObject(canonicalCandidatePath);
  _exactKeys(candidate, const [
    r'$schema',
    'schema_version',
    'document_type',
    'release_id',
    'created_at',
    'gitops',
    'services',
    'shared_migration',
    'frontend',
    'home',
    'analytics_privacy',
    'ai_release_eval_config',
    'environments',
    'journey_harness',
    'quality_evidence_inputs',
    'rollout',
  ], r'$canonicalCandidate');
  _exactValue(
    candidate['document_type'],
    'candidate-spec',
    'canonicalCandidate.document_type',
  );
  _exactValue(
    candidate['release_id'],
    releaseId,
    'canonicalCandidate.release_id',
  );
  final frontend = _object(
    candidate['frontend'],
    'canonicalCandidate.frontend',
  );
  _exactValue(
    frontend['repository'],
    'DevPathAi/devpath-frontend',
    'canonicalCandidate.frontend.repository',
  );
  _exactValue(
    frontend['source_sha'],
    sourceSha,
    'canonicalCandidate.frontend.source_sha',
  );
  _exactValue(
    laneBinding['repository'],
    'DevPathAi/devpath-frontend',
    'laneBinding.repository',
  );
  final inputs = _object(
    candidate['quality_evidence_inputs'],
    'canonicalCandidate.quality_evidence_inputs',
  );
  final projection = _object(
    inputs['frontend_projection_contract'],
    'canonicalCandidate.frontend_projection_contract',
  );
  _exactKeys(projection, const [
    'schema_version',
    'projection_contract_sha256',
    'projection_matrix',
  ], r'$canonicalCandidate.frontend_projection_contract');
  final catalog = validateCatalog(path: catalogPath);
  for (final entry in <String, Object?>{
    'schema_version': _projectionContractVersion,
    'projection_contract_sha256': catalog['projection_contract_sha256'],
    'projection_matrix': catalog['projection_matrix'],
  }.entries) {
    _exactValue(
      projection[entry.key],
      entry.value,
      'canonicalCandidate.frontend_projection_contract.${entry.key}',
    );
  }
  final catalogs = _object(inputs['catalogs'], 'canonicalCandidate.catalogs');
  final label = visual ? 'frontend-visual' : 'frontend-automated-a11y';
  final lane = _object(catalogs[label], 'canonicalCandidate.catalogs.$label');
  final generatedPath =
      'evidence/et13/generated/${visual ? 'visual' : 'a11y'}-cases.v1.json';
  final expected = <String, Object?>{
    'repository': 'DevPathAi/devpath-frontend',
    'source_sha': sourceSha,
    'path': generatedPath,
    'sha256': laneBinding['case_catalog_sha256'],
    'case_catalog_version': laneBinding['case_catalog_version'],
    'case_catalog_schema_version': laneBinding['case_catalog_schema_version'],
    'projection_contract_sha256': laneBinding['projection_contract_sha256'],
    'fixture_ids': laneBinding['fixture_ids'],
    'case_count': laneBinding['case_count'],
    'surface_case_counts': laneBinding['surface_case_counts'],
    'capture_surface': laneBinding['capture_surface'],
    'device_evidence': laneBinding['device_evidence'],
    'evidence_mode': _releaseReady,
    'input_provenance_sha256': laneBinding['input_provenance_sha256'],
    'input_provenance_file_sha256': laneBinding['input_provenance_file_sha256'],
    if (visual) ...{
      'baseline_status': _approved,
      'baseline_set_sha256': laneBinding['baseline_set_sha256'],
      'baseline_approval_sha256': laneBinding['baseline_approval_sha256'],
    },
  };
  _exactKeys(
    lane,
    expected.keys.toList(growable: false),
    r'$canonicalCandidate.catalogs.' + label,
  );
  for (final entry in expected.entries) {
    _exactValue(
      lane[entry.key],
      entry.value,
      'canonicalCandidate.catalogs.$label.${entry.key}',
    );
  }
  return actualSha;
}

String _evidenceCandidateSha({
  required String kind,
  required Map<String, Object?> laneBinding,
  required String laneBindingPath,
  String? canonicalCandidatePath,
  String? canonicalCandidateSha256,
  String? releaseId,
}) {
  final release = laneBinding['evidence_mode'] == _releaseReady;
  final supplied = [
    canonicalCandidatePath,
    canonicalCandidateSha256,
    releaseId,
  ];
  if (release) {
    if (supplied.any((value) => value == null || value.isEmpty)) {
      _fail(
        'release-ready evidence requires the full canonical candidate path, '
        'raw SHA-256, and release ID',
      );
    }
    return validateCanonicalReleaseCandidateForLane(
      kind: kind,
      canonicalCandidatePath: canonicalCandidatePath!,
      expectedCandidateSha256: canonicalCandidateSha256!,
      releaseId: releaseId!,
      sourceSha: _string(laneBinding['source_sha'], 'binding.source_sha'),
      laneBinding: laneBinding,
    );
  }
  if (supplied.any((value) => value != null)) {
    _fail('diagnostic evidence must not consume a canonical release candidate');
  }
  return _rawSha(laneBindingPath);
}

void validateAtomicLaneBindingIdentity({
  required Map<String, Object?> visualBinding,
  required Map<String, Object?> a11yBinding,
}) {
  for (final key in [
    'evidence_mode',
    'producer_run_id',
    'producer_run_attempt',
    'repository',
    'source_sha',
  ]) {
    _exactValue(
      a11yBinding[key],
      visualBinding[key],
      'atomicLaneIdentity.$key',
    );
  }
}

void validateCanonicalReleaseInputs({
  required String canonicalCandidatePath,
  required String canonicalCandidateSha256,
  required String releaseId,
  required String visualCandidatePath,
  required String visualProvenancePath,
  required String a11yCandidatePath,
  required String a11yProvenancePath,
}) {
  final bindings = <String, Map<String, Object?>>{
    'visual': _validateCandidateSpec(
      kind: 'visual',
      candidatePath: visualCandidatePath,
      provenancePath: visualProvenancePath,
    ),
    'a11y': _validateCandidateSpec(
      kind: 'a11y',
      candidatePath: a11yCandidatePath,
      provenancePath: a11yProvenancePath,
    ),
  };
  final sourceSha = _string(
    bindings['visual']!['source_sha'],
    'visualBinding.source_sha',
  );
  validateAtomicLaneBindingIdentity(
    visualBinding: bindings['visual']!,
    a11yBinding: bindings['a11y']!,
  );
  final visualProvenance = validateInputProvenanceDocument(
    kind: 'visual',
    provenancePath: visualProvenancePath,
  );
  final a11yProvenance = validateInputProvenanceDocument(
    kind: 'a11y',
    provenancePath: a11yProvenancePath,
  );
  final baselineAuthentication = _object(
    visualProvenance['baseline_authentication'],
    'visualProvenance.baseline_authentication',
  );
  _exactValue(
    a11yProvenance['baseline_authentication'],
    baselineAuthentication,
    'atomicLaneIdentity.baseline_authentication',
  );
  _exactValue(
    baselineAuthentication['release_id'],
    releaseId,
    'baselineAuthentication.release_id',
  );
  _exactValue(
    baselineAuthentication['approval_document_sha256'],
    bindings['visual']!['baseline_approval_sha256'],
    'baselineAuthentication.approval_document_sha256',
  );
  for (final entry in bindings.entries) {
    _exactValue(
      entry.value['evidence_mode'],
      _releaseReady,
      '${entry.key}Binding.evidence_mode',
    );
    _exactValue(
      entry.value['source_sha'],
      sourceSha,
      '${entry.key}Binding.source_sha',
    );
    validateCanonicalReleaseCandidateForLane(
      kind: entry.key,
      canonicalCandidatePath: canonicalCandidatePath,
      expectedCandidateSha256: canonicalCandidateSha256,
      releaseId: releaseId,
      sourceSha: sourceSha,
      laneBinding: entry.value,
    );
  }
}

Map<String, Object?> writeResultManifest({
  required String kind,
  required String sourceSha,
  required String buildMarkerPath,
  required String provenancePath,
  required String artifactRoot,
  required String captureSummaryPath,
  required String mode,
  required String outputPath,
  String? baselineRoot,
  String? baselineApprovalPath,
}) {
  final visual = kind == 'visual';
  if (!visual && kind != 'a11y') _fail('kind must be visual or a11y');
  _mode(mode, 'manifest.evidence_mode');
  final provenance = validateInputProvenanceFile(
    kind: kind,
    sourceSha: sourceSha,
    buildMarkerPath: buildMarkerPath,
    provenancePath: provenancePath,
  );
  final baselineAuthentication = _validateProvenanceMode(provenance, mode);
  _validateCaptureSummary(
    path: captureSummaryPath,
    sourceSha: sourceSha,
    mode: mode,
  );
  final baseline = _baselineDigests(
    visual: visual,
    mode: mode,
    sourceSha: sourceSha,
    baselineRoot: baselineRoot,
    approvalPath: baselineApprovalPath,
  );
  if (visual && mode == _releaseReady) {
    _exactValue(
      baselineAuthentication!['approval_document_sha256'],
      baseline.approvalSha,
      'provenance.baseline_authentication.approval_document_sha256',
    );
  }
  final casePath =
      'evidence/et13/generated/${visual ? 'visual' : 'a11y'}-cases.v1.json';
  final generated = _readObject(casePath);
  final cases = <Map<String, Object?>>[];
  for (final raw in _array(generated['cases'], 'generated.cases')) {
    final expected = _object(raw, 'generated.case');
    final relative = _string(expected['artifact_path'], 'generated.path');
    final artifact = File.fromUri(
      Directory(artifactRoot).uri.resolve(relative),
    );
    if (!artifact.existsSync()) _fail('missing capture artifact $relative');
    final result = <String, Object?>{
      'case_id': expected['case_id'],
      'status': 'passed',
      'artifact_path': relative,
      'sha256': _rawSha(artifact.path),
      'bytes': artifact.lengthSync(),
    };
    if (!visual) {
      final detail = _readObject(artifact.path);
      for (final key in [
        'standard',
        'critical_violations',
        'serious_violations',
        'other_violations',
        'passes',
        'incomplete',
      ]) {
        result[key] = detail[key];
      }
      _validateA11yResult(detail, result);
    }
    cases.add(result);
  }
  final renderer = validateRendererLock();
  final manifest = <String, Object?>{
    'schema_version': visual
        ? 'leva.et13.visual-manifest.v1'
        : 'leva.et13.a11y-manifest.v1',
    'evidence_mode': mode,
    'case_catalog_version': _catalogVersion,
    'case_catalog_schema_version': visual ? _visualVersion : _a11yVersion,
    'fixture_ids': _fixtureIds,
    'source_sha': sourceSha,
    'catalog_sha256': _rawSha('evidence/et13/catalog.v1.json'),
    'case_catalog_sha256': _rawSha(casePath),
    'projection_contract_sha256':
        validateCatalog()['projection_contract_sha256'],
    'assets_lock_sha256': _rawSha('evidence/et13/assets.lock.json'),
    'renderer_lock_sha256': _rawSha('evidence/et13/renderer.lock.json'),
    'input_provenance_sha256': provenance['input_provenance_sha256'],
    'renderer_image': renderer['image'],
    'renderer_image_digest': renderer['manifest_digest'],
    'capture_network': 'none',
    'unexpected_request_policy': 'fail',
    'capture_surface': _captureSurface,
    'device_evidence': false,
    'external_accessibility_status': _externalAccessibilityStatus,
    if (visual) ...{
      'baseline_status': mode == _releaseReady ? _approved : _pendingReview,
      'baseline_set_sha256': baseline.setSha,
      'baseline_approval_sha256': baseline.approvalSha,
    },
    'case_count': visual ? 96 : 24,
    'surface_case_counts': visual ? _visualSurfaceCounts : _a11ySurfaceCounts,
    'cases': cases,
  };
  _writePretty(outputPath, manifest);
  validateResultManifest(
    kind: kind,
    manifestPath: outputPath,
    artifactRoot: artifactRoot,
    buildMarkerPath: buildMarkerPath,
    provenancePath: provenancePath,
    baselineRoot: baselineRoot,
    baselineApprovalPath: baselineApprovalPath,
  );
  return manifest;
}

Map<String, Object?> writeSanitizedEvidence({
  required String kind,
  required String candidatePath,
  required String provenancePath,
  required String manifestPath,
  required String outputPath,
  String? canonicalCandidatePath,
  String? canonicalCandidateSha256,
  String? releaseId,
}) {
  final visual = kind == 'visual';
  if (!visual && kind != 'a11y') _fail('kind must be visual or a11y');
  final candidate = _validateCandidateSpec(
    kind: kind,
    candidatePath: candidatePath,
    provenancePath: provenancePath,
  );
  if (candidate['evidence_mode'] == _releaseReady) {
    final provenance = validateInputProvenanceDocument(
      kind: kind,
      provenancePath: provenancePath,
    );
    final authentication = _object(
      provenance['baseline_authentication'],
      'provenance.baseline_authentication',
    );
    _exactValue(
      authentication['release_id'],
      releaseId,
      'baselineAuthentication.release_id',
    );
  }
  final manifest = validateResultManifestDocument(
    kind: kind,
    manifestPath: manifestPath,
  );
  final cases = _array(manifest['cases'], 'manifest.cases');
  if (cases.any((raw) => _object(raw, 'case')['status'] != 'passed')) {
    _fail('sanitized evidence cannot include a failed manifest case');
  }
  for (final key in [
    'source_sha',
    'case_catalog_sha256',
    'case_catalog_version',
    'case_catalog_schema_version',
    'projection_contract_sha256',
    'fixture_ids',
    'case_count',
    'surface_case_counts',
    'capture_surface',
    'device_evidence',
    'input_provenance_sha256',
    'evidence_mode',
  ]) {
    if (jsonEncode(candidate[key]) != jsonEncode(manifest[key])) {
      _fail('candidate and result manifest disagree at $key');
    }
  }
  if (visual) {
    for (final key in [
      'baseline_status',
      'baseline_set_sha256',
      'baseline_approval_sha256',
    ]) {
      if (jsonEncode(candidate[key]) != jsonEncode(manifest[key])) {
        _fail('candidate and result manifest disagree at $key');
      }
    }
  }
  final candidateSha = _evidenceCandidateSha(
    kind: kind,
    laneBinding: candidate,
    laneBindingPath: candidatePath,
    canonicalCandidatePath: canonicalCandidatePath,
    canonicalCandidateSha256: canonicalCandidateSha256,
    releaseId: releaseId,
  );
  final evidence = <String, Object?>{
    'candidate_spec_sha256': candidateSha,
    'status': 'passed',
    'producer_run_id': candidate['producer_run_id'],
    'producer_run_attempt': candidate['producer_run_attempt'],
    'repository': candidate['repository'],
    'source_sha': candidate['source_sha'],
    'case_catalog_sha256': candidate['case_catalog_sha256'],
    'case_catalog_version': _catalogVersion,
    'case_catalog_schema_version': candidate['case_catalog_schema_version'],
    'projection_contract_sha256': candidate['projection_contract_sha256'],
    'fixture_ids': _fixtureIds,
    'case_count': visual ? 96 : 24,
    'passed_case_count': visual ? 96 : 24,
    'failed_case_count': 0,
    'surface_case_counts': candidate['surface_case_counts'],
    'capture_surface': _captureSurface,
    'device_evidence': false,
    'input_provenance_sha256': candidate['input_provenance_sha256'],
    'input_provenance_file_sha256': _rawSha(provenancePath),
    'result_manifest_sha256': _rawSha(manifestPath),
    'evidence_mode': candidate['evidence_mode'],
    if (visual) ...{
      'baseline_status': manifest['baseline_status'],
      'baseline_set_sha256': manifest['baseline_set_sha256'],
      'baseline_approval_sha256': manifest['baseline_approval_sha256'],
      'pixel_diff_percent': candidate['evidence_mode'] == _releaseReady
          ? 0
          : null,
    } else ...{
      'standard': _a11yStandard,
      'critical_violations': cases.fold<int>(
        0,
        (total, raw) =>
            total + (_object(raw, 'case')['critical_violations'] as int),
      ),
      'serious_violations': cases.fold<int>(
        0,
        (total, raw) =>
            total + (_object(raw, 'case')['serious_violations'] as int),
      ),
    },
  };
  if (!visual &&
      (evidence['critical_violations'] != 0 ||
          evidence['serious_violations'] != 0)) {
    _fail('sanitized a11y evidence must have zero critical/serious violations');
  }
  _writePretty(outputPath, evidence);
  validateSanitizedEvidence(
    kind: kind,
    evidencePath: outputPath,
    candidatePath: candidatePath,
    provenancePath: provenancePath,
    manifestPath: manifestPath,
    canonicalCandidatePath: canonicalCandidatePath,
    canonicalCandidateSha256: canonicalCandidateSha256,
    releaseId: releaseId,
  );
  return evidence;
}

void validateSanitizedEvidence({
  required String kind,
  required String evidencePath,
  required String candidatePath,
  required String provenancePath,
  required String manifestPath,
  String? canonicalCandidatePath,
  String? canonicalCandidateSha256,
  String? releaseId,
}) {
  final visual = kind == 'visual';
  final evidence = _readObject(evidencePath);
  _exactKeys(
    evidence,
    visual ? _visualEvidenceKeys : _a11yEvidenceKeys,
    r'$evidence',
  );
  final candidate = _validateCandidateSpec(
    kind: kind,
    candidatePath: candidatePath,
    provenancePath: provenancePath,
  );
  if (candidate['evidence_mode'] == _releaseReady) {
    final provenance = validateInputProvenanceDocument(
      kind: kind,
      provenancePath: provenancePath,
    );
    final authentication = _object(
      provenance['baseline_authentication'],
      'provenance.baseline_authentication',
    );
    _exactValue(
      authentication['release_id'],
      releaseId,
      'baselineAuthentication.release_id',
    );
  }
  final manifest = validateResultManifestDocument(
    kind: kind,
    manifestPath: manifestPath,
  );
  for (final key in [
    'source_sha',
    'case_catalog_sha256',
    'case_catalog_version',
    'case_catalog_schema_version',
    'projection_contract_sha256',
    'fixture_ids',
    'case_count',
    'surface_case_counts',
    'capture_surface',
    'device_evidence',
    'input_provenance_sha256',
    'evidence_mode',
  ]) {
    _exactValue(candidate[key], manifest[key], 'candidate.$key');
  }
  final candidateSha = _evidenceCandidateSha(
    kind: kind,
    laneBinding: candidate,
    laneBindingPath: candidatePath,
    canonicalCandidatePath: canonicalCandidatePath,
    canonicalCandidateSha256: canonicalCandidateSha256,
    releaseId: releaseId,
  );
  for (final entry in <String, Object?>{
    'candidate_spec_sha256': candidateSha,
    'status': 'passed',
    'producer_run_id': candidate['producer_run_id'],
    'producer_run_attempt': candidate['producer_run_attempt'],
    'repository': candidate['repository'],
    'source_sha': candidate['source_sha'],
    'case_catalog_sha256': candidate['case_catalog_sha256'],
    'case_catalog_version': _catalogVersion,
    'case_catalog_schema_version': visual ? _visualVersion : _a11yVersion,
    'projection_contract_sha256':
        validateCatalog()['projection_contract_sha256'],
    'case_count': visual ? 96 : 24,
    'passed_case_count': visual ? 96 : 24,
    'failed_case_count': 0,
    'capture_surface': _captureSurface,
    'device_evidence': false,
    'input_provenance_sha256': candidate['input_provenance_sha256'],
    'input_provenance_file_sha256': _rawSha(provenancePath),
    'result_manifest_sha256': _rawSha(manifestPath),
    'evidence_mode': candidate['evidence_mode'],
  }.entries) {
    _exactValue(evidence[entry.key], entry.value, 'evidence.${entry.key}');
  }
  if (!_listEquals(
    _array(evidence['fixture_ids'], 'evidence.fixture_ids'),
    _fixtureIds,
  )) {
    _fail('evidence fixture order drifted');
  }
  if (!_mapEquals(
    _object(evidence['surface_case_counts'], 'evidence.surface_counts'),
    visual ? _visualSurfaceCounts : _a11ySurfaceCounts,
  )) {
    _fail('evidence surface counts drifted');
  }
  if (visual) {
    for (final key in [
      'baseline_status',
      'baseline_set_sha256',
      'baseline_approval_sha256',
    ]) {
      _exactValue(candidate[key], manifest[key], 'candidate.$key');
      _exactValue(evidence[key], manifest[key], 'evidence.$key');
    }
    _exactValue(
      evidence['pixel_diff_percent'],
      candidate['evidence_mode'] == _releaseReady ? 0 : null,
      'evidence.pixel_diff_percent',
    );
  } else {
    _exactValue(evidence['standard'], _a11yStandard, 'evidence.standard');
    final cases = _array(manifest['cases'], 'manifest.cases');
    for (final key in ['critical_violations', 'serious_violations']) {
      final total = cases.fold<int>(
        0,
        (sum, raw) => sum + _integer(_object(raw, 'case')[key], 'case.$key'),
      );
      _exactValue(evidence[key], total, 'evidence.$key');
      _exactValue(evidence[key], 0, 'evidence.$key');
    }
  }
}

void validateReleasePackage({
  required String kind,
  required String packageRoot,
  required String candidatePath,
  String? canonicalCandidatePath,
  String? canonicalCandidateSha256,
  String? releaseId,
}) {
  final visual = kind == 'visual';
  final root = Directory(packageRoot).absolute;
  validateReleasePackageLayout(kind: kind, packageRoot: packageRoot);
  final packagedCases = File.fromUri(
    root.uri.resolve('evidence/et13/generated/$kind-cases.v1.json'),
  );
  final sourceCases = File('evidence/et13/generated/$kind-cases.v1.json');
  if (!packagedCases.existsSync() ||
      !_listEquals(
        packagedCases.readAsBytesSync(),
        sourceCases.readAsBytesSync(),
      )) {
    _fail('packaged generated case catalog differs from source bytes');
  }
  validateSanitizedEvidence(
    kind: kind,
    evidencePath: File.fromUri(root.uri.resolve('evidence.json')).path,
    candidatePath: candidatePath,
    provenancePath: File.fromUri(
      root.uri.resolve('artifacts/et13/provenance.v1.json'),
    ).path,
    manifestPath: File.fromUri(
      root.uri.resolve(
        'artifacts/et13/${visual ? 'visual' : 'a11y'}-manifest.v1.json',
      ),
    ).path,
    canonicalCandidatePath: canonicalCandidatePath,
    canonicalCandidateSha256: canonicalCandidateSha256,
    releaseId: releaseId,
  );
}

/// Validates the archive layout separately so path/link mutation tests do not
/// need to synthesize trusted evidence payloads.
void validateReleasePackageLayout({
  required String kind,
  required String packageRoot,
}) {
  if (kind != 'visual' && kind != 'a11y') {
    _fail('kind must be visual or a11y');
  }
  final root = Directory(packageRoot).absolute;
  if (!root.existsSync()) _fail('release package root is absent');
  final expected = <String>{
    'evidence.json',
    'evidence/et13/generated/${kind}-cases.v1.json',
    'artifacts/et13/provenance.v1.json',
    'artifacts/et13/${kind}-manifest.v1.json',
  };
  const expectedDirectories = <String>{
    'artifacts',
    'artifacts/et13',
    'evidence',
    'evidence/et13',
    'evidence/et13/generated',
  };
  final actualFiles = <String>{};
  final actualDirectories = <String>{};
  final prefix = '${root.path}${Platform.pathSeparator}';
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    final relative = entity.absolute.path
        .substring(prefix.length)
        .replaceAll('\\', '/');
    final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      _fail('release package may not contain symbolic links');
    }
    if (type == FileSystemEntityType.file) actualFiles.add(relative);
    if (type == FileSystemEntityType.directory) {
      actualDirectories.add(relative);
    }
  }
  if (!_setEquals(expected, actualFiles) ||
      !_setEquals(expectedDirectories, actualDirectories)) {
    _fail('release package must contain exactly four canonical nested files');
  }
}

bool _setEquals(Set<Object?> left, Set<Object?> right) =>
    left.length == right.length && left.containsAll(right);

void _usage() {
  stderr.writeln(
    'Usage: dart run tools/et13_evidence.dart '
    '<generate|validate|build-marker|provenance|candidate|manifest|evidence|'
    'validate-release-inputs|validate-manifest|validate-review-manifest|'
    'validate-package> '
    '[--name=value ...]',
  );
}

Map<String, String> _options(Iterable<String> arguments) => <String, String>{
  for (final argument in arguments)
    if (argument.startsWith('--') && argument.contains('='))
      argument.substring(2, argument.indexOf('=')): argument.substring(
        argument.indexOf('=') + 1,
      ),
};

String _requiredOption(Map<String, String> options, String name) {
  final value = options[name];
  if (value == null || value.isEmpty) _fail('missing --$name');
  return value;
}

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    _usage();
    exitCode = 64;
    return;
  }
  try {
    switch (arguments.first) {
      case 'generate':
        writeGeneratedCatalogs();
        validateGeneratedCatalogs();
        stdout.writeln('ET13 generated catalogs: visual=96 a11y=24');
      case 'validate':
        validateCanonicalLineEndings();
        validateContractDocuments();
        validateCatalog();
        validateGeneratedCatalogs();
        validateAssets();
        validateRendererLock();
        stdout.writeln('ET13 catalog/assets/renderer: OK');
      case 'provenance':
        final options = _options(arguments.skip(1));
        final mode = _requiredOption(options, 'mode');
        _mode(mode, 'provenance.evidence_mode');
        Map<String, Object?>? baselineAuthentication;
        if (mode == _releaseReady) {
          baselineAuthentication = buildBaselineAuthentication(
            releaseId: _requiredOption(options, 'release-id'),
            sourceSha: _requiredOption(options, 'source-sha'),
            baselineRoot: _requiredOption(options, 'baseline-root'),
            approvalPath: _requiredOption(options, 'baseline-approval'),
            runId: _positiveInteger(
              _requiredOption(options, 'baseline-run-id'),
              'baseline-run-id',
            ),
            runAttempt: _positiveInteger(
              _requiredOption(options, 'baseline-run-attempt'),
              'baseline-run-attempt',
            ),
            artifactId: _positiveInteger(
              _requiredOption(options, 'baseline-artifact-id'),
              'baseline-artifact-id',
            ),
            artifactName: _requiredOption(options, 'baseline-artifact-name'),
            artifactArchiveSha256: _requiredOption(
              options,
              'baseline-artifact-archive-sha256',
            ),
            workflowSha256: _requiredOption(
              options,
              'baseline-workflow-sha256',
            ),
          );
        } else {
          const releaseOnly = <String>{
            'release-id',
            'baseline-root',
            'baseline-approval',
            'baseline-run-id',
            'baseline-run-attempt',
            'baseline-artifact-id',
            'baseline-artifact-name',
            'baseline-artifact-archive-sha256',
            'baseline-workflow-sha256',
          };
          if (options.keys.any(releaseOnly.contains)) {
            _fail('diagnostic provenance must not consume baseline inputs');
          }
        }
        final provenance = writeInputProvenance(
          kind: _requiredOption(options, 'kind'),
          sourceSha: _requiredOption(options, 'source-sha'),
          buildMarkerPath: _requiredOption(options, 'build-marker'),
          outputPath: _requiredOption(options, 'output'),
          baselineAuthentication: baselineAuthentication,
        );
        stdout.writeln(
          'ET13 ${options['kind']} input provenance: '
          '${provenance['input_provenance_sha256']}',
        );
      case 'build-marker':
        final options = _options(arguments.skip(1));
        writeBuildMarker(
          sourceSha: _requiredOption(options, 'source-sha'),
          outputPath: _requiredOption(options, 'output'),
          webRoot: _requiredOption(options, 'web-root'),
          adminRoot: _requiredOption(options, 'admin-root'),
          mobileRoot: _requiredOption(options, 'mobile-root'),
        );
        stdout.writeln('ET13 build marker: OK');
      case 'candidate':
        final options = _options(arguments.skip(1));
        writeCandidateSpec(
          kind: _requiredOption(options, 'kind'),
          sourceSha: _requiredOption(options, 'source-sha'),
          buildMarkerPath: _requiredOption(options, 'build-marker'),
          provenancePath: _requiredOption(options, 'provenance'),
          mode: _requiredOption(options, 'mode'),
          producerRunId: _requiredOption(options, 'producer-run-id'),
          producerRunAttempt: _requiredOption(options, 'producer-run-attempt'),
          repository: _requiredOption(options, 'repository'),
          outputPath: _requiredOption(options, 'output'),
          baselineRoot: options['baseline-root'],
          baselineApprovalPath: options['baseline-approval'],
        );
        stdout.writeln('ET13 ${options['kind']} candidate spec: OK');
      case 'manifest':
        final options = _options(arguments.skip(1));
        writeResultManifest(
          kind: _requiredOption(options, 'kind'),
          sourceSha: _requiredOption(options, 'source-sha'),
          buildMarkerPath: _requiredOption(options, 'build-marker'),
          provenancePath: _requiredOption(options, 'provenance'),
          artifactRoot: _requiredOption(options, 'artifact-root'),
          captureSummaryPath: _requiredOption(options, 'capture-summary'),
          mode: _requiredOption(options, 'mode'),
          outputPath: _requiredOption(options, 'output'),
          baselineRoot: options['baseline-root'],
          baselineApprovalPath: options['baseline-approval'],
        );
        stdout.writeln('ET13 ${options['kind']} result manifest: OK');
      case 'validate-release-inputs':
        final options = _options(arguments.skip(1));
        validateCanonicalReleaseInputs(
          canonicalCandidatePath: _requiredOption(
            options,
            'canonical-candidate',
          ),
          canonicalCandidateSha256: _requiredOption(
            options,
            'canonical-candidate-sha256',
          ),
          releaseId: _requiredOption(options, 'release-id'),
          visualCandidatePath: _requiredOption(options, 'visual-candidate'),
          visualProvenancePath: _requiredOption(options, 'visual-provenance'),
          a11yCandidatePath: _requiredOption(options, 'a11y-candidate'),
          a11yProvenancePath: _requiredOption(options, 'a11y-provenance'),
        );
        stdout.writeln('ET13 canonical release inputs: OK');
      case 'evidence':
        final options = _options(arguments.skip(1));
        writeSanitizedEvidence(
          kind: _requiredOption(options, 'kind'),
          candidatePath: _requiredOption(options, 'candidate'),
          provenancePath: _requiredOption(options, 'provenance'),
          manifestPath: _requiredOption(options, 'manifest'),
          outputPath: _requiredOption(options, 'output'),
          canonicalCandidatePath: options['canonical-candidate'],
          canonicalCandidateSha256: options['canonical-candidate-sha256'],
          releaseId: options['release-id'],
        );
        stdout.writeln('ET13 ${options['kind']} sanitized evidence: OK');
      case 'validate-manifest':
        final options = _options(arguments.skip(1));
        validateResultManifest(
          kind: _requiredOption(options, 'kind'),
          manifestPath: _requiredOption(options, 'manifest'),
          artifactRoot: _requiredOption(options, 'artifact-root'),
          buildMarkerPath: _requiredOption(options, 'build-marker'),
          provenancePath: _requiredOption(options, 'provenance'),
          baselineRoot: options['baseline-root'],
          baselineApprovalPath: options['baseline-approval'],
        );
        stdout.writeln('ET13 ${options['kind']} manifest: OK');
      case 'validate-review-manifest':
        final options = _options(arguments.skip(1));
        validateReviewManifest(
          kind: _requiredOption(options, 'kind'),
          manifestPath: _requiredOption(options, 'manifest'),
          artifactRoot: _requiredOption(options, 'artifact-root'),
          buildMarkerPath: _requiredOption(options, 'build-marker'),
          provenancePath: _requiredOption(options, 'provenance'),
        );
        stdout.writeln('ET13 ${options['kind']} review manifest: OK');
      case 'validate-package':
        final options = _options(arguments.skip(1));
        validateReleasePackage(
          kind: _requiredOption(options, 'kind'),
          packageRoot: _requiredOption(options, 'package-root'),
          candidatePath: _requiredOption(options, 'candidate'),
          canonicalCandidatePath: options['canonical-candidate'],
          canonicalCandidateSha256: options['canonical-candidate-sha256'],
          releaseId: options['release-id'],
        );
        stdout.writeln('ET13 ${options['kind']} release package: OK');
      default:
        _usage();
        exitCode = 64;
    }
  } on Object catch (error) {
    stderr.writeln('ET13 evidence contract failed: $error');
    exitCode = 1;
  }
}
