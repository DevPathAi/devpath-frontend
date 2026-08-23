import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File(
    '../../.github/workflows/mission-spine-manual-at-evidence.yml',
  );

  test('manual AT producer exposes only frozen dispatch coordinates', () {
    expect(workflow.existsSync(), isTrue);
    final source = workflow.readAsStringSync().replaceAll('\r\n', '\n');
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
      final source = workflow.readAsStringSync().replaceAll('\r\n', '\n');
      for (final binding in {
        'manual-at-nvda': 'Approve manual NVDA evidence',
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
      expect(source, contains('build-provenance.v2.json'));
      expect(source, contains('mobile/android/leva-release.apk'));
      expect(source, isNot(contains('manual-at-voiceover')));
      expect(source, isNot(contains('mobile/ios')));
      expect(source, isNot(contains('signed_ipa')));
      expect(source, contains('unsealable-manual-at-review'));
      const releaseInput = r'${{ inputs.release_id }}';
      for (final lane in ['nvda', 'talkback']) {
        expect(source, contains('$releaseInput-manual-$lane-run-'));
      }
      expect(source, contains('overwrite: false'));
      expect(source, contains('if-no-files-found: error'));
    },
  );

  test('manual AT input authentication owns the read-only App boundary', () {
    final source = workflow.readAsStringSync().replaceAll('\r\n', '\n');
    final authenticateStart = source.indexOf('  authenticate-inputs:');
    final firstApprovalStart = source.indexOf('\n  approve-nvda:');
    expect(authenticateStart, greaterThanOrEqualTo(0));
    expect(firstApprovalStart, greaterThan(authenticateStart));
    final authenticate = source.substring(
      authenticateStart,
      firstApprovalStart,
    );

    expect(authenticate, contains('name: mission-spine-manual-at-auth'));
    expect(
      authenticate,
      contains("test \"\${GITHUB_EVENT_NAME}\" = workflow_dispatch"),
    );
    expect(authenticate, contains("test \"\${GITHUB_REF}\" = refs/heads/main"));
    expect(authenticate, contains("test \"\${GITHUB_RUN_ATTEMPT}\" = 1"));
    expect(authenticate, contains('persist-credentials: false'));
    expect(authenticate, contains('owner: DevPathAi'));
    expect(
      authenticate,
      contains('secrets.MISSION_SPINE_EVIDENCE_READER_APP_ID'),
    );
    expect(
      authenticate,
      contains('secrets.MISSION_SPINE_EVIDENCE_READER_APP_PRIVATE_KEY'),
    );
    expect(authenticate, contains('permission-actions: read'));
    expect(authenticate, contains('permission-contents: read'));
    expect(authenticate, isNot(contains('permission-actions: write')));
    expect(authenticate, isNot(contains('permission-contents: write')));
    expect(authenticate, isNot(contains('permission-administration:')));
    expect(authenticate, isNot(contains('repositories:')));
    expect(authenticate, contains('steps.gitops-token.outputs.app-slug'));
    expect(authenticate, contains('devpath-evidence-reader'));
    expect(authenticate, contains('/installation/repositories?per_page=100'));
    expect(authenticate, contains(".total_count == 1"));
    expect(
      authenticate,
      contains(".repositories[0].full_name == \"DevPathAi/devpath-gitops\""),
    );
    final sourceGuard = authenticate.indexOf(
      'Reject branch, source, and rerun ambiguity',
    );
    final protectedApproval = authenticate.indexOf(
      'Authenticate protected input-reader approval',
    );
    final mint = authenticate.indexOf('Mint read-only GitOps candidate token');
    final inventory = authenticate.indexOf(
      'Verify evidence reader App is GitOps-only',
    );
    final candidate = authenticate.indexOf(
      'Authenticate canonical candidate metadata',
    );
    expect(sourceGuard, greaterThanOrEqualTo(0));
    expect(protectedApproval, greaterThan(sourceGuard));
    expect(mint, greaterThan(protectedApproval));
    expect(inventory, greaterThan(mint));
    expect(candidate, greaterThan(inventory));

    final legacyAppId = ['secrets', 'GITOPS_APP_ID'].join('.');
    final legacyAppKey = ['secrets', 'GITOPS_APP_PRIVATE_KEY'].join('.');
    expect(source, isNot(contains(legacyAppId)));
    expect(source, isNot(contains(legacyAppKey)));
    expect(
      RegExp(
        r'secrets\.MISSION_SPINE_EVIDENCE_READER_APP_ID',
      ).allMatches(source).length,
      1,
    );
    expect(
      RegExp(
        r'secrets\.MISSION_SPINE_EVIDENCE_READER_APP_PRIVATE_KEY',
      ).allMatches(source).length,
      1,
    );
  });

  test('manual AT workflow action references are immutable pins', () {
    expect(workflow.existsSync(), isTrue);
    final source = workflow.readAsStringSync().replaceAll('\r\n', '\n');
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
