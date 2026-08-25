import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  authenticateMetadata,
  validateCandidateSource,
  validateCandidateSourceFacts,
  validateMetadataResponse,
} from './verify_external_artifact.mjs';

const releaseId = 'ms-20260816-et13';
const frontendSha = '1234567890abcdef1234567890abcdef12345678';
const candidateHead = 'abcdef1234567890abcdef1234567890abcdef12';
const baseSha = 'fedcba0987654321fedcba0987654321fedcba09';
const workflow =
  '.github/workflows/mission-spine-candidate.yml';
const candidateWorkflowBytes = Buffer.from('trusted candidate workflow\n');
const candidateWorkflowSha256 = createHash('sha256')
  .update(candidateWorkflowBytes)
  .digest('hex');
const candidatePath =
  `release-manifests/candidates/${releaseId}.candidate-spec.json`;

function candidateRun(overrides = {}) {
  return {
    id: 101,
    run_attempt: 2,
    event: 'workflow_dispatch',
    status: 'completed',
    conclusion: 'success',
    head_sha: candidateHead,
    head_branch: 'candidate/et13',
    path: `${workflow}@candidate/et13`,
    repository: { full_name: 'DevPathAi/devpath-gitops' },
    head_repository: { full_name: 'DevPathAi/devpath-gitops' },
    ...overrides,
  };
}

function candidateArtifact(overrides = {}) {
  return {
    id: 202,
    name: `${releaseId}-candidate-spec-run-101-attempt-2`,
    expired: false,
    expires_at: '2099-01-01T00:00:00Z',
    size_in_bytes: 1024,
    digest:
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    workflow_run: { id: 101, head_sha: candidateHead },
    ...overrides,
  };
}

function jsonResponse(value, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async json() {
      return value;
    },
  };
}

test('candidate metadata derives immutable head from the successful attempt', () => {
  const result = validateMetadataResponse({
    kind: 'candidate',
    releaseId,
    runId: 101,
    runAttempt: 2,
    artifactId: 202,
    frontendSha,
    run: candidateRun(),
    artifact: candidateArtifact(),
    workflowBytes: candidateWorkflowBytes,
  });
  assert.equal(result.headSha, candidateHead);
  assert.equal(result.workflowSha256, candidateWorkflowSha256);
  assert.equal(
    result.artifactArchiveSha256,
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  );
});

test('candidate API authentication hashes the exact producer workflow bytes', async () => {
  const parsed = new Map([
    ['kind', 'candidate'],
    ['release-id', releaseId],
    ['run-id', '101'],
    ['run-attempt', '2'],
    ['artifact-id', '202'],
    ['frontend-sha', frontendSha],
  ]);
  const fetchImpl = async (url) => {
    if (url.includes('/actions/runs/101/attempts/2')) {
      return jsonResponse(candidateRun());
    }
    if (url.includes('/actions/artifacts/202')) {
      return jsonResponse(candidateArtifact());
    }
    if (url.includes('/contents/')) {
      return jsonResponse({
        type: 'file',
        path: workflow,
        encoding: 'base64',
        content: candidateWorkflowBytes.toString('base64'),
      });
    }
    throw new Error(`unexpected test URL: ${url}`);
  };
  assert.equal(
    (await authenticateMetadata(parsed, 'test-token', fetchImpl))
      .workflowSha256,
    candidateWorkflowSha256,
  );
});

test('candidate metadata rejects wrong attempt, workflow ref, artifact, and digest', () => {
  const mutations = [
    { run: candidateRun({ run_attempt: 3 }), artifact: candidateArtifact() },
    {
      run: candidateRun({ path: `${workflow}@attacker/ref` }),
      artifact: candidateArtifact(),
    },
    { run: candidateRun(), artifact: candidateArtifact({ id: 999 }) },
    { run: candidateRun(), artifact: candidateArtifact({ digest: null }) },
    {
      run: candidateRun(),
      artifact: candidateArtifact({ size_in_bytes: 0 }),
    },
    {
      run: candidateRun(),
      artifact: candidateArtifact({
        workflow_run: { id: 101, head_sha: baseSha },
      }),
    },
  ];
  for (const mutation of mutations) {
    assert.throws(
      () =>
        validateMetadataResponse({
          kind: 'candidate',
          releaseId,
          runId: 101,
          runAttempt: 2,
          artifactId: 202,
          frontendSha,
          ...mutation,
        }),
      /ET13 external artifact verification failed/,
    );
  }
});

