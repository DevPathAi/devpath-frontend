import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  appendFileSync,
  lstatSync,
  readFileSync,
} from 'node:fs';
import { pathToFileURL } from 'node:url';
import process from 'node:process';

const gitopsRepository = 'DevPathAi/devpath-gitops';
const frontendRepository = 'DevPathAi/devpath-frontend';
const candidateWorkflow = '.github/workflows/mission-spine-candidate.yml';
const baselineWorkflow = '.github/workflows/et13-baseline-approval.yml';

function fail(message) {
  throw new Error(`ET13 external artifact verification failed: ${message}`);
}

function options(argv) {
  const parsed = new Map();
  for (const value of argv) {
    if (!value.startsWith('--') || !value.includes('=')) {
      fail(`invalid option ${value}`);
    }
    const split = value.indexOf('=');
    const key = value.slice(2, split);
    if (parsed.has(key)) fail(`duplicate --${key}`);
    parsed.set(key, value.slice(split + 1));
  }
  return parsed;
}

function required(parsed, name) {
  const value = parsed.get(name);
  if (!value) fail(`missing --${name}`);
  return value;
}

function positiveInteger(value, name) {
  if (!/^[1-9][0-9]*$/.test(String(value))) {
    fail(`${name} must be a positive integer`);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) {
    fail(`${name} exceeds the safe integer range`);
  }
  return parsed;
}

function sha1(value, name) {
  if (!/^(?!0{40}$)[0-9a-f]{40}$/.test(value)) {
    fail(`${name} must be a nonzero Git SHA`);
  }
  return value;
}

function sha256(value, name) {
  if (!/^[0-9a-f]{64}$/.test(value)) {
    fail(`${name} must be a SHA-256 digest`);
  }
  return value;
}

function releaseId(value) {
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(value)) {
    fail('release-id is not a safe immutable identifier');
  }
  return value;
}

function exact(actual, expected, name) {
  if (actual !== expected) fail(`${name} mismatch`);
}

function rawSha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

async function github(path, token, fetchImpl = fetch) {
  const response = await fetchImpl(`https://api.github.com${path}`, {
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2022-11-28',
    },
    redirect: 'error',
  });
  if (!response.ok) {
    fail(`GitHub API ${path} returned HTTP ${response.status}`);
  }
  return response.json();
}

function validateRunPath(run, workflow) {
  if (typeof run.head_branch !== 'string' || run.head_branch.length < 1) {
    fail('run.head_branch is absent');
  }
  const allowed = new Set([
    workflow,
    `${workflow}@${run.head_branch}`,
    `${workflow}@refs/heads/${run.head_branch}`,
  ]);
  if (!allowed.has(run.path)) fail('run.path/ref mismatch');
}

