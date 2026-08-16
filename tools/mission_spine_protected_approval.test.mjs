import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';

import {
  validateProtectedApprovalFacts,
} from './mission_spine_protected_approval.mjs';

const sha = '1234567890abcdef1234567890abcdef12345678';
const workflowBytes = Buffer.from('name: trusted signed workflow\n');
const workflowSha256 = createHash('sha256')
  .update(workflowBytes)
  .digest('hex');
const approvalFacts = {
  repository: 'DevPathAi/devpath-frontend',
  sourceSha: sha,
  runId: 501,
  runAttempt: 1,
  environmentName: 'mission-spine-mobile-signing-android',
  jobName: 'Sign Android release',
  workflowPath: '.github/workflows/mission-spine-signed-mobile-build.yml',
  localWorkflowSha256: workflowSha256,
  run: {
    id: 501,
    run_attempt: 1,
    event: 'workflow_dispatch',
    head_sha: sha,
    head_branch: 'main',
    path: '.github/workflows/mission-spine-signed-mobile-build.yml@main',
    repository: { full_name: 'DevPathAi/devpath-frontend' },
    head_repository: { full_name: 'DevPathAi/devpath-frontend' },
    actor: { id: 11, login: 'initiator' },
    triggering_actor: { id: 11, login: 'initiator' },
    created_at: '2025-08-17T01:00:00Z',
  },
  branch: {
    name: 'main',
    protected: true,
    commit: { sha },
  },
  environment: {
    id: 91,
    name: 'mission-spine-mobile-signing-android',
    protection_rules: [
      {
        type: 'required_reviewers',
        prevent_self_review: true,
        reviewers: [{ type: 'Team', reviewer: { id: 81 } }],
      },
    ],
  },
  approvals: [
    {
      state: 'approved',
      user: { id: 21, login: 'independent-reviewer', type: 'User' },
      environments: [
        { id: 91, name: 'mission-spine-mobile-signing-android' },
        { id: 92, name: 'mission-spine-mobile-signing-ios' },
      ],
    },
  ],
  jobs: {
    jobs: [
      {
        name: 'Sign Android release',
        run_id: 501,
        head_sha: sha,
        started_at: '2025-08-17T01:02:03Z',
      },
      {
        name: 'Sign iOS release',
        run_id: 501,
        head_sha: sha,
        started_at: null,
      },
    ],
  },
  workflowBytes,
};

test('protected approval binds exact environment, job, workflow, and reviewer', () => {
  const actual = validateProtectedApprovalFacts(approvalFacts);
  assert.deepEqual(actual, {
    approval_environment: 'mission-spine-mobile-signing-android',
    approval_environment_id: 91,
    approval_job_name: 'Sign Android release',
    approved_by: 'independent-reviewer',
    approved_by_id: 21,
    approval_effective_at: '2025-08-17T01:02:03Z',
    workflow_sha256: workflowSha256,
  });
});

test('protected approval rejects self-review and missing branch protection', () => {
  const selfReview = structuredClone(approvalFacts);
  selfReview.approvals[0].user = { id: 11, login: 'initiator', type: 'User' };
  assert.throws(
    () => validateProtectedApprovalFacts(selfReview),
    /initiator cannot approve/,
  );

  const unprotected = structuredClone(approvalFacts);
  unprotected.branch.protected = false;
  assert.throws(
    () => validateProtectedApprovalFacts(unprotected),
    /protected branch policy/,
  );
});

test('protected approval rejects stale approval reuse on a rerun attempt', () => {
  const rerun = structuredClone(approvalFacts);
  rerun.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
  rerun.runAttempt = 2;
  rerun.run.run_attempt = 2;
  assert.throws(
    () => validateProtectedApprovalFacts(rerun),
    /attempt 1/,
  );
});

test('protected approval rejects wrong job, environment, and workflow bytes', () => {
  for (const mutate of [
    (facts) => {
      facts.jobs.jobs[0].name = 'Lookalike signing job';
    },
    (facts) => {
      facts.approvals[0].environments[0].name = 'unprotected';
    },
    (facts) => {
      facts.workflowBytes = Buffer.from('substituted workflow\n');
    },
  ]) {
    const invalid = structuredClone(approvalFacts);
    invalid.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
    mutate(invalid);
    assert.throws(() => validateProtectedApprovalFacts(invalid));
  }
});