test('baseline metadata requires the exact current-source protected workflow bytes', () => {
  const run = {
    ...candidateRun(),
    id: 303,
    run_attempt: 1,
    head_sha: frontendSha,
    head_branch: 'main',
    path: '.github/workflows/et13-baseline-approval.yml@main',
    repository: { full_name: 'DevPathAi/devpath-frontend' },
    head_repository: { full_name: 'DevPathAi/devpath-frontend' },
  };
  const artifact = {
    ...candidateArtifact(),
    id: 404,
    name:
      `${releaseId}-frontend-visual-approved-baseline-run-303-attempt-1`,
    workflow_run: { id: 303, head_sha: frontendSha },
  };
  const bytes = Buffer.from('protected workflow\n');
  const expected =
    'e325a31b7d462fa669d1d390a2cb30f93ec80d174f341d81f0342be0114acece';
  assert.equal(
    validateMetadataResponse({
      kind: 'baseline',
      releaseId,
      runId: 303,
      runAttempt: 1,
      artifactId: 404,
      frontendSha,
      run,
      artifact,
      workflowBytes: bytes,
      expectedWorkflowSha256: expected,
    }).workflowSha256,
    expected,
  );
  assert.throws(
    () =>
      validateMetadataResponse({
        kind: 'baseline',
        releaseId,
        runId: 303,
        runAttempt: 1,
        artifactId: 404,
        frontendSha,
        run,
        artifact,
        workflowBytes: null,
        expectedWorkflowSha256: expected,
      }),
    /workflow raw bytes are absent/,
  );
});

test('baseline API authentication fails closed when the protected workflow is absent', async () => {
  const workflowBytes = Buffer.from('protected workflow\n');
  const expectedWorkflowSha256 = createHash('sha256')
    .update(workflowBytes)
    .digest('hex');
  const run = {
    ...candidateRun(),
    id: 303,
    run_attempt: 1,
    head_sha: frontendSha,
    head_branch: 'main',
    path: '.github/workflows/et13-baseline-approval.yml@main',
    repository: { full_name: 'DevPathAi/devpath-frontend' },
    head_repository: { full_name: 'DevPathAi/devpath-frontend' },
  };
  const artifact = {
    ...candidateArtifact(),
    id: 404,
    name:
      `${releaseId}-frontend-visual-approved-baseline-run-303-attempt-1`,
    workflow_run: { id: 303, head_sha: frontendSha },
  };
  const parsed = new Map([
    ['kind', 'baseline'],
    ['release-id', releaseId],
    ['run-id', '303'],
    ['run-attempt', '1'],
    ['artifact-id', '404'],
    ['frontend-sha', frontendSha],
    ['workflow-sha256', expectedWorkflowSha256],
  ]);
  const fetchImpl = async (url) => {
    if (url.includes('/actions/runs/303/attempts/1')) {
      return jsonResponse(run);
    }
    if (url.includes('/actions/artifacts/404')) {
      return jsonResponse(artifact);
    }
    if (url.includes('/contents/')) {
      return jsonResponse({ message: 'Not Found' }, 404);
    }
    throw new Error(`unexpected test URL: ${url}`);
  };
  await assert.rejects(
    authenticateMetadata(parsed, 'test-token', fetchImpl),
    /returned HTTP 404/,
  );

  const positiveFetch = async (url) => {
    if (url.includes('/actions/runs/303/attempts/1')) {
      return jsonResponse(run);
    }
    if (url.includes('/actions/artifacts/404')) {
      return jsonResponse(artifact);
    }
    if (url.includes('/contents/')) {
      return jsonResponse({
        type: 'file',
        path: '.github/workflows/et13-baseline-approval.yml',
        encoding: 'base64',
        content: workflowBytes.toString('base64'),
      });
    }
    throw new Error(`unexpected test URL: ${url}`);
  };
  assert.equal(
    (await authenticateMetadata(parsed, 'test-token', positiveFetch))
      .workflowSha256,
    expectedWorkflowSha256,
  );
});

function sourceFacts(overrides = {}) {
  return {
    releaseId,
    repository: 'DevPathAi/devpath-gitops',
    headSha: candidateHead,
    checkedHeadSha: candidateHead,
    baseSha,
    parentShas: [baseSha],
    remoteMainSha: baseSha,
    candidatePath,
    changedPaths: [candidatePath],
    changedStatuses: [`A\t${candidatePath}`],
    workflowChanged: false,
    candidateBytesEqual: true,
    candidateShaMatches: true,
    sourceTreeClean: true,
    ...overrides,
  };
}

