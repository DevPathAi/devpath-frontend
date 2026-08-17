import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File(
    '../../.github/workflows/mission-spine-manual-at-evidence.yml',
  );

  test('manual AT producer exposes only frozen dispatch coordinates', () {
    expect(workflow.existsSync(), isTrue);
    final source = workflow.readAsStringSync();
    expect(source, contains('\non:\n  workflow_dispatch:\n'));
    for (final input in [
      'release_id',
      'candidate_run_id',
      'candidate_run_attempt',
      'candidate_artifact_id',
      'candidate_spec_sha256',
    ]) {
      expect(source, contains('      $input:'));
    }
    expect(source, isNot(contains('signed_artifact_id:')));
    expect(source, isNot(contains('reviewer:')));
    expect(source, isNot(contains('case_count:')));
  });

  test(
    'manual AT lanes are protected and jointly publish sanitized artifacts',
    () {
      expect(workflow.existsSync(), isTrue);
      final source = workflow.readAsStringSync();
      for (final binding in {
        'manual-at-nvda': 'Approve manual NVDA evidence',
        'manual-at-voiceover': 'Approve manual VoiceOver evidence',
        'manual-at-talkback': 'Approve manual TalkBack evidence',
      }.entries) {
        expect(source, contains('name: ${binding.key}'));
        expect(source, contains('name: ${binding.value}'));
      }
      expect(source, contains('protected approvals require attempt 1'));
      expect(source, contains('tools/et13/verify_external_artifact.mjs'));
      expect(source, contains('candidate-source'));
      expect(source, contains('validate-manual-inputs'));
      expect(source, contains('validate-manual-packages'));
      expect(source, contains('build-provenance.v1.json'));
      expect(source, contains('mobile/android/leva-release.apk'));
      expect(source, contains('mobile/ios/leva-release.ipa'));
      expect(source, contains('unsealable-manual-at-review'));
      const releaseInput = r'${{ inputs.release_id }}';
      for (final lane in ['nvda', 'voiceover', 'talkback']) {
        expect(source, contains('$releaseInput-manual-$lane-run-'));
      }
      expect(source, contains('overwrite: false'));
      expect(source, contains('if-no-files-found: error'));
    },
  );

  test('manual AT workflow action references are immutable pins', () {
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
}