export function validateMetadataResponse({
  kind,
  releaseId: id,
  runId,
  runAttempt,
  artifactId,
  frontendSha,
  run,
  artifact,
  workflowBytes,
  expectedWorkflowSha256,
}) {
  if (!['candidate', 'baseline'].includes(kind)) {
    fail('kind must be candidate or baseline');
  }
  const config =
    kind === 'candidate'
      ? {
          repository: gitopsRepository,
          workflow: candidateWorkflow,
          expectedHead: null,
          artifactName:
            `${id}-candidate-spec-run-${runId}-attempt-${runAttempt}`,
        }
      : {
          repository: frontendRepository,
          workflow: baselineWorkflow,
          expectedHead: frontendSha,
          artifactName:
            `${id}-frontend-visual-approved-baseline-run-${runId}-attempt-${runAttempt}`,
        };

  exact(run.id, runId, 'run.id');
  exact(run.run_attempt, runAttempt, 'run.run_attempt');
  exact(run.event, 'workflow_dispatch', 'run.event');
  exact(run.status, 'completed', 'run.status');
  exact(run.conclusion, 'success', 'run.conclusion');
  const headSha = sha1(run.head_sha, 'run.head_sha');
  if (config.expectedHead !== null) {
    exact(headSha, config.expectedHead, 'run.head_sha');
  }
  validateRunPath(run, config.workflow);
  exact(run.repository?.full_name, config.repository, 'run.repository');
  exact(
    run.head_repository?.full_name,
    config.repository,
    'run.head_repository',
  );
  if (kind === 'candidate' && run.head_branch === 'main') {
    fail('candidate run must originate from a candidate-only branch');
  }

  exact(artifact.id, artifactId, 'artifact.id');
  exact(artifact.name, config.artifactName, 'artifact.name');
  exact(artifact.expired, false, 'artifact.expired');
  exact(artifact.workflow_run?.id, runId, 'artifact.workflow_run.id');
  exact(
    artifact.workflow_run?.head_sha,
    headSha,
    'artifact.workflow_run.head_sha',
  );
  const digest = artifact.digest ?? '';
  if (!/^sha256:[0-9a-f]{64}$/.test(digest)) {
    fail('artifact.digest is absent or is not SHA-256');
  }
  if (!Number.isSafeInteger(artifact.size_in_bytes) ||
      artifact.size_in_bytes < 1) {
    fail('artifact is empty or has no bounded byte size');
  }
  const expiresAt = Date.parse(artifact.expires_at ?? '');
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    fail('artifact is expired or has no valid expiration timestamp');
  }

  let workflowSha256 = null;
  if (kind === 'baseline') {
    if (!Buffer.isBuffer(workflowBytes) || workflowBytes.length < 1) {
      fail('workflow raw bytes are absent');
    }
    workflowSha256 = rawSha256(workflowBytes);
    exact(
      workflowSha256,
      sha256(expectedWorkflowSha256, 'workflow-sha256'),
      'workflow raw SHA-256',
    );
  }

  return {
    headSha,
    headBranch: run.head_branch,
    artifactName: artifact.name,
    artifactArchiveSha256: digest.slice('sha256:'.length),
    workflowSha256,
  };
}

export function validateCandidateSourceFacts(facts) {
  const expectedPath =
    `release-manifests/candidates/${facts.releaseId}.candidate-spec.json`;
  exact(facts.repository, gitopsRepository, 'candidate.gitops.repository');
  exact(facts.checkedHeadSha, facts.headSha, 'checked candidate HEAD');
  if (
    !Array.isArray(facts.parentShas) ||
    facts.parentShas.length !== 1 ||
    facts.parentShas[0] !== facts.baseSha
  ) {
    fail('candidate HEAD must have exactly one parent equal to gitops.base_sha');
  }
  exact(
    facts.remoteMainSha,
    facts.baseSha,
    'protected remote main versus gitops.base_sha',
  );
  exact(facts.candidatePath, expectedPath, 'candidate path');
  if (
    facts.changedPaths.length !== 1 ||
    facts.changedPaths[0] !== expectedPath
  ) {
    fail('candidate commit must change only the fixed candidate path');
  }
  if (
    facts.changedStatuses.length !== 1 ||
    facts.changedStatuses[0] !== `A\t${expectedPath}`
  ) {
    fail('candidate commit must add exactly the fixed candidate path');
  }
  if (facts.workflowChanged) {
    fail('candidate producer workflow differs between protected base and HEAD');
  }
  if (!facts.candidateBytesEqual) {
    fail('downloaded candidate bytes differ from the candidate Git blob');
  }
  if (!facts.candidateShaMatches) {
    fail('downloaded candidate raw SHA-256 differs from the dispatch binding');
  }
  if (!facts.sourceTreeClean) {
    fail('candidate checkout is not clean');
  }
}

function git(root, args, encoding = 'utf8') {
  return execFileSync('git', args, {
    cwd: root,
    encoding,
    windowsHide: true,
  });
}

function lines(value) {
  const trimmed = value.trim();
  return trimmed === '' ? [] : trimmed.split(/\r?\n/);
}

