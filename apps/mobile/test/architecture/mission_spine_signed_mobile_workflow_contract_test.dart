import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/apksigner_certificate_parser.dart' as certificate_parser;

void main() {
  final workflow = File(
    '../../.github/workflows/mission-spine-signed-mobile-build.yml',
  );

  test('signed mobile producer is protected, pinned, and byte-derived', () {
    expect(workflow.existsSync(), isTrue);
    final source = workflow.readAsStringSync();

    expect(source, contains('workflow_dispatch:'));
    expect(source, contains('GITHUB_RUN_ATTEMPT'));
    expect(source, contains('protected approvals require attempt 1'));
    expect(source, contains('name: Sign Android release'));
    expect(source, contains('name: mission-spine-mobile-signing-android'));
    expect(source, contains('name: Sign iOS release'));
    expect(source, contains('name: mission-spine-mobile-signing-ios'));
    expect(source, contains('tools/mission_spine_protected_approval.mjs'));

    expect(source, contains("flutter-version: '3.44.1'"));
    expect(source, contains('924134a44c189315be2148659913dda1671cbe99'));
    expect(source, contains("java-version: '17.0.20+8'"));
    expect(source, contains("xcode-version: '26.4.1'"));
    expect(
      RegExp(r'^\s*xcodebuild -version\s*\|', multiLine: true).hasMatch(source),
      isFalse,
      reason: 'Xcode must not write into an early-closing grep under pipefail',
    );
    expect(source, contains(r'apple_toolchain="$(xcodebuild -version)"'));
    expect(
      source,
      contains(
        'test "\${apple_toolchain}" = '
        "\$'Xcode 26.4.1\\nBuild version 17E202'",
      ),
    );
    expect(source, contains('flutter build apk --release --no-pub'));
    expect(source, contains('flutter build ipa --release --no-pub'));
    final iosJob = source.substring(source.indexOf('  sign-ios:'));
    const disableSwiftPm = 'flutter config --no-enable-swift-package-manager';
    expect(RegExp(disableSwiftPm).allMatches(iosJob), hasLength(1));
    expect(
      iosJob.indexOf(disableSwiftPm),
      lessThan(iosJob.indexOf('flutter pub get --enforce-lockfile')),
      reason: 'the protected iOS build must resolve plugins with CocoaPods',
    );
    expect(source, contains('--dart-define=USE_MOCK=false'));
    expect(source, contains('API_BASE_URL=https://api.leva.ai.kr'));
    expect(source, contains('WEB_APP_URL=https://app.leva.ai.kr'));

    expect(source, contains(r'"${apksigner}" sign'));
    expect(source, contains('verify --verbose --print-certs'));
    expect(
      source,
      contains('dart run apps/mobile/tools/apksigner_certificate_parser.dart'),
    );
    expect(
      source,
      isNot(contains('Signer #1 certificate SHA-256 digest')),
      reason: 'current apksigner labels the certificate as V3.0 Signer',
    );
    expect(source, contains('signing_certificate_sha256'));
    expect(source, contains("'method': 'ad-hoc'"));
    expect(source, contains('CODE_SIGN_STYLE = Manual'));
    expect(source, contains('PROVISIONING_PROFILE_SPECIFIER = %s'));
    expect(source, contains('xcodebuild -showBuildSettings'));
    expect(source, contains('codesign --verify --deep --strict'));
    expect(source, contains('provisioning_profile_uuid'));
    expect(source, contains('provisioning_profile_expires_at'));
    expect(source, contains("jq -r '.get_task_allow'"));
    expect(source, contains("jq -r '.provisions_all_devices'"));
    expect(source, isNot(contains("jq -er '.get_task_allow'")));
    expect(source, contains('protected_manual_at_test_devices'));
    expect(
      source,
      contains("sed -n 's/^version: //p' apps/mobile/pubspec.yaml"),
    );
    expect(source, isNot(contains('play_app_signing: true')));
    expect(source, isNot(contains('app-store')));

    expect(
      source,
      contains(r'${{ inputs.release_id }}-signed-mobile-build-run-'),
    );
    expect(source, contains('build-provenance.v1.json'));
    expect(source, contains('mobile/android/leva-release.apk'));
    expect(source, contains('mobile/ios/leva-release.ipa'));
    expect(source, contains('validate-signed-bundle'));
    expect(source, contains('if-no-files-found: error'));
    expect(source, contains('overwrite: false'));
  });

  test('every signed mobile workflow action uses an immutable pin', () {
    expect(workflow.existsSync(), isTrue);
    final source = workflow.readAsStringSync();
    final uses = RegExp(
      r'^\s*(?:-\s+)?uses: ([^@\s]+)@([^\s#]+)(?:\s+#\s*(\S+))?\s*$',
      multiLine: true,
    ).allMatches(source).toList();
    expect(uses, isNotEmpty);
    for (final use in uses) {
      expect(use.group(2), matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(use.group(3), matches(RegExp(r'^v\d+(?:\.\d+){0,2}$')));
    }
  });

  test('live apksigner V3 output yields the single signing certificate', () {
    const output = '''
Verifies
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
Number of signers: 1
V3.0 Signer: certificate DN: CN=DevPathAi Release Test
V3.0 Signer: certificate SHA-256 digest: F767C648E8439785B9058A3EF70C72006AE06174CE4A56FF601B59CCAA9D5347
''';

    expect(
      certificate_parser.parseSingleCertificateSha256(output),
      'f767c648e8439785b9058a3ef70c72006ae06174ce4a56ff601b59ccaa9d5347',
    );
  });

  test('certificate parser rejects multiple distinct signers', () {
    const output = '''
Number of signers: 2
Signer #1 certificate SHA-256 digest: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
Signer #2 certificate SHA-256 digest: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
''';

    expect(
      () => certificate_parser.parseSingleCertificateSha256(output),
      throwsFormatException,
    );
  });
}