test('candidate source accepts only one candidate-only child of protected main', () => {
  assert.doesNotThrow(() => validateCandidateSourceFacts(sourceFacts()));
});

test('candidate source rejects malicious base, workflow, repository, and extra diff', () => {
  const mutations = [
    { repository: 'attacker/devpath-gitops' },
    { parentShas: [candidateHead] },
    { remoteMainSha: candidateHead },
    { workflowChanged: true },
    { changedPaths: [candidatePath, workflow] },
    { changedStatuses: [`M\t${candidatePath}`] },
    { candidateBytesEqual: false },
    { candidateShaMatches: false },
    { sourceTreeClean: false },
  ];
  for (const mutation of mutations) {
    assert.throws(
      () => validateCandidateSourceFacts(sourceFacts(mutation)),
      /ET13 external artifact verification failed/,
    );
  }
});

test('candidate source authenticates an actual one-file child tree', async () => {
  const temporary = mkdtempSync(join(tmpdir(), 'et13-candidate-source-'));
  const root = join(temporary, 'checkout');
  mkdirSync(root);
  const candidateArtifactPath = join(
    temporary,
    'downloaded-candidate-spec.json',
  );
  const candidateRelativePath =
    `release-manifests/candidates/${releaseId}.candidate-spec.json`;
  try {
    const git = (arguments_) =>
      execFileSync('git', arguments_, {
        cwd: root,
        encoding: 'utf8',
        windowsHide: true,
      }).trim();
    git(['init']);
    git(['config', 'user.name', 'ET13 Contract']);
    git(['config', 'user.email', 'et13@example.invalid']);
    mkdirSync(join(root, '.github', 'workflows'), { recursive: true });
    writeFileSync(join(root, workflow), 'protected candidate workflow\n');
    git(['add', workflow]);
    git(['commit', '-m', 'protected base']);
    const protectedBase = git(['rev-parse', 'HEAD']);
    const candidate = {
      release_id: releaseId,
      gitops: {
        repository: 'DevPathAi/devpath-gitops',
        base_sha: protectedBase,
      },
    };
    const candidateBytes = `${JSON.stringify(candidate, null, 2)}\n`;
    const checkedCandidatePath = join(root, candidateRelativePath);
    mkdirSync(join(root, 'release-manifests', 'candidates'), {
      recursive: true,
    });
    writeFileSync(checkedCandidatePath, candidateBytes);
    git(['add', candidateRelativePath]);
    git(['commit', '-m', 'candidate only']);
    const head = git(['rev-parse', 'HEAD']);
    writeFileSync(candidateArtifactPath, readFileSync(checkedCandidatePath));
    const digest = createHash('sha256')
      .update(readFileSync(candidateArtifactPath))
      .digest('hex');
    const parsed = new Map([
      ['release-id', releaseId],
      ['head-sha', head],
      ['candidate-spec-sha256', digest],
      ['checkout-root', root],
      ['candidate-path', candidateArtifactPath],
    ]);
    const fetchImpl = async (url) => {
      if (url.endsWith('/git/ref/heads/main')) {
        return jsonResponse({
          ref: 'refs/heads/main',
          object: { type: 'commit', sha: protectedBase },
        });
      }
      if (url.endsWith('/branches/main')) {
        return jsonResponse({
          name: 'main',
          commit: { sha: protectedBase },
          protected: true,
        });
      }
      throw new Error(`unexpected test URL: ${url}`);
    };
    const result = await validateCandidateSource(
      parsed,
      'test-token',
      fetchImpl,
    );
    assert.equal(result.baseSha, protectedBase);
    assert.equal(result.candidatePath, candidateRelativePath);

    await assert.rejects(
      validateCandidateSource(parsed, 'test-token', async () =>
        jsonResponse({
          ref: 'refs/heads/attacker',
          object: { type: 'commit', sha: protectedBase },
        })),
      /protected main ref mismatch/,
    );
    await assert.rejects(
      validateCandidateSource(parsed, 'test-token', async (url) => {
        if (url.endsWith('/git/ref/heads/main')) {
          return jsonResponse({
            ref: 'refs/heads/main',
            object: { type: 'commit', sha: protectedBase },
          });
        }
        if (url.endsWith('/branches/main')) {
          return jsonResponse({
            name: 'main',
            commit: { sha: protectedBase },
            protected: false,
          });
        }
        throw new Error(`unexpected test URL: ${url}`);
      }),
      /protected branch policy mismatch/,
    );

    rmSync(join(root, workflow));
    await assert.rejects(
      validateCandidateSource(parsed, 'test-token', fetchImpl),
    );
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
});
