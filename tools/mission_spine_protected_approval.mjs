import { createHash } from 'node:crypto';
import { appendFileSync, lstatSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import process from 'node:process';

const frontendRepository = 'DevPathAi/devpath-frontend';
const frozenReviewers = Object.freeze([
  Object.freeze({ id: 77432570, login: 'VelkaressiaBlutkrone' }),
]);

function protectedBinding(jobName) {
  return Object.freeze({ jobName, reviewers: frozenReviewers });
}

const allowedBindings = new Map([
  [
    '.github/workflows/et13-evidence.yml',
    new Map([
      [
        'mission-spine-et13-release-auth',
        protectedBinding('Authenticate ET13 release inputs'),
      ],
    ]),
  ],
  [
    '.github/workflows/mission-spine-signed-mobile-build.yml',
    new Map([
      [
        'mission-spine-mobile-signing-android',
        protectedBinding('Sign Android release'),
      ],
    ]),
  ],
  [
    '.github/workflows/mission-spine-manual-at-evidence.yml',
    new Map([
      [
        'mission-spine-manual-at-auth',
        protectedBinding('Authenticate manual AT inputs'),
      ],
      ['manual-at-nvda', protectedBinding('Approve manual NVDA evidence')],
      [
        'manual-at-talkback',
        protectedBinding('Approve manual TalkBack evidence'),
      ],
    ]),
  ],
]);

function fail(message) {
  throw new Error(`Mission Spine protected approval failed: ${message}`);
}

function exact(actual, expected, name) {
  if (actual !== expected) fail(`${name} mismatch`);
}

function positiveInteger(value, name) {
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1 || `${parsed}` !== `${value}`) {
    fail(`${name} must be a positive integer`);
  }
  return parsed;
}

function sha1(value, name) {
  if (typeof value !== 'string' || !/^(?!0{40}$)[0-9a-f]{40}$/.test(value)) {
    fail(`${name} must be a nonzero lowercase Git SHA`);
  }
  return value;
}

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function utc(value, name) {
  if (
    typeof value !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(value) ||
    !Number.isFinite(Date.parse(value))
  ) {
    fail(`${name} must be an exact UTC timestamp ending in Z`);
  }
  return Date.parse(value);
}

function validateWorkflowPath(run, workflowPath) {
  exact(run.path, workflowPath, 'run.path');
}

function githubUserIdentity(value, name) {
  const id = positiveInteger(value?.id, `${name}.id`);
  const login = value?.login;
  if (
    value?.type !== 'User' ||
    typeof login !== 'string' ||
    !/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$/.test(login)
  ) {
    fail(`${name} must be a human GitHub user`);
  }
  return { id, login };
}

function validateBinding(workflowPath, environmentName, jobName) {
  const environments = allowedBindings.get(workflowPath);
  const binding = environments?.get(environmentName);
  if (!binding || binding.jobName !== jobName) {
    fail('workflow/environment/job binding is not allowlisted');
  }
  return binding;
}