export async function authenticateMetadata(
  parsed,
  token,
  fetchImpl = fetch,
) {
  const kind = required(parsed, 'kind');
  const id = releaseId(required(parsed, 'release-id'));
  const runId = positiveInteger(required(parsed, 'run-id'), 'run-id');
  const runAttempt = positiveInteger(
    required(parsed, 'run-attempt'),
    'run-attempt',
  );
  const artifactId = positiveInteger(
    required(parsed, 'artifact-id'),
    'artifact-id',
  );
  const frontendSha = sha1(
    required(parsed, 'frontend-sha'),
    'frontend-sha',
  );
  const config =
    kind === 'candidate'
      ? { repository: gitopsRepository, workflow: candidateWorkflow }
      : kind === 'baseline'
        ? { repository: frontendRepository, workflow: baselineWorkflow }
        : fail('kind must be candidate, baseline, or candidate-source');

  const run = await github(
    `/repos/${config.repository}/actions/runs/${runId}/attempts/${runAttempt}`,
    token,
    fetchImpl,
  );
  const artifact = await github(
    `/repos/${config.repository}/actions/artifacts/${artifactId}`,
    token,
    fetchImpl,
  );

  let workflowBytes = null;
  let expectedWorkflowSha256 = null;
  if (kind === 'baseline') {
    expectedWorkflowSha256 = sha256(
      required(parsed, 'workflow-sha256'),
      'workflow-sha256',
    );
    const headSha = sha1(run.head_sha, 'run.head_sha');
    const encoded = config.workflow
      .split('/')
      .map((part) => encodeURIComponent(part))
      .join('/');
    const workflow = await github(
      `/repos/${config.repository}/contents/${encoded}?ref=${headSha}`,
      token,
      fetchImpl,
    );
    exact(workflow.type, 'file', 'workflow.type');
    exact(workflow.path, config.workflow, 'workflow.path');
    exact(workflow.encoding, 'base64', 'workflow.encoding');
    workflowBytes = Buffer.from(
      (workflow.content ?? '').replace(/\s/g, ''),
      'base64',
    );
  }

  return validateMetadataResponse({
    kind,
    releaseId: id,
    runId,
    runAttempt,
    artifactId,
    frontendSha,
    run,
    artifact,
    workflowBytes,
    expectedWorkflowSha256,
  });
}

