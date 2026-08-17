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
      contains('android:enabled="@bool/enable_exact_app_links"'),
    );
    expect(
      manifest,
      contains('android:pathAdvancedPattern="/path/[1-9][0-9]{0,14}/today"'),
    );
    expect(
      manifest,
      contains(
        'android:pathAdvancedPattern="/mission/[1-9][0-9]{0,14}/content/[1-9][0-9]{0,14}"',
      ),
    );
    expect(
      manifest,
      contains('<uri-relative-filter-group android:allow="false">'),
    );
    expect(manifest, contains('android:queryPattern=".*"'));
    expect(manifest, contains('android:fragmentPattern=".*"'));
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
      bool resolves(String rawUri) {
        final uri = Uri.parse(rawUri);
        if (uri.scheme != 'https' ||
            uri.host != 'app.leva.ai.kr' ||
            uri.hasQuery ||
            uri.hasFragment) {
          return false;
        }
        return patterns.any((pattern) => pattern.hasMatch(uri.path));
      }

      expect(resolves('https://app.leva.ai.kr/path/301/today'), isTrue);
      expect(
        resolves('https://app.leva.ai.kr/mission/999999999999999/content/77'),
        isTrue,
      );
      for (final rejected in [
        'https://app.leva.ai.kr/mission/302/sandbox/content/77',
        'https://app.leva.ai.kr/mission/302/mentor/content/77',
        'https://app.leva.ai.kr/mission/302/review',
        'https://app.leva.ai.kr/mission/302/extra/content/77',
        'https://app.leva.ai.kr/path/301/extra/today',
        'https://app.leva.ai.kr/mission/0/content/77',
        'https://app.leva.ai.kr/path/9007199254740992/today',
        'https://app.leva.ai.kr/path/301/today?source=push',
        'https://app.leva.ai.kr/mission/302/content/9007199254740992',
        'https://app.leva.ai.kr/mission/302/content/77?source=push',
        'https://app.leva.ai.kr/path/301/today#content',
      ]) {
        expect(resolves(rejected), isFalse, reason: rejected);
      }
      expect(
        _read('android/app/src/main/res/values/bools.xml'),
        contains('<bool name="enable_exact_app_links">false</bool>'),
      );
      expect(
        _read('android/app/src/main/res/values-v35/bools.xml'),
        contains('<bool name="enable_exact_app_links">true</bool>'),
      );
      expect(
        Directory('android/app/src/main/res/values-v31').existsSync(),
        isFalse,
      );
    },
  );

  test('Android resolver probe locks canonical and rejected URI evidence', () {
    final probe = _read('tools/mobile_android_link_contract.dart');

    for (final marker in [
      'cmd',
      'package',
      'resolve-activity',
      'MissionLinkActivity',
      'https://app.leva.ai.kr/path/301/today',
      'https://app.leva.ai.kr/path/9007199254740992/today',
      'https://app.leva.ai.kr/path/301/today?source=push',
      'https://app.leva.ai.kr/mission/302/content/9007199254740992',
      'https://app.leva.ai.kr/mission/302/content/77?source=push',
      'https://app.leva.ai.kr/path/301/today#content',
      '--adb',
    ]) {
      expect(probe, contains(marker), reason: marker);
    }
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
      expect(registrar, contains('delete<dynamic>'));
      expect(registrar, contains("'/notifications/devices'"));
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

  test(
    'router consumes each pending generation with CAS, without a global latch',
    () {
      final router = _read('lib/src/app/router.dart');

      expect(router, contains('consumeIfMatches'));
      expect(router, contains('expectedGeneration'));
      expect(router, isNot(contains('pendingConsumeScheduled')));
    },
  );
}
