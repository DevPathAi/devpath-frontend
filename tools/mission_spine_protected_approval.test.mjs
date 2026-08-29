import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  githubInitiatorIdentity,
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
const baselineWorkflowSource = readFileSync(
  new URL('../.github/workflows/et13-baseline-approval.yml', import.meta.url),
  'utf8',
);
const manualWorkflowSource = readFileSync(
  new URL('../.github/workflows/mission-spine-manual-at-evidence.yml', import.meta.url),
  'utf8',
).replace(/\r\n/g, '\n');
const et13WorkflowSource = readFileSync(
  new URL('../.github/workflows/et13-evidence.yml', import.meta.url),
  'utf8',
).replace(/\r\n/g, '\n');

test('prod26r8 dispatchers start candidate-bound main workflows as the Actions App', () => {
  assert.match(
    manualWorkflowSource,
    /authenticate-inputs:\n\s+if: github\.ref == 'refs\/heads\/main'/,
  );
  assert.match(
    manualWorkflowSource,
    /dispatch-manual-at:\n\s+if: github\.ref == 'refs\/heads\/chore\/prod26r8-candidate-evidence-dispatch'/,
  );
  assert.match(
    et13WorkflowSource,
    /authenticate-release-inputs:\n\s+if: github\.event_name == 'workflow_dispatch' && github\.ref == 'refs\/heads\/main'/,
  );
  assert.match(
    et13WorkflowSource,
    /dispatch-final-et13:\n\s+if: github\.event_name == 'workflow_dispatch' && github\.ref == 'refs\/heads\/chore\/prod26r8-candidate-evidence-dispatch'/,
  );
  for (const workflow of [manualWorkflowSource, et13WorkflowSource]) {
    assert.match(workflow, /actions: write/);
    assert.match(workflow, /RELEASE_ID: ms-20260829-prod26r8/);
    assert.match(
      workflow,
      /CANDIDATE_SPEC_SHA256: a0ad5fd087db806c56fe41f195b7722cd97a821b71c6178f2959a12679d0614f/,
    );
    assert.match(workflow, /SOURCE_SHA: edc2c56f695eaad6d5e494bab81d5b5db4427e14/);
    assert.match(workflow, /test "\$inner_actor" = "github-actions\[bot\]"/);
    assert.match(workflow, /test "\$inner_triggering_actor" = "github-actions\[bot\]"/);
    assert.match(workflow, /test "\$\(jq -er '\.actor\.id' "\$run_document"\)" = "41898282"/);
  }
});
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

test('protected approval accepts only the exact GitHub Actions automation initiator', () => {
  const automated = structuredClone(approvalFacts);
  automated.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
  automated.run.actor = {
    id: 41898282,
    login: 'github-actions[bot]',
    type: 'Bot',
  };
  automated.run.triggering_actor = {
    id: 41898282,
    login: 'github-actions[bot]',
    type: 'Bot',
  };
  assert.equal(
    validateProtectedApprovalFacts(automated).approved_by,
    'VelkaressiaBlutkrone',
  );
});

test('protected approval rejects lookalike automation initiators and bot reviewers', () => {
  for (const identity of [
    { id: 41898282, login: 'evil-actions[bot]', type: 'Bot' },
    { id: 41898282, login: 'github-actions[bot]suffix', type: 'Bot' },
    { id: 7, login: 'github-actions[bot]', type: 'Bot' },
    { id: 41898282, login: 'github-actions[bot]', type: 'User' },
  ]) {
    const lookalike = structuredClone(approvalFacts);
    lookalike.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
    lookalike.run.actor = identity;
    lookalike.run.triggering_actor = identity;
    assert.throws(
      () => validateProtectedApprovalFacts(lookalike),
      /run\.actor/,
    );
  }

  const botReviewer = structuredClone(approvalFacts);
  botReviewer.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
  botReviewer.approvals[0].user = {
    id: 41898282,
    login: 'github-actions[bot]',
    type: 'Bot',
  };
  assert.throws(
    () => validateProtectedApprovalFacts(botReviewer),
    /reviewer login is absent or non-human/,
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

test('protected approval rejects runs outside executing or peer-waiting states', () => {
  for (const status of ['queued', 'pending', 'requested', 'completed']) {
    const inactive = structuredClone(approvalFacts);
    inactive.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
    inactive.run.status = status;
    if (status === 'completed') inactive.run.conclusion = 'success';
    assert.throws(
      () => validateProtectedApprovalFacts(inactive),
      /run.status/,
    );
  }
});

test('protected approval accepts a waiting run while an approved peer job executes', () => {
  const waiting = structuredClone(approvalFacts);
  waiting.workflowBytes = Buffer.from(approvalFacts.workflowBytes);
  waiting.run.status = 'waiting';
  assert.equal(
    validateProtectedApprovalFacts(waiting).approved_by,
    'VelkaressiaBlutkrone',
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

test('exact GitHub Actions automation may initiate but lookalikes are rejected', () => {
  assert.deepEqual(
    githubInitiatorIdentity({
      id: 41898282,
      login: 'github-actions[bot]',
      type: 'Bot',
    }, 'run.actor'),
    { id: 41898282, login: 'github-actions[bot]' },
  );
  assert.deepEqual(
    githubInitiatorIdentity({ id: 11, login: 'initiator', type: 'User' }, 'run.actor'),
    { id: 11, login: 'initiator' },
  );
  for (const identity of [
    { id: 41898282, login: 'github-actions-bot[bot]', type: 'Bot' },
    { id: 41898283, login: 'github-actions[bot]', type: 'Bot' },
    { id: 41898282, login: 'github-actions[bot]-suffix', type: 'Bot' },
    { id: 41898282, login: 'github-actions[bot]', type: 'User' },
  ]) {
    assert.throws(() => githubInitiatorIdentity(identity, 'run.actor'));
  }
});

test('ET13 baseline approval uses the exact automation-aware initiator validator', () => {
  assert.match(
    baselineWorkflowSource,
    /const \{ githubInitiatorIdentity \} = await import\(\s*'\.\/tools\/mission_spine_protected_approval\.mjs'\s*\);/,
  );
  assert.equal(
    baselineWorkflowSource.match(/githubInitiatorIdentity\(\s*currentRun\.(?:actor|triggering_actor)/g)?.length,
    2,
  );
  assert.doesNotMatch(
    baselineWorkflowSource,
    /githubUserIdentity\(\s*currentRun\.(?:actor|triggering_actor)/,
  );
});