export function validateProtectedApprovalFacts(facts) {
  const binding = validateBinding(
    facts.workflowPath,
    facts.environmentName,
    facts.jobName,
  );
  exact(facts.repository, frontendRepository, 'repository');
  sha1(facts.sourceSha, 'sourceSha');
  const runId = positiveInteger(facts.runId, 'runId');
  const runAttempt = positiveInteger(facts.runAttempt, 'runAttempt');
  if (runAttempt !== 1) {
    fail('protected approvals require attempt 1 and a fresh workflow_dispatch');
  }

  exact(facts.run.id, runId, 'run.id');
  exact(facts.run.run_attempt, runAttempt, 'run.run_attempt');
  exact(facts.run.event, 'workflow_dispatch', 'run.event');
  if (!['in_progress', 'waiting'].includes(facts.run.status)) {
    fail('run.status mismatch');
  }
  exact(facts.run.conclusion, null, 'run.conclusion');
  exact(facts.run.head_sha, facts.sourceSha, 'run.head_sha');
  exact(facts.run.head_branch, 'main', 'run.head_branch');
  exact(facts.run.repository?.full_name, frontendRepository, 'run.repository');
  exact(
    facts.run.head_repository?.full_name,
    frontendRepository,
    'run.head_repository',
  );
  validateWorkflowPath(facts.run, facts.workflowPath);
  githubUserIdentity(facts.run.actor, 'run.actor');
  githubUserIdentity(facts.run.triggering_actor, 'run.triggering_actor');

  exact(facts.branch.name, 'main', 'protected branch name');
  exact(facts.branch.commit?.sha, facts.sourceSha, 'protected branch commit SHA');
  exact(facts.branch.protected, true, 'protected branch policy');

  exact(facts.environment.name, facts.environmentName, 'environment.name');
  exact(
    facts.environment.can_admins_bypass,
    false,
    'environment can_admins_bypass',
  );
  if (
    !facts.environment.deployment_branch_policy ||
    typeof facts.environment.deployment_branch_policy !== 'object' ||
    Array.isArray(facts.environment.deployment_branch_policy)
  ) {
    fail('environment deployment branch policy is absent');
  }
  exact(
    facts.environment.deployment_branch_policy.protected_branches,
    false,
    'environment protected_branches policy',
  );
  exact(
    facts.environment.deployment_branch_policy.custom_branch_policies,
    true,
    'environment custom_branch_policies policy',
  );
  if (
    !facts.branchPolicies ||
    typeof facts.branchPolicies !== 'object' ||
    Array.isArray(facts.branchPolicies)
  ) {
    fail('environment branch policies are absent');
  }
  exact(facts.branchPolicies.total_count, 1, 'environment branch policy count');
  if (
    !Array.isArray(facts.branchPolicies.branch_policies) ||
    facts.branchPolicies.branch_policies.length !== 1
  ) {
    fail('environment branch policy list is absent or ambiguous');
  }
  const branchPolicy = facts.branchPolicies.branch_policies[0];
  positiveInteger(branchPolicy?.id, 'environment branch policy id');
  exact(branchPolicy?.name, 'main', 'environment branch policy name');
  exact(branchPolicy?.type, 'branch', 'environment branch policy type');
  const environmentId = positiveInteger(
    facts.environment.id,
    'environment.id',
  );
  if (!Array.isArray(facts.environment.protection_rules)) {
    fail('environment protection rules are absent');
  }
  const reviewerRules = facts.environment.protection_rules.filter(
    (rule) => rule.type === 'required_reviewers',
  );
  if (reviewerRules.length !== 1) {
    fail('required reviewer rule is absent or ambiguous');
  }
  const reviewerRule = reviewerRules[0];
  exact(
    reviewerRule.prevent_self_review,
    true,
    'environment prevent_self_review',
  );
  if (!Array.isArray(reviewerRule.reviewers) || reviewerRule.reviewers.length < 1) {
    fail('environment has no configured reviewer');
  }
  exact(
    reviewerRule.reviewers.length,
    binding.reviewers.length,
    'environment reviewer count',
  );
  const configuredReviewers = reviewerRule.reviewers
    .map((entry) => {
      exact(entry?.type, 'User', 'environment reviewer type');
      exact(entry?.reviewer?.type, 'User', 'environment reviewer account type');
      return {
        id: positiveInteger(entry.reviewer?.id, 'environment reviewer id'),
        login: entry.reviewer?.login,
      };
    })
    .sort((left, right) => left.id - right.id);
  const expectedReviewers = [...binding.reviewers].sort(
    (left, right) => left.id - right.id,
  );
  for (let index = 0; index < expectedReviewers.length; index += 1) {
    exact(
      configuredReviewers[index].id,
      expectedReviewers[index].id,
      'environment reviewer id',
    );
    exact(
      configuredReviewers[index].login,
      expectedReviewers[index].login,
      'environment reviewer login',
    );
  }

  if (!Array.isArray(facts.approvals)) fail('approval history is absent');
  const reviews = facts.approvals.filter(
    (review) =>
      review.state === 'approved' &&
      Array.isArray(review.environments) &&
      review.environments.filter(
        (entry) =>
          entry?.id === environmentId && entry?.name === facts.environmentName,
      ).length === 1,
  );
  if (reviews.length !== 1) fail('exact environment approval is absent or ambiguous');
  const review = reviews[0];
  const login = review.user?.login;
  if (
    typeof login !== 'string' ||
    !/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$/.test(login) ||
    review.user?.type !== 'User'
  ) {
    fail('approved reviewer login is absent or non-human');
  }
  const reviewerId = positiveInteger(review.user.id, 'approved reviewer id');
  const configuredUser = expectedReviewers.some(
    (entry) => entry.id === reviewerId && entry.login === login,
  );
  if (!configuredUser) {
    fail('approved reviewer is not the exact configured user reviewer');
  }

  if (!facts.jobs || !Array.isArray(facts.jobs.jobs)) {
    fail('attempt job list is absent');
  }
  const matchingJobs = facts.jobs.jobs.filter((job) => job.name === facts.jobName);
  if (matchingJobs.length !== 1) {
    fail('protected approval job identity is absent or ambiguous');
  }
  const job = matchingJobs[0];
  exact(job.run_id, runId, 'approval job run_id');
  exact(job.head_sha, facts.sourceSha, 'approval job head_sha');
  const createdAt = utc(facts.run.created_at, 'run.created_at');
  const effectiveAt = utc(job.started_at, 'approval job started_at');
  if (effectiveAt < createdAt || effectiveAt > Date.now()) {
    fail('approval effective time is outside the protected run interval');
  }

  if (!Buffer.isBuffer(facts.workflowBytes) || facts.workflowBytes.length < 1) {
    fail('workflow raw bytes are absent');
  }
  const workflowSha256 = sha256(facts.workflowBytes);
  exact(workflowSha256, facts.localWorkflowSha256, 'workflow raw SHA-256');

  return {
    approval_environment: facts.environmentName,
    approval_environment_id: environmentId,
    approval_job_name: facts.jobName,
    approved_by: login,
    approved_by_id: reviewerId,
    approval_effective_at: job.started_at,
    workflow_sha256: workflowSha256,
  };
}

