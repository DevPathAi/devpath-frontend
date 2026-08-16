import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _catalogVersion = 'leva.et13.catalog.v1';
const _visualVersion = 'leva.et13.visual-cases.v1';
const _a11yVersion = 'leva.et13.a11y-cases.v1';
const _pendingReview = 'pending_external_review';
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

void validateGeneratedCatalogs() {
  final generated = generateCatalogs();
  final expected = <String, String>{
    'evidence/et13/generated/visual-cases.v1.json': _pretty(generated.visual),
    'evidence/et13/generated/a11y-cases.v1.json': _pretty(generated.a11y),
  };
  for (final entry in expected.entries) {
    final file = File(entry.key);
    if (!file.existsSync() || file.readAsStringSync() != entry.value) {
      _fail('${entry.key} is missing or not canonical; run generate');
    }
  }
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
  const ids = [
    'pretendard-400',
    'pretendard-500',
    'pretendard-600',
    'pretendard-700',
    'd2coding',
    'material-symbols-rounded',
    'material-icons',
    'monaco-editor',
  ];
  final actualIds = <String>[];
  for (final raw in assets) {
    final asset = _object(raw, 'asset');
    final id = _string(asset['id'], 'asset.id');
    actualIds.add(id);
    final path = _string(asset['path'], '$id.path');
    final expectedBytes = _integer(asset['bytes'], '$id.bytes');
    final expectedSha = _string(asset['sha256'], '$id.sha256');
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
    } else {
      final file = _resolvedAssetFile(asset);
      if (!file.existsSync() ||
          file.lengthSync() != expectedBytes ||
          sha256.convert(file.readAsBytesSync()).toString() != expectedSha) {
        _fail('$id does not match its exact asset lock: ${file.path}');
      }
    }
  }
  if (!_listEquals(actualIds, ids)) _fail('asset order drifted: $actualIds');
  final workspaceLockSha = _rawSha('pubspec.lock');
  if (workspaceLockSha !=
      '8300e2b167174209f291e994e7e094ada7af819ba6ba05a9d4e2fdc004cf38c6') {
    _fail('workspace lock hash drifted from the approved renderer input');
  }
}

Map<String, Object?> inputProvenance(String kind, String sourceSha) {
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sourceSha)) {
    _fail('source SHA must be 40 lowercase hex characters');
  }
  validateGeneratedCatalogs();
  validateAssets();
  final casePath = kind == 'visual'
      ? 'evidence/et13/generated/visual-cases.v1.json'
      : kind == 'a11y'
      ? 'evidence/et13/generated/a11y-cases.v1.json'
      : _fail('kind must be visual or a11y');
  final renderer = _readObject('evidence/et13/renderer.lock.json');
  final inputs = <String, Object?>{
    'schema_version': 'leva.et13.input-provenance.v1',
    'kind': kind,
    'source_sha': sourceSha,
    'catalog_sha256': _rawSha('evidence/et13/catalog.v1.json'),
    'case_catalog_sha256': _rawSha(casePath),
    'assets_lock_sha256': _rawSha('evidence/et13/assets.lock.json'),
    'renderer_lock_sha256': _rawSha('evidence/et13/renderer.lock.json'),
    'renderer_image_digest': renderer['manifest_digest'],
  };
  return <String, Object?>{
    ...inputs,
    'provenance_sha256': _canonicalSha(inputs),
  };
}

void _usage() {
  stderr.writeln(
    'Usage: dart run tools/et13_evidence.dart '
    '<generate|validate|provenance> [--kind=visual|a11y --source-sha=<sha>]',
  );
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
        validateCatalog();
        validateGeneratedCatalogs();
        validateAssets();
        stdout.writeln('ET13 catalog/assets: OK');
      case 'provenance':
        final options = <String, String>{
          for (final argument in arguments.skip(1))
            if (argument.startsWith('--') && argument.contains('='))
              argument.substring(2, argument.indexOf('=')): argument.substring(
                argument.indexOf('=') + 1,
              ),
        };
        stdout.write(
          _pretty(
            inputProvenance(options['kind'] ?? '', options['source-sha'] ?? ''),
          ),
        );
      default:
        _usage();
        exitCode = 64;
    }
  } on Object catch (error) {
    stderr.writeln('ET13 evidence contract failed: $error');
    exitCode = 1;
  }
}
