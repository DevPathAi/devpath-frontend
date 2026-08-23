import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  validateProtectedApprovalFacts,
} from './mission_spine_protected_approval.mjs';

const sha = '1234567890abcdef1234567890abcdef12345678';
const workflowBytes = Buffer.from('name: trusted signed workflow\n');
const workflowSha256 = createHash('sha256')
  .update(workflowBytes)
  .digest('hex');
const verifierSource = readFileSync(
  new URL('./mission_spine_protected_approval.mjs', import.meta.url),
  'utf8',
);
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
    status: 'in_progress',
    conclusion: null,
    head_sha: sha,
    head_branch: 'main',
    path: '.github/workflows/mission-spine-signed-mobile-build.yml',
    repository: { full_name: 'DevPathAi/devpath-frontend' },
    head_repository: { full_name: 'DevPathAi/devpath-frontend' },
    actor: { id: 11, login: 'initiator', type: 'User' },
    triggering_actor: { id: 11, login: 'initiator', type: 'User' },
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
    can_admins_bypass: false,
    deployment_branch_policy: {
      protected_branches: false,
      custom_branch_policies: true,
    },
    protection_rules: [
      {
        type: 'required_reviewers',
        prevent_self_review: true,
        reviewers: [
          {
            type: 'User',
            reviewer: {
              id: 77432570,
              login: 'VelkaressiaBlutkrone',
              type: 'User',
            },
          },
        ],
      },
    ],
  },
  branchPolicies: {
    total_count: 1,
    branch_policies: [
      { id: 101, name: 'main', type: 'branch' },
    ],
  },
  approvals: [
    {
      state: 'approved',
      user: { id: 77432570, login: 'VelkaressiaBlutkrone', type: 'User' },
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
    approved_by: 'VelkaressiaBlutkrone',
    approved_by_id: 77432570,
    approval_effective_at: '2025-08-17T01:02:03Z',
    workflow_sha256: workflowSha256,
  });
});

test('protected approval permits the configured reviewer to initiate and approve', () => {
  const aiOperated = structuredClone(approvalFacts);
  aiOperated.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
  aiOperated.run.actor = {
    id: 77432570,
    login: 'VelkaressiaBlutkrone',
    type: 'User',
  };
  aiOperated.run.triggering_actor = {
    id: 77432570,
    login: 'VelkaressiaBlutkrone',
    type: 'User',
  };
  assert.equal(
    validateProtectedApprovalFacts(aiOperated).approved_by,
    'VelkaressiaBlutkrone',
  );
});

test('protected approval rejects missing initiator identity and branch protection', () => {
  const missingActor = structuredClone(approvalFacts);
  missingActor.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
  missingActor.run.actor = null;
  assert.throws(
    () => validateProtectedApprovalFacts(missingActor),
    /run\.actor/,
  );

  const unprotected = structuredClone(approvalFacts);
  unprotected.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
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

test('protected approval pins the current GitHub API contract', () => {
  assert.match(verifierSource, /'X-GitHub-Api-Version': '2026-03-10'/);
  assert.doesNotMatch(verifierSource, /2022-11-28/);
});

test('protected approval rejects a run that is no longer executing', () => {
  const completed = structuredClone(approvalFacts);
  completed.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
  completed.run.status = 'completed';
  completed.run.conclusion = 'success';
  assert.throws(
    () => validateProtectedApprovalFacts(completed),
    /run.status/,
  );
});

test('protected approval rejects admin bypass and run path suffix ambiguity', () => {
  for (const mutate of [
    (facts) => {
      facts.environment.can_admins_bypass = true;
    },
    (facts) => {
      delete facts.environment.can_admins_bypass;
    },
    (facts) => {
      facts.run.path = `${facts.workflowPath}@main`;
    },
    (facts) => {
      facts.run.path = `${facts.workflowPath}@refs/heads/main`;
    },
  ]) {
    const invalid = structuredClone(approvalFacts);
    invalid.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
    mutate(invalid);
    assert.throws(() => validateProtectedApprovalFacts(invalid));
  }
});

test('protected approval rejects a widened environment branch policy', () => {
  for (const mutate of [
    (facts) => {
      facts.environment.deployment_branch_policy.protected_branches = true;
    },
    (facts) => {
      facts.environment.deployment_branch_policy.custom_branch_policies = false;
    },
    (facts) => {
      facts.branchPolicies.branch_policies[0].name = 'release/*';
    },
    (facts) => {
      facts.branchPolicies.branch_policies.push({
        id: 102,
        name: 'release/*',
        type: 'branch',
      });
      facts.branchPolicies.total_count = 2;
    },
  ]) {
    const invalid = structuredClone(approvalFacts);
    invalid.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
    mutate(invalid);
    assert.throws(() => validateProtectedApprovalFacts(invalid));
  }
});

test('protected approval rejects an unverified team-membership claim', () => {
  const teamOnly = structuredClone(approvalFacts);
  teamOnly.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
  teamOnly.environment.protection_rules[0].reviewers = [
    { type: 'Team', reviewer: { id: 81, slug: 'release-reviewers' } },
  ];
  assert.throws(
    () => validateProtectedApprovalFacts(teamOnly),
    /reviewer type/,
  );
});

test('protected approval rejects reviewer authority widening or replacement', () => {
  for (const mutate of [
    (facts) => {
      facts.environment.protection_rules[0].reviewers.push({
        type: 'User',
        reviewer: { id: 22, login: 'new-reviewer', type: 'User' },
      });
    },
    (facts) => {
      facts.environment.protection_rules[0].reviewers[0] = {
        type: 'User',
        reviewer: { id: 22, login: 'replacement-reviewer', type: 'User' },
      };
      facts.approvals[0].user = {
        id: 22,
        login: 'replacement-reviewer',
        type: 'User',
      };
    },
    (facts) => {
      facts.environment.protection_rules[0].reviewers.push({
        type: 'Team',
        reviewer: { id: 81, slug: 'release-reviewers' },
      });
    },
  ]) {
    const invalid = structuredClone(approvalFacts);
    invalid.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
    mutate(invalid);
    assert.throws(() => validateProtectedApprovalFacts(invalid));
  }
});

test('manual AT authentication environment is an exact protected binding', () => {
  const manual = structuredClone(approvalFacts);
  manual.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
  manual.workflowPath =
    '.github/workflows/mission-spine-manual-at-evidence.yml';
  manual.environmentName = 'mission-spine-manual-at-auth';
  manual.jobName = 'Authenticate manual AT inputs';
  manual.run.path = manual.workflowPath;
  manual.environment.name = manual.environmentName;
  manual.approvals[0].environments = [
    { id: manual.environment.id, name: manual.environmentName },
  ];
  manual.jobs.jobs[0].name = manual.jobName;
  assert.equal(
    validateProtectedApprovalFacts(manual).approval_environment,
    manual.environmentName,
  );
});

test('ET13 release authentication environment is an exact protected binding', () => {
  const et13 = structuredClone(approvalFacts);
  et13.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
  et13.workflowPath = '.github/workflows/et13-evidence.yml';
  et13.environmentName = 'mission-spine-et13-release-auth';
  et13.jobName = 'Authenticate ET13 release inputs';
  et13.run.path = et13.workflowPath;
  et13.environment.name = et13.environmentName;
  et13.approvals[0].environments = [
    { id: et13.environment.id, name: et13.environmentName },
  ];
  et13.jobs.jobs[0].name = et13.jobName;
  assert.equal(
    validateProtectedApprovalFacts(et13).approval_environment,
    et13.environmentName,
  );
});
