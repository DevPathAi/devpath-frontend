import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _catalogVersion = 'leva.et13.catalog.v1';
const _visualVersion = 'leva.et13.visual-cases.v1';
const _a11yVersion = 'leva.et13.a11y-cases.v1';
const _pendingReview = 'pending_external_review';
const _captureSurface = 'flutter_web_release_projection';
const _externalAccessibilityStatus = 'not_satisfied';
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

void _exactValue(Object? actual, Object? expected, String path) {
  if (actual != expected) _fail('$path must be $expected; found $actual');
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

Map<String, Object?> validateCatalog() {
  const path = 'evidence/et13/catalog.v1.json';
  final catalog = _readObject(path);
  _exactKeys(catalog, const [
    'schema_version',
    'fixtures',
    'visual_matrix',
    'a11y_matrix',
    'baseline_status',
  ], r'$catalog');
  if (catalog['schema_version'] != _catalogVersion) {
    _fail('catalog schema_version must be $_catalogVersion');
  }
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
    'fixture_ids': _fixtureIds,
    'case_count': 96,
    'surface_case_counts': _visualSurfaceCounts,
    'cases': visualCases,
  };
  final a11y = <String, Object?>{
    'schema_version': _a11yVersion,
    'case_catalog_version': _catalogVersion,
    'catalog_sha256': catalogSha,
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

String _gitOutput(List<String> arguments) {
  final result = Process.runSync('git', arguments, runInShell: false);
  if (result.exitCode != 0) {
    _fail('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

void validateSourceIdentity(String sourceSha, String buildMarkerPath) {
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sourceSha) ||
      sourceSha == '0000000000000000000000000000000000000000') {
    _fail('source SHA must be a non-zero 40-character lowercase git SHA');
  }
  final head = _gitOutput(['rev-parse', '--verify', 'HEAD']);
  if (sourceSha != head) {
    _fail('source SHA $sourceSha does not match clean git HEAD $head');
  }
  final trackedStatus = _gitOutput([
    'status',
    '--porcelain=v1',
    '--untracked-files=no',
  ]);
  if (trackedStatus.isNotEmpty) {
    _fail('tracked source must be clean before provenance is computed');
  }

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
  }
}

Map<String, Object?> inputProvenance(
  String kind,
  String sourceSha,
  String buildMarkerPath,
) {
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
    'assets_lock_sha256': _rawSha('evidence/et13/assets.lock.json'),
    'renderer_lock_sha256': _rawSha('evidence/et13/renderer.lock.json'),
    'renderer_image_digest': renderer['manifest_digest'],
    'build_marker_sha256': _rawSha(buildMarkerPath),
  };
  return <String, Object?>{
    ...inputs,
    'provenance_sha256': _canonicalSha(inputs),
  };
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

void validateResultManifest({
  required String kind,
  required String manifestPath,
  required String artifactRoot,
  required String buildMarkerPath,
}) {
  final visual = kind == 'visual';
  if (!visual && kind != 'a11y') _fail('kind must be visual or a11y');
  final manifest = _readObject(manifestPath);
  _exactKeys(manifest, const [
    'schema_version',
    'case_catalog_version',
    'fixture_ids',
    'source_sha',
    'catalog_sha256',
    'case_catalog_sha256',
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
    'baseline_status',
    'case_count',
    'surface_case_counts',
    'cases',
  ], r'$manifest');

  final casePath = visual
      ? 'evidence/et13/generated/visual-cases.v1.json'
      : 'evidence/et13/generated/a11y-cases.v1.json';
  final generated = _readObject(casePath);
  final expectedCases = _array(generated['cases'], 'generated.cases');
  final expectedCount = visual ? 96 : 24;
  final expectedSurfaceCounts = visual
      ? _visualSurfaceCounts
      : _a11ySurfaceCounts;
  final expectedSchema = visual
      ? 'leva.et13.visual-manifest.v1'
      : 'leva.et13.a11y-manifest.v1';
  _exactValue(manifest['schema_version'], expectedSchema, 'manifest.schema');
  _exactValue(
    manifest['case_catalog_version'],
    _catalogVersion,
    'manifest.case_catalog_version',
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
  final provenance = inputProvenance(kind, sourceSha, buildMarkerPath);
  _exactValue(
    manifest['input_provenance_sha256'],
    provenance['provenance_sha256'],
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
    'baseline_status': _pendingReview,
  }.entries) {
    _exactValue(manifest[entry.key], entry.value, 'manifest.${entry.key}');
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
      visual
          ? const ['case_id', 'artifact_path', 'sha256', 'bytes']
          : const [
              'case_id',
              'artifact_path',
              'sha256',
              'bytes',
              'standard',
              'critical_violations',
              'serious_violations',
              'other_violations',
              'passes',
              'incomplete',
            ],
      'manifest.cases[$index]',
    );
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
      final signature = prefix.readSync(8);
      prefix.closeSync();
      if (!_listEquals(signature, pngSignature)) {
        _fail('case[$index] is not a PNG artifact');
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

bool _setEquals(Set<Object?> left, Set<Object?> right) =>
    left.length == right.length && left.containsAll(right);

void _usage() {
  stderr.writeln(
    'Usage: dart run tools/et13_evidence.dart '
    '<generate|validate|provenance|validate-manifest> '
    '[--kind=visual|a11y --source-sha=<sha> --build-marker=<path> '
    '--manifest=<path> --artifact-root=<path>]',
  );
}

Map<String, String> _options(Iterable<String> arguments) => <String, String>{
  for (final argument in arguments)
    if (argument.startsWith('--') && argument.contains('='))
      argument.substring(2, argument.indexOf('=')): argument.substring(
        argument.indexOf('=') + 1,
      ),
};

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
        validateCatalog();
        validateGeneratedCatalogs();
        validateAssets();
        validateRendererLock();
        stdout.writeln('ET13 catalog/assets/renderer: OK');
      case 'provenance':
        final options = _options(arguments.skip(1));
        stdout.write(
          _pretty(
            inputProvenance(
              options['kind'] ?? '',
              options['source-sha'] ?? '',
              options['build-marker'] ?? '',
            ),
          ),
        );
      case 'validate-manifest':
        final options = _options(arguments.skip(1));
        validateResultManifest(
          kind: options['kind'] ?? '',
          manifestPath: options['manifest'] ?? '',
          artifactRoot: options['artifact-root'] ?? '',
          buildMarkerPath: options['build-marker'] ?? '',
        );
        stdout.writeln('ET13 ${options['kind']} manifest: OK');
      default:
        _usage();
        exitCode = 64;
    }
  } on Object catch (error) {
    stderr.writeln('ET13 evidence contract failed: $error');
    exitCode = 1;
  }
}
