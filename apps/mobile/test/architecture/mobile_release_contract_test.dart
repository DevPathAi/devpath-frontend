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

  test('release Android build cannot silently use the debug signing key', () {
    final gradle = _read('android/app/build.gradle.kts');
    final properties = _read('android/gradle.properties');

    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(properties, contains('kotlin.incremental=false'));
  });

  test('App/Universal Link declarations cover canonical Today and Content', () {
    final android = _read('android/app/src/main/AndroidManifest.xml');
    final ios = _read('ios/Runner/Runner.entitlements');
    final xcodeProject = _read('ios/Runner.xcodeproj/project.pbxproj');

    expect(android, contains('android:autoVerify="true"'));
    expect(android, contains('android:host="app.devpath.ai"'));
    expect(android, contains('android:pathPrefix="/path/"'));
    expect(android, contains('android:pathPrefix="/mission/"'));
    expect(ios, contains('applinks:app.devpath.ai'));
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'.allMatches(
        xcodeProject,
      ),
      hasLength(3),
    );
  });
}
