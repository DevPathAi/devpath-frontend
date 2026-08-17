import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String workflow;

  setUpAll(() {
    final file = File('../../.github/workflows/et13-baseline-approval.yml');
    expect(file.existsSync(), isTrue);
    workflow = file.readAsStringSync();
  });

  test(
    'approval job is a read-only, first-attempt protected environment gate',
    () {
      expect(workflow, contains("'on':\n  workflow_dispatch:"));
      expect(workflow, contains('actions: read'));
      expect(workflow, contains('contents: read'));
      expect(
        workflow,
        isNot(contains(RegExp(r'\b(?:actions|contents): write\b'))),
      );
      expect(workflow, contains('name: et13-baseline-approval'));
      expect(workflow, contains("requiredRule.prevent_self_review !== true"));
      expect(workflow, contains('requiredRules.length !== 1'));
      expect(workflow, contains('requiredRule.reviewers.length < 1'));
      expect(
        workflow,
        contains(r'/environments/${encodeURIComponent(environmentName)}'),
      );
      expect(workflow, contains(r'/actions/runs/${currentRunId}/approvals'));
      expect(workflow, contains("review.state === 'approved'"));
      expect(
        workflow,
        contains('const protectedReviewVisible = Array.isArray(approvals)'),
      );
      expect(workflow, contains('approvals.length !== 1'));
      expect(workflow, contains('review.environments.length === 1'));
      expect(
        workflow,
        contains('review.environments[0]?.id === environment.id'),
      );
      expect(
        workflow,
        contains('review.environments[0]?.name === environmentName'),
      );
      expect(workflow, contains('approvedBy === currentRun.actor?.login'));
      expect(
        workflow,
        contains('approvedBy === currentRun.triggering_actor?.login'),
      );
      expect(workflow, contains('review.user.id === currentRun.actor?.id'));
      expect(
        workflow,
        contains('review.user.id === currentRun.triggering_actor?.id'),
      );
      expect(workflow, contains("currentRun.run_attempt, 1"));
      expect(workflow, isNot(contains('/pending_deployments')));
      expect(workflow, isNot(contains("method: 'POST'")));
    },
  );

  test('raw review input is bound to immutable same-source coordinates', () {
    for (final input in [
      'release_id:',
      'raw_run_id:',
      'raw_run_attempt:',
      'raw_artifact_id:',
      'raw_artifact_digest:',
      'raw_workflow_sha256:',
    ]) {
      expect(workflow, contains(input), reason: input);
    }
    expect(
      workflow,
      contains(r'/actions/runs/${rawRunId}/attempts/${rawRunAttempt}'),
    );
    expect(workflow, contains(r'/actions/artifacts/${rawArtifactId}'));
    expect(
      workflow,
      contains(
        r'et13-unsealed-raw-review-run-${rawRunId}-attempt-${rawRunAttempt}',
      ),
    );
    expect(workflow, contains("exact(rawRun.head_sha, sourceSha"));
    expect(workflow, contains("exact(rawRun.event, 'push'"));
    expect(workflow, contains("exact(rawRun.conclusion, 'success'"));
    expect(workflow, contains("exact(rawArtifact.digest, rawArtifactDigest"));
    expect(workflow, contains('const acceptedPaths = new Set(['));
    expect(workflow, isNot(contains(r'startsWith(`${expectedPath}@`)')));
    expect(workflow, contains("createHash('sha256')"));
    expect(workflow, contains(r'/actions/artifacts/${RAW_ARTIFACT_ID}/zip'));
    expect(workflow, contains('sha256sum --check --strict'));
    expect(workflow, contains('test ! -e build/et13/raw-archive'));
    expect(workflow, contains('stat.S_IFLNK'));
    expect(workflow, contains('unzip -q'));
    expect(workflow, contains('diff --recursive --brief'));
    expect(workflow, contains('artifact-ids: \${{ inputs.raw_artifact_id }}'));
    expect(workflow, contains('run-id: \${{ inputs.raw_run_id }}'));
  });

  test('approved artifact is an exact validated 98-file baseline bundle', () {
    expect(workflow, contains("test -z \"\$(find \"\${raw_root}\" -type l"));
    expect(workflow, contains("test \"\${#visual_paths[@]}\" -eq 96"));
    expect(workflow, contains('review-candidate.v1.json'));
    expect(workflow, contains('baseline-approval.v1.json'));
    expect(workflow, contains('review_candidate_sha256'));
    expect(workflow, contains('candidate_set_sha256'));
    expect(workflow, contains('approved_by'));
    expect(workflow, contains('approved_by_id'));
    expect(workflow, contains('approval_effective_at'));
    expect(workflow, isNot(contains('review.environments[0].updated_at')));
    for (final field in [
      'approval_repository',
      'approval_workflow_path',
      'approval_workflow_sha256',
      'approval_run_id',
      'approval_run_attempt',
      'approval_head_sha',
      'approval_environment',
      'approval_environment_id',
      'raw_review_workflow_sha256',
      'raw_review_run_id',
      'raw_review_run_attempt',
      'raw_review_head_sha',
      'raw_review_artifact_id',
      'raw_review_artifact_name',
      'raw_review_artifact_digest',
    ]) {
      expect(workflow, contains(field), reason: field);
    }
    expect(workflow, contains('requireExactBundle: true'));
    expect(workflow, contains(r'find "${approved_root}" -type l'));
    expect(
      workflow,
      contains(r'find "${approved_root}" -mindepth 1 ! -type f ! -type d'),
    );
    expect(workflow, contains(r'"${RUNNER_TEMP}/expected-directories.txt"'));
    expect(workflow, contains(r'"${RUNNER_TEMP}/actual-directories.txt"'));
    expect(
      workflow,
      contains('test "\$(wc -l < "\${RUNNER_TEMP}/actual-files.txt")" -eq 98'),
    );
    expect(workflow, contains('sha256sum --check --strict'));
    expect(
      workflow,
      contains(
        '\${{ inputs.release_id }}-frontend-visual-approved-baseline-run-',
      ),
    );
    expect(workflow, contains('if-no-files-found: error'));
    expect(workflow, contains('924134a44c189315be2148659913dda1671cbe99'));
  });

  test(
    'fresh approval validates packaged review evidence without build trees',
    () {
      expect(workflow, contains('validate-review-manifest'));
      expect(
        workflow,
        isNot(contains('et13_evidence.dart validate-manifest \\')),
        reason:
            'approval runners receive the strict raw-review bundle, not the '
            'producer build trees required by validate-manifest',
      );
      expect(workflow, contains(r'if [[ "${lane}" == visual ]]; then'));
      expect(
        workflow,
        contains('.baseline_status == "pending_external_review"'),
      );
      for (final field in [
        'baseline_status',
        'baseline_set_sha256',
        'baseline_approval_sha256',
      ]) {
        expect(
          workflow,
          contains('has("$field") | not'),
          reason: 'a11y review candidates must omit $field',
        );
      }
    },
  );

  test('all third-party actions are pinned to full commit identities', () {
    final uses = RegExp(
      r'^\s*-?\s*uses:\s*([^\s#]+)',
      multiLine: true,
    ).allMatches(workflow).map((match) => match.group(1)!).toList();
    expect(uses, isNotEmpty);
    for (final action in uses) {
      expect(action, matches(RegExp(r'^[^@]+@[0-9a-f]{40}$')), reason: action);
    }
  });
}
