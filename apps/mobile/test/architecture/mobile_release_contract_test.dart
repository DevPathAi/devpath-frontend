import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../../tools/mobile_source_guard.dart' as source_guard;

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
      expect(workflow, contains('runs-on: ubuntu-24.04'));
      expect(workflow, contains('runs-on: macos-26'));
      expect(workflow, contains("java-version: '17.0.20+8'"));
      expect(
        workflow,
        contains(
          'OpenJDK Runtime Environment Temurin-17.0.20+8 '
          '(build 17.0.20+8)',
        ),
      );
      expect(workflow, isNot(contains('secrets.')));

      final wrapper = _read('android/gradle/wrapper/gradle-wrapper.properties');
      expect(
        wrapper,
        contains(
          'distributionSha256Sum='
          'b84e04fa845fecba48551f425957641074fcc00a88a84d2aae5808743b35fc85',
        ),
      );
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

  test('source guard rejects reviewed action SHA and count drift', () {
    final workflow = _read('../../.github/workflows/mobile.yml');
    expect(source_guard.mobileWorkflowActionViolation(workflow), isNull);

    final shaDrift = workflow.replaceFirst(
      'd23441a48e516b6c34aea4fa41551a30e30af803',
      '0000000000000000000000000000000000000000',
    );
    expect(
      source_guard.mobileWorkflowActionViolation(shaDrift),
      contains('actions/checkout must use reviewed pin'),
    );

    final countDrift =
        '$workflow\n'
        '      - uses: actions/setup-java@'
        'cf277c60eb25467037889841efdb72551f06f6c3 # v4.9.1\n';
    expect(
      source_guard.mobileWorkflowActionViolation(countDrift),
      contains('actions/setup-java must occur exactly 1 time(s)'),
    );
  });

  test('source guard rejects exact Xcode patch and build drift', () {
    final workflow = _read('../../.github/workflows/mobile.yml');
    expect(source_guard.mobileWorkflowToolchainViolation(workflow), isNull);

    expect(
      RegExp(
        r'^\s*xcodebuild -version\s*\|',
        multiLine: true,
      ).hasMatch(workflow),
      isFalse,
      reason:
          'xcodebuild must not feed grep -q under pipefail because grep can '
          'close the pipe before xcodebuild writes its second line',
    );
    expect(
      RegExp(
        r'^\s*apple_toolchain="\$\(xcodebuild -version\)"$',
        multiLine: true,
      ).allMatches(workflow),
      hasLength(1),
      reason: 'capture the exact two-line Xcode identity once',
    );
    expect(
      workflow,
      contains(
        'test "\${apple_toolchain}" = '
        "\$'Xcode 26.4.1\\nBuild version 17E202'",
      ),
    );

    final versionDrift = workflow.replaceFirst(
      "xcode-version: '26.4.1'",
      "xcode-version: '26.4'",
    );
    expect(
      source_guard.mobileWorkflowToolchainViolation(versionDrift),
      contains('Xcode 26.4.1'),
    );

    final buildDrift = workflow.replaceFirst('17E202', '17E999');
    expect(
      source_guard.mobileWorkflowToolchainViolation(buildDrift),
      contains('17E202'),
    );
  });

  test('source guard rejects exact Temurin patch and build drift', () {
    final workflow = _read('../../.github/workflows/mobile.yml');
    expect(source_guard.mobileWorkflowToolchainViolation(workflow), isNull);

    final versionDrift = workflow.replaceFirst(
      "java-version: '17.0.20+8'",
      "java-version: '17'",
    );
    expect(
      source_guard.mobileWorkflowToolchainViolation(versionDrift),
      contains('Temurin 17.0.20+8'),
    );

    final runtimeDrift = workflow.replaceFirst(
      'OpenJDK Runtime Environment Temurin-17.0.20+8 (build 17.0.20+8)',
      'OpenJDK Runtime Environment Temurin-17.0.19+10 (build 17.0.19+10)',
    );
    expect(
      source_guard.mobileWorkflowToolchainViolation(runtimeDrift),
      contains('Temurin 17.0.20+8'),
    );
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

  test('native delivery is opt-in and AppLinks is the only link owner', () {
    final android = _read('android/app/src/main/AndroidManifest.xml');
    final ios = _read('ios/Runner/Info.plist');
    final push = _read('lib/src/services/push_service.dart');
    final main = _read('lib/main.dart');

    expect(
      android,
      contains(
        'android:name="firebase_messaging_auto_init_enabled" '
        'android:value="false"',
      ),
    );
    expect(
      android,
      contains(
        'android:name="firebase_analytics_collection_enabled" '
        'android:value="false"',
      ),
    );
    expect(
      android,
      contains(
        'android:name="flutter_deeplinking_enabled" '
        'android:value="false"',
      ),
    );
    expect(ios, contains('<key>FirebaseMessagingAutoInitEnabled</key>'));
    expect(ios, contains('<key>FlutterDeepLinkingEnabled</key>'));
    expect(
      RegExp(
        r'<key>(FirebaseMessagingAutoInitEnabled|FlutterDeepLinkingEnabled)</key>\s*<false/>',
      ).allMatches(ios),
      hasLength(2),
    );
    expect(push, contains('Future<void> disableAutoInit()'));
    expect(push, isNot(contains('setAutoInitEnabled(true)')));
    expect(main, contains('setAutoInitEnabled(false)'));
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
