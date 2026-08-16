import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('production origin and native filters are exact Today+Content only', () {
    final config = _read('lib/src/app/app_config.dart');
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final entitlements = Directory('ios/Runner')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.entitlements'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(config, contains('https://app.leva.ai.kr'));
    expect(config, isNot(contains('https://app.devpath.ai')));
    expect(manifest, contains('android:host="app.leva.ai.kr"'));
    expect(manifest, contains('android:pathPattern="/path/.*/today"'));
    expect(manifest, contains('android:pathPattern="/mission/.*/content/.*"'));
    expect(manifest, isNot(contains('android:pathPrefix="/mission/"')));
    expect(entitlements, contains('applinks:app.leva.ai.kr'));
  });

  test('CI compiles mock+production and asserts all exact toolchains', () {
    final workflow = _read('../../.github/workflows/mobile.yml');
    for (final marker in [
      'frameworkVersion',
      'dartSdkVersion',
      'java -version',
      'ANDROID_HOME',
      'xcodebuild -version',
      '--dart-define=USE_MOCK=true',
      '--dart-define=USE_MOCK=false',
    ]) {
      expect(workflow, contains(marker), reason: marker);
    }
  });

  test(
    'production mobile source cannot embed mock fixtures or web-only routes',
    () {
      final source = Directory('lib/src')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      for (final route in ['/sandbox', '/mentor', '/review', '/claim']) {
        expect(source, isNot(contains("GoRoute(path: '$route")), reason: route);
      }
    },
  );
}
