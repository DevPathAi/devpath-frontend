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
    expect(
      manifest,
      contains('android:pathAdvancedPattern="/path/[1-9][0-9]*/today"'),
    );
    expect(
      manifest,
      contains(
        'android:pathAdvancedPattern="/mission/[1-9][0-9]*/content/[1-9][0-9]*"',
      ),
    );
    expect(manifest, isNot(contains('android:pathPattern=')));
    expect(manifest, isNot(contains('android:pathPrefix="/mission/"')));
    expect(entitlements, contains('applinks:app.leva.ai.kr'));
  });

  test(
    'Android intent filters resolve canonical shapes and reject web-only paths',
    () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final patterns = RegExp(r'android:pathAdvancedPattern="([^"]+)"')
          .allMatches(manifest)
          .map((match) => RegExp('^${match.group(1)}\$'))
          .toList();
      bool resolves(String path) =>
          patterns.any((pattern) => pattern.hasMatch(path));

      expect(resolves('/path/301/today'), isTrue);
      expect(resolves('/mission/302/content/77'), isTrue);
      for (final rejected in [
        '/mission/302/sandbox/content/77',
        '/mission/302/mentor/content/77',
        '/mission/302/review',
        '/mission/302/extra/content/77',
        '/path/301/extra/today',
        '/mission/0/content/77',
      ]) {
        expect(resolves(rejected), isFalse, reason: rejected);
      }
      expect(
        _read('android/app/src/main/res/values/bools.xml'),
        contains('<bool name="enable_exact_app_links">false</bool>'),
      );
      expect(
        _read('android/app/src/main/res/values-v31/bools.xml'),
        contains('<bool name="enable_exact_app_links">true</bool>'),
      );
    },
  );

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

  test(
    'push lifecycle requests consented permission, rotates, and unregisters',
    () {
      final push = _read('lib/src/services/push_service.dart');
      final registrar = _read(
        'lib/src/features/notifications/application/device_registrar.dart',
      );
      final app = _read('lib/src/app/app.dart');
      final auth = _read(
        'lib/src/features/auth/application/auth_controller.dart',
      );

      for (final marker in [
        'requestPermission',
        'tokenRefresh',
        'deleteToken',
      ]) {
        expect(push, contains(marker), reason: marker);
      }
      expect(registrar, contains("delete<dynamic>('/notifications/devices'"));
      expect(registrar, contains('requestPermission'));
      expect(registrar, contains('tokenRefresh'));
      expect(app, contains('ConsentStatus.done'));
      expect(auth, contains('.unregister('));
    },
  );

  test(
    'FCM documentation uses the preserved iOS bundle identifier honestly',
    () {
      final docs = _read('docs/FCM_SETUP.md');
      final example = _read('ios/Runner/GoogleService-Info.plist.example');

      expect(docs, contains('ai.devpath.devpathMobile'));
      expect(example, contains('ai.devpath.devpathMobile'));
      expect(docs, contains('requestPermission'));
      expect(docs, contains('onTokenRefresh'));
      expect(docs, contains('unregister'));
    },
  );

  test('source guard scans main.dart and blocks browser-only APIs', () {
    final guard = _read('../../tools/mobile_source_guard.dart');

    expect(guard, contains("apps/mobile/lib'"));
    for (final marker in [
      'dart:html',
      'dart:js',
      'localStorage',
      'sessionStorage',
    ]) {
      expect(guard, contains(marker), reason: marker);
    }
  });
}