export async function validateCandidateSource(
  parsed,
  token,
  fetchImpl = fetch,
) {
  const id = releaseId(required(parsed, 'release-id'));
  const headSha = sha1(required(parsed, 'head-sha'), 'head-sha');
  const expectedCandidateSha = sha256(
    required(parsed, 'candidate-spec-sha256'),
    'candidate-spec-sha256',
  );
  const root = required(parsed, 'checkout-root');
  const artifactPath = required(parsed, 'candidate-path');
  const artifactStat = lstatSync(artifactPath);
  if (!artifactStat.isFile() || artifactStat.isSymbolicLink()) {
    fail('downloaded candidate must be one regular non-link file');
  }
  const artifactBytes = readFileSync(artifactPath);
  const candidate = JSON.parse(artifactBytes.toString('utf8'));
  exact(candidate.release_id, id, 'candidate.release_id');
  const repository = candidate.gitops?.repository;
  const baseSha = sha1(candidate.gitops?.base_sha, 'candidate.gitops.base_sha');
  const candidatePath =
    `release-manifests/candidates/${id}.candidate-spec.json`;
  const checkedHeadSha = git(root, ['rev-parse', '--verify', 'HEAD']).trim();
  const parentLine = git(root, [
    'rev-list',
    '--parents',
    '-n',
    '1',
    'HEAD',
  ]).trim();
  const parentShas = parentLine.split(/\s+/).slice(1);
  const protectedMain = await github(
    `/repos/${gitopsRepository}/git/ref/heads/main`,
    token,
    fetchImpl,
  );
  exact(protectedMain.ref, 'refs/heads/main', 'protected main ref');
  exact(protectedMain.object?.type, 'commit', 'protected main object type');
  const remoteMainSha = sha1(
    protectedMain.object?.sha,
    'protected main SHA',
  );
  const protectedBranch = await github(
    `/repos/${gitopsRepository}/branches/main`,
    token,
    fetchImpl,
  );
  exact(protectedBranch.name, 'main', 'protected branch name');
  exact(
    protectedBranch.commit?.sha,
    remoteMainSha,
    'protected branch commit SHA',
  );
  exact(protectedBranch.protected, true, 'protected branch policy');
  const changedPaths = lines(
    git(root, ['diff', '--name-only', `${baseSha}...HEAD`]),
  );
  const changedStatuses = lines(
    git(root, ['diff', '--name-status', `${baseSha}...HEAD`]),
  );
  const workflowDiff = spawnSync(
    'git',
    ['diff', '--quiet', baseSha, 'HEAD', '--', candidateWorkflow],
    { cwd: root, windowsHide: true },
  );
  if (![0, 1].includes(workflowDiff.status)) {
    fail('git workflow comparison failed');
  }
  const candidateGitBytes = readFileSync(
    new URL(
      candidatePath.replaceAll('\\', '/'),
      pathToFileURL(`${root}/`),
    ),
  );
  const baseWorkflowBytes = git(
    root,
    ['show', `${baseSha}:${candidateWorkflow}`],
    null,
  );
  const headWorkflowBytes = readFileSync(
    new URL(
      candidateWorkflow,
      pathToFileURL(`${root}/`),
    ),
  );
  const sourceTreeClean =
    git(root, ['status', '--porcelain=v1', '--untracked-files=all']).trim() ===
    '';

  validateCandidateSourceFacts({
    releaseId: id,
    repository,
    headSha,
    checkedHeadSha,
    baseSha,
    parentShas,
    remoteMainSha,
    candidatePath,
    changedPaths,
    changedStatuses,
    workflowChanged:
      workflowDiff.status === 1 ||
      !Buffer.from(baseWorkflowBytes).equals(headWorkflowBytes),
    candidateBytesEqual: artifactBytes.equals(candidateGitBytes),
    candidateShaMatches: rawSha256(artifactBytes) === expectedCandidateSha,
    sourceTreeClean,
  });

  return {
    baseSha,
    candidatePath,
    workflowSha256: rawSha256(headWorkflowBytes),
  };
}

function writeOutputs(kind, result) {
  const outputPath = process.env.GITHUB_OUTPUT;
  if (!outputPath) return;
  const prefix =
    kind === 'candidate-source'
      ? 'candidate'
      : kind;
  const values =
    kind === 'candidate-source'
      ? {
          candidate_base_sha: result.baseSha,
          candidate_source_path: result.candidatePath,
          candidate_workflow_sha256: result.workflowSha256,
        }
      : {
          [`${prefix}_head_sha`]: result.headSha,
          [`${prefix}_head_branch`]: result.headBranch,
          [`${prefix}_artifact_name`]: result.artifactName,
          [`${prefix}_artifact_archive_sha256`]:
            result.artifactArchiveSha256,
          ...(
            result.workflowSha256 === null
              ? {}
              : { [`${prefix}_workflow_sha256`]: result.workflowSha256 }
          ),
        };
  for (const [key, value] of Object.entries(values)) {
    appendFileSync(outputPath, `${key}=${value}\n`, {
      encoding: 'utf8',
    });
  }
}

async function main() {
  const parsed = options(process.argv.slice(2));
  const kind = required(parsed, 'kind');
  const token = process.env.GITHUB_TOKEN;
  if (!token) fail('GITHUB_TOKEN credential is absent');
  const result =
    kind === 'candidate-source'
      ? await validateCandidateSource(parsed, token)
      : await authenticateMetadata(parsed, token);
  writeOutputs(kind, result);
  process.stdout.write(
    kind === 'candidate-source'
      ? `ET13 candidate source chain: ${result.baseSha} -> verified HEAD\n`
      : `ET13 ${kind} artifact metadata: authenticated\n`,
  );
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  await main();
}