async function github(path, token, fetchImpl = fetch) {
  const response = await fetchImpl(`https://api.github.com${path}`, {
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2026-03-10',
    },
    redirect: 'error',
  });
  if (!response.ok) fail(`GitHub API ${path} returned HTTP ${response.status}`);
  return response.json();
}

function parseOptions(argv) {
  const result = new Map();
  for (const argument of argv) {
    if (!argument.startsWith('--') || !argument.includes('=')) {
      fail(`invalid option ${argument}`);
    }
    const split = argument.indexOf('=');
    const key = argument.slice(2, split);
    if (result.has(key)) fail(`duplicate --${key}`);
    result.set(key, argument.slice(split + 1));
  }
  return result;
}

function required(options, key) {
  const value = options.get(key);
  if (!value) fail(`missing --${key}`);
  return value;
}

async function authenticate(options) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) fail('GITHUB_TOKEN is absent');
  const repository = process.env.GITHUB_REPOSITORY;
  const sourceSha = process.env.GITHUB_SHA;
  const runId = positiveInteger(process.env.GITHUB_RUN_ID, 'GITHUB_RUN_ID');
  const runAttempt = positiveInteger(
    process.env.GITHUB_RUN_ATTEMPT,
    'GITHUB_RUN_ATTEMPT',
  );
  const workflowPath = required(options, 'workflow-path');
  const environmentName = required(options, 'environment');
  const jobName = required(options, 'job-name');
  const output = required(options, 'output');
  validateBinding(workflowPath, environmentName, jobName);
  exact(repository, frontendRepository, 'GITHUB_REPOSITORY');
  exact(process.env.GITHUB_REF, 'refs/heads/main', 'GITHUB_REF');
  sha1(sourceSha, 'GITHUB_SHA');
  const workflowInfo = lstatSync(workflowPath);
  if (!workflowInfo.isFile() || workflowInfo.isSymbolicLink()) {
    fail('local workflow must be one regular non-link file');
  }
  const localWorkflowBytes = readFileSync(workflowPath);

  const run = await github(
    `/repos/${repository}/actions/runs/${runId}/attempts/${runAttempt}`,
    token,
  );
  const branch = await github(`/repos/${repository}/branches/main`, token);
  const environment = await github(
    `/repos/${repository}/environments/${encodeURIComponent(environmentName)}`,
    token,
  );
  const branchPolicies = await github(
    `/repos/${repository}/environments/${encodeURIComponent(environmentName)}/deployment-branch-policies?per_page=100`,
    token,
  );
  const encodedWorkflow = workflowPath
    .split('/')
    .map((part) => encodeURIComponent(part))
    .join('/');
  const workflow = await github(
    `/repos/${repository}/contents/${encodedWorkflow}?ref=${sourceSha}`,
    token,
  );
  exact(workflow.type, 'file', 'workflow.type');
  exact(workflow.path, workflowPath, 'workflow.path');
  exact(workflow.encoding, 'base64', 'workflow.encoding');
  const workflowBytes = Buffer.from(
    (workflow.content ?? '').replace(/\s/g, ''),
    'base64',
  );
  if (!workflowBytes.equals(localWorkflowBytes)) {
    fail('checked workflow differs from exact GitHub source bytes');
  }

  let approvals = [];
  let jobs = null;
  for (let attempt = 0; attempt < 10; attempt += 1) {
    approvals = await github(`/repos/${repository}/actions/runs/${runId}/approvals`, token);
    jobs = await github(
      `/repos/${repository}/actions/runs/${runId}/attempts/${runAttempt}/jobs?per_page=100`,
      token,
    );
    const reviewVisible = Array.isArray(approvals) && approvals.some(
      (review) =>
        review.state === 'approved' &&
        review.environments?.some(
          (entry) => entry.id === environment.id && entry.name === environmentName,
        ),
    );
    if (reviewVisible && jobs?.jobs?.some((job) => job.name === jobName && job.started_at)) {
      break;
    }
    await new Promise((done) => setTimeout(done, 2000));
  }

  const result = validateProtectedApprovalFacts({
    repository,
    sourceSha,
    runId,
    runAttempt,
    environmentName,
    jobName,
    workflowPath,
    localWorkflowSha256: sha256(localWorkflowBytes),
    run,
    branch,
    environment,
    branchPolicies,
    approvals,
    jobs,
    workflowBytes,
  });
  writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`, {
    encoding: 'utf8',
    flag: 'wx',
  });
  if (process.env.GITHUB_OUTPUT) {
    appendFileSync(
      process.env.GITHUB_OUTPUT,
      Object.entries(result)
        .map(([key, value]) => `${key}=${value}\n`)
        .join(''),
      { encoding: 'utf8' },
    );
  }
  process.stdout.write('Protected workflow approval authenticated\n');
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  const options = parseOptions(process.argv.slice(2));
  authenticate(options).catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
