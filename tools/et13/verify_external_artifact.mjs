import process from 'node:process';
import { createHash } from 'node:crypto';

function fail(message) {
  throw new Error(`ET13 external artifact verification failed: ${message}`);
}

function options(argv) {
  const parsed = new Map();
  for (const value of argv) {
    if (!value.startsWith('--') || !value.includes('=')) fail(`invalid option ${value}`);
    const split = value.indexOf('=');
    parsed.set(value.slice(2, split), value.slice(split + 1));
  }
  return parsed;
}

function required(parsed, name) {
  const value = parsed.get(name);
  if (!value) fail(`missing --${name}`);
  return value;
}

function positiveInteger(value, name) {
  if (!/^[1-9][0-9]*$/.test(value)) fail(`${name} must be a positive integer`);
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) fail(`${name} exceeds the safe integer range`);
  return parsed;
}

function sha1(value, name) {
  if (!/^(?!0{40}$)[0-9a-f]{40}$/.test(value)) fail(`${name} must be a nonzero Git SHA`);
  return value;
}

function sha256(value, name) {
  if (!/^[0-9a-f]{64}$/.test(value)) fail(`${name} must be a SHA-256 digest`);
  return value;
}

function releaseId(value) {
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(value)) {
    fail('release-id is not a safe immutable identifier');
  }
  return value;
}

async function github(path, token) {
  const response = await fetch(`https://api.github.com${path}`, {
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2022-11-28',
    },
    redirect: 'error',
  });
  if (!response.ok) fail(`GitHub API ${path} returned HTTP ${response.status}`);
  return response.json();
}

function exact(actual, expected, name) {
  if (actual !== expected) fail(`${name} mismatch`);
}

async function main() {
  const parsed = options(process.argv.slice(2));
  const kind = required(parsed, 'kind');
  if (!['candidate', 'baseline'].includes(kind)) fail('kind must be candidate or baseline');
  const id = releaseId(required(parsed, 'release-id'));
  const runId = positiveInteger(required(parsed, 'run-id'), 'run-id');
  const runAttempt = positiveInteger(required(parsed, 'run-attempt'), 'run-attempt');
  const artifactId = positiveInteger(required(parsed, 'artifact-id'), 'artifact-id');
  const frontendSha = sha1(required(parsed, 'frontend-sha'), 'frontend-sha');
  const workflowBlobSha = sha256(
    required(parsed, 'workflow-blob-sha'),
    'workflow-blob-sha',
  );
  const token = process.env.GITHUB_TOKEN;
  if (!token) fail('GITHUB_TOKEN credential is absent');

  const config = kind === 'candidate'
    ? {
        repository: 'DevPathAi/devpath-gitops',
        workflow: '.github/workflows/mission-spine-candidate.yml',
        headSha: sha1(required(parsed, 'gitops-head-sha'), 'gitops-head-sha'),
        artifactName: `${id}-candidate-spec-run-${runId}-attempt-${runAttempt}`,
      }
    : {
        repository: 'DevPathAi/devpath-frontend',
        workflow: '.github/workflows/et13-baseline-approval.yml',
        headSha: frontendSha,
        artifactName:
          `${id}-frontend-visual-approved-baseline-run-${runId}-attempt-${runAttempt}`,
      };

  const run = await github(
    `/repos/${config.repository}/actions/runs/${runId}/attempts/${runAttempt}`,
    token,
  );
  exact(run.id, runId, 'run.id');
  exact(run.run_attempt, runAttempt, 'run.run_attempt');
  exact(run.event, 'workflow_dispatch', 'run.event');
  exact(run.status, 'completed', 'run.status');
  exact(run.conclusion, 'success', 'run.conclusion');
  exact(run.head_sha, config.headSha, 'run.head_sha');
  if (run.path !== config.workflow && !run.path?.startsWith(`${config.workflow}@`)) {
    fail('run.path mismatch');
  }
  exact(run.repository?.full_name, config.repository, 'run.repository');

  const artifact = await github(
    `/repos/${config.repository}/actions/artifacts/${artifactId}`,
    token,
  );
  exact(artifact.id, artifactId, 'artifact.id');
  exact(artifact.name, config.artifactName, 'artifact.name');
  exact(artifact.expired, false, 'artifact.expired');
  exact(artifact.workflow_run?.id, runId, 'artifact.workflow_run.id');
  exact(artifact.workflow_run?.head_sha, config.headSha, 'artifact.workflow_run.head_sha');
  if (!/^sha256:[0-9a-f]{64}$/.test(artifact.digest ?? '')) {
    fail('artifact.digest is absent or is not SHA-256');
  }
  const expiresAt = Date.parse(artifact.expires_at ?? '');
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    fail('artifact is expired or has no valid expiration timestamp');
  }

  const encodedWorkflow = config.workflow
    .split('/')
    .map((part) => encodeURIComponent(part))
    .join('/');
  const workflow = await github(
    `/repos/${config.repository}/contents/${encodedWorkflow}?ref=${config.headSha}`,
    token,
  );
  exact(workflow.type, 'file', 'workflow.type');
  exact(workflow.path, config.workflow, 'workflow.path');
  exact(workflow.encoding, 'base64', 'workflow.encoding');
  if (!/^(?!0{40}$)[0-9a-f]{40}$/.test(workflow.sha ?? '')) {
    fail('workflow Git object identity is absent or invalid');
  }
  const workflowBytes = Buffer.from((workflow.content ?? '').replace(/\s/g, ''), 'base64');
  if (workflowBytes.length < 1) fail('workflow raw bytes are absent');
  exact(
    createHash('sha256').update(workflowBytes).digest('hex'),
    workflowBlobSha,
    'workflow raw SHA-256',
  );

  process.stdout.write(
    `ET13 ${kind} artifact metadata: run ${runId}/${runAttempt}, artifact ${artifactId}\n`,
  );
}

await main();
