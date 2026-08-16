import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'native CI pins the exact Flutter source and emits unsigned build evidence',
    () {
      final workflow = _read('../../.github/workflows/mobile.yml');

      expect(workflow, contains("flutter-version: '3.44.1'"));
      expect(workflow, contains('dart run tools/mobile_source_guard.dart'));
      expect(workflow, contains('flutter build apk --release --no-pub'));
      expect(workflow, contains('apksigner'));
      expect(workflow, contains('--no-codesign'));
      expect(workflow, contains('pubspec.lock'));
      expect(workflow, isNot(contains('secrets.')));
    },
  );

  test('every external mobile CI action is immutable full-SHA pinned', () {
    final workflow = _read('../../.github/workflows/mobile.yml');
    final uses = RegExp(
      r'^\s*(?:-\s+)?uses: ([^@\s]+)@([^\s#]+)(?:\s+#\s*(\S+))?\s*$',
      multiLine: true,
    ).allMatches(workflow).toList();

    expect(uses, isNotEmpty);
    expect(uses.map((match) => match.group(1)).toSet(), {
      'actions/checkout',
      'subosito/flutter-action',
      'actions/setup-java',
      'actions/upload-artifact',
      'maxim-lobanov/setup-xcode',
    });
    for (final use in uses) {
      expect(
        use.group(2),
        matches(RegExp(r'^[0-9a-f]{40}$')),
        reason: '${use.group(1)} must use an immutable commit SHA',
      );
      expect(
        use.group(3),
        matches(RegExp(r'^v\d+(?:\.\d+){0,2}$')),
        reason: '${use.group(1)} must retain a human-readable version comment',
      );
    }
  });

  test('release Android build cannot silently use the debug signing key', () {
    final gradle = _read('android/app/build.gradle.kts');
    final properties = _read('android/gradle.properties');

    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(properties, contains('kotlin.incremental=false'));
  });

  test('App/Universal Link declarations cover canonical Today and Content', () {
    final android = _read('android/app/src/main/AndroidManifest.xml');
    final iosDebug = _read('ios/Runner/RunnerDebug.entitlements');
    final iosRelease = _read('ios/Runner/RunnerRelease.entitlements');
    final xcodeProject = _read('ios/Runner.xcodeproj/project.pbxproj');

    expect(android, contains('android:autoVerify="true"'));
    expect(android, contains('android:host="app.leva.ai.kr"'));
    expect(
      android,
      contains('android:pathAdvancedPattern="/path/[1-9][0-9]{0,14}/today"'),
    );
    expect(
      android,
      contains(
        'android:pathAdvancedPattern="/mission/[1-9][0-9]{0,14}/content/[1-9][0-9]{0,14}"',
      ),
    );
    expect(android, contains('android:queryPattern=".*"'));
    expect(android, contains('android:fragmentPattern=".*"'));
    expect(android, isNot(contains('android:pathPrefix="/mission/"')));
    expect(iosDebug, contains('applinks:app.leva.ai.kr'));
    expect(iosDebug, contains('<string>development</string>'));
    expect(iosRelease, contains('applinks:app.leva.ai.kr'));
    expect(iosRelease, contains('<string>production</string>'));
    expect(_runnerEntitlements(xcodeProject), {
      'Debug': 'Runner/RunnerDebug.entitlements',
      'Release': 'Runner/RunnerRelease.entitlements',
      'Profile': 'Runner/RunnerRelease.entitlements',
    });
  });
}

Map<String, String> _runnerEntitlements(String project) {
  final section = project
      .split('/* Begin XCBuildConfiguration section */')[1]
      .split('/* End XCBuildConfiguration section */')[0];
  final result = <String, String>{};
  final blocks = RegExp(
    r'/\* (Debug|Release|Profile) \*/ = \{(.*?)\n\s*\};',
    dotAll: true,
  ).allMatches(section);
  for (final block in blocks) {
    final body = block.group(2)!;
    if (!body.contains(
      'PRODUCT_BUNDLE_IDENTIFIER = ai.devpath.devpathMobile;',
    )) {
      continue;
    }
    final entitlement = RegExp(
      r'CODE_SIGN_ENTITLEMENTS = ([^;]+);',
    ).firstMatch(body);
    result[block.group(1)!] = entitlement?.group(1) ?? '';
  }
  return result;
}
