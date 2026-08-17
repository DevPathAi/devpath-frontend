import assert from 'node:assert/strict';
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import test from 'node:test';

import {
  createManualEvidence,
  validateAllManualCatalogs,
  validateManualEvidencePackages,
  validateSignedMobileArtifactFacts,
} from './mission_spine_manual_at_evidence.mjs';

const root = resolve(import.meta.dirname, '..');
const sourceSha = '1234567890abcdef1234567890abcdef12345678';
const candidateSha256 = '1'.repeat(64);

const expectedCases = {
  'manual-nvda': [
    'nvda-web-today-mission-spine',
    'nvda-web-next-action-navigation',
  ],
  'manual-voiceover': [
    'voiceover-ios-today-mission-spine',
    'voiceover-ios-next-action-navigation',
    'voiceover-ios-content-reading',
    'voiceover-ios-offline-status',
  ],
  'manual-talkback': [
    'talkback-android-today-mission-spine',
    'talkback-android-next-action-navigation',
    'talkback-android-content-reading',
    'talkback-android-offline-status',
  ],
};

function approval(lane) {
  const suffix = lane.slice('manual-'.length);
  const title = {
    nvda: 'NVDA',
    voiceover: 'VoiceOver',
    talkback: 'TalkBack',
  }[suffix];
  return {
    approval_environment: lane.replace('manual-', 'manual-at-'),
    approval_environment_id: 100 + Object.keys(expectedCases).indexOf(lane),
    approval_job_name: `Approve manual ${title} evidence`,
    approved_by: 'independent-reviewer',
    approved_by_id: 501,
    approval_effective_at: '2025-08-17T01:02:03Z',
    workflow_sha256: '2'.repeat(64),
  };
}

function candidateFromCatalogs(catalogs) {
  const bindings = {};
  for (const [lane, value] of Object.entries(catalogs)) {
    bindings[lane] = {
      repository: 'DevPathAi/devpath-frontend',
      source_sha: sourceSha,
      path: value.catalog_path,
      sha256: value.catalog_sha256,
      case_count: value.case_count,
      provenance_sha256: value.provenance_sha256,
    };
  }
  return {
    $schema: 'https://example.invalid/candidate.schema.json',
    schema_version: 'mission-spine.candidate-spec.v1',
    document_type: 'candidate-spec',
    release_id: 'release-2026-08-17',
    created_at: '2025-08-17T00:00:00Z',
    gitops: {},
    services: {},
    shared_migration: {},
    frontend: {
      repository: 'DevPathAi/devpath-frontend',
      source_sha: sourceSha,
    },
    home: {},
    analytics_privacy: {},
    ai_release_eval_config: {},
    environments: {},
    journey_harness: {},
    quality_evidence_inputs: {
      catalogs: bindings,
      frontend_projection_contract: {},
      mobile_test_artifacts: {
        schema_version: 'leva.mission-spine.signed-mobile-build-binding.v1',
        repository: 'DevPathAi/devpath-frontend',
        source_sha: sourceSha,
        event: 'workflow_dispatch',
        workflow_path:
          '.github/workflows/mission-spine-signed-mobile-build.yml',
        workflow_sha256: '3'.repeat(64),
        workflow_run_id: 701,
        run_attempt: 1,
        artifact_id: 801,
        artifact_name:
          'release-2026-08-17-signed-mobile-build-run-701-attempt-1',
        artifact_archive_sha256: '4'.repeat(64),
        build_provenance_file: 'build-provenance.v1.json',
        build_provenance_sha256: '5'.repeat(64),
        signed_apk_file: 'mobile/android/leva-release.apk',
        signed_apk_sha256: '6'.repeat(64),
        signed_ipa_file: 'mobile/ios/leva-release.ipa',
        signed_ipa_sha256: '7'.repeat(64),
      },
    },
    rollout: {},
  };
}

test('manual catalogs and static provenance have exact reviewed order and bytes', () => {
  const catalogs = validateAllManualCatalogs(root);
  assert.deepEqual(Object.keys(catalogs), Object.keys(expectedCases));
  for (const [lane, expected] of Object.entries(expectedCases)) {
    assert.deepEqual(catalogs[lane].case_ids, expected);
    assert.equal(catalogs[lane].case_count, expected.length);
    assert.match(catalogs[lane].catalog_sha256, /^[0-9a-f]{64}$/);
    assert.match(catalogs[lane].provenance_sha256, /^[0-9a-f]{64}$/);
  }
});

test('manual evidence uses exact lane keys and protected approval identity', () => {
  const catalogs = validateAllManualCatalogs(root);
  const candidate = candidateFromCatalogs(catalogs);
  for (const lane of Object.keys(expectedCases)) {
    const evidence = createManualEvidence({
      lane,
      candidate,
      candidateSpecSha256: candidateSha256,
      releaseId: 'release-2026-08-17',
      sourceSha,
      producerRunId: 901,
      producerRunAttempt: 1,
      approval: approval(lane),
      repositoryRoot: root,
    });
    assert.equal(evidence.status, 'passed');
    assert.equal(evidence.case_count, expectedCases[lane].length);
    assert.equal(evidence.passed_case_count, expectedCases[lane].length);
    assert.equal(evidence.failed_case_count, 0);
    assert.equal(
      evidence.approval_environment,
      lane.replace('manual-', 'manual-at-'),
    );
    const commonKeys = [
      'candidate_spec_sha256',
      'status',
      'producer_run_id',
      'producer_run_attempt',
      'repository',
      'source_sha',
      'case_catalog_sha256',
      'case_count',
      'passed_case_count',
      'failed_case_count',
      'assistive_technology',
      'test_provenance_sha256',
    ];
    const approvalKeys = [
      'approval_environment',
      'approval_environment_id',
      'approval_job_name',
      'approved_by',
      'approved_by_id',
      'approval_effective_at',
    ];
    if (lane === 'manual-nvda') {
      assert.equal('build_provenance_sha256' in evidence, false);
      assert.deepEqual(Object.keys(evidence), [...commonKeys, ...approvalKeys]);
    } else {
      assert.equal(evidence.build_provenance_sha256, '5'.repeat(64));
      assert.deepEqual(Object.keys(evidence), [
        ...commonKeys,
        'build_provenance_sha256',
        lane === 'manual-voiceover'
          ? 'signed_ipa_sha256'
          : 'signed_apk_sha256',
        ...approvalKeys,
      ]);
    }
  }
});

test('manual evidence rejects attempt reuse, catalog drift, and unsafe review data', () => {
  const catalogs = validateAllManualCatalogs(root);
  const candidate = candidateFromCatalogs(catalogs);
  assert.throws(
    () =>
      createManualEvidence({
        lane: 'manual-nvda',
        candidate,
        candidateSpecSha256: candidateSha256,
        releaseId: 'release-2026-08-17',
        sourceSha,
        producerRunId: 901,
        producerRunAttempt: 2,
        approval: approval('manual-nvda'),
        repositoryRoot: root,
      }),
    /attempt 1/,
  );

  const drift = structuredClone(candidate);
  drift.quality_evidence_inputs.catalogs['manual-nvda'].case_count = 3;
  assert.throws(
    () =>
      createManualEvidence({
        lane: 'manual-nvda',
        candidate: drift,
        candidateSpecSha256: candidateSha256,
        releaseId: 'release-2026-08-17',
        sourceSha,
        producerRunId: 901,
        producerRunAttempt: 1,
        approval: approval('manual-nvda'),
        repositoryRoot: root,
      }),
    /case_count/,
  );

  const unsafe = approval('manual-nvda');
  unsafe.approved_by = 'data:text/plain,reviewer';
  assert.throws(
    () =>
      createManualEvidence({
        lane: 'manual-nvda',
        candidate,
        candidateSpecSha256: candidateSha256,
        releaseId: 'release-2026-08-17',
        sourceSha,
        producerRunId: 901,
        producerRunAttempt: 1,
        approval: unsafe,
        repositoryRoot: root,
      }),
    /approved_by/,
  );
});

test('three manual packages are jointly exact and reject extras', () => {
  const catalogs = validateAllManualCatalogs(root);
  const candidate = candidateFromCatalogs(catalogs);
  const packageRoot = mkdtempSync(join(tmpdir(), 'manual-at-packages-'));
  try {
    for (const lane of Object.keys(expectedCases)) {
      const laneRoot = join(packageRoot, lane);
      mkdirSync(laneRoot);
      const evidence = createManualEvidence({
        lane,
        candidate,
        candidateSpecSha256: candidateSha256,
        releaseId: 'release-2026-08-17',
        sourceSha,
        producerRunId: 901,
        producerRunAttempt: 1,
        approval: approval(lane),
        repositoryRoot: root,
      });
      writeFileSync(
        join(laneRoot, 'evidence.json'),
        `${JSON.stringify(evidence, null, 2)}\n`,
      );
    }
    assert.doesNotThrow(() =>
      validateManualEvidencePackages({
        packageRoot,
        candidate,
        candidateSpecSha256: candidateSha256,
        releaseId: 'release-2026-08-17',
        sourceSha,
        producerRunId: 901,
        producerRunAttempt: 1,
        repositoryRoot: root,
      }),
    );
    writeFileSync(join(packageRoot, 'manual-nvda', 'raw-notes.txt'), 'forbidden');
    assert.throws(
      () =>
        validateManualEvidencePackages({
          packageRoot,
          candidate,
          candidateSpecSha256: candidateSha256,
          releaseId: 'release-2026-08-17',
          sourceSha,
          producerRunId: 901,
          producerRunAttempt: 1,
          repositoryRoot: root,
        }),
      /exactly evidence.json/,
    );
  } finally {
    rmSync(packageRoot, { recursive: true, force: true });
  }
});

test('signed bundle metadata is attempt-specific, protected, and byte-bound', () => {
  const catalogs = validateAllManualCatalogs(root);
  const candidate = candidateFromCatalogs(catalogs);
  const binding = candidate.quality_evidence_inputs.mobile_test_artifacts;
  const workflowBytes = Buffer.from('trusted signed workflow\n');
  binding.workflow_sha256 =
    '730d931c8cd494ba27b747ade73d3f36b337db80860d911c22a0abe308e68b85';
  const facts = {
    binding,
    releaseId: candidate.release_id,
    sourceSha,
    run: {
      id: 701,
      run_attempt: 1,
      event: 'workflow_dispatch',
      status: 'completed',
      conclusion: 'success',
      head_sha: sourceSha,
      head_branch: 'main',
      path: '.github/workflows/mission-spine-signed-mobile-build.yml@main',
      repository: { full_name: 'DevPathAi/devpath-frontend' },
      head_repository: { full_name: 'DevPathAi/devpath-frontend' },
    },
    branch: { name: 'main', commit: { sha: sourceSha }, protected: true },
    artifact: {
      id: 801,
      name: 'release-2026-08-17-signed-mobile-build-run-701-attempt-1',
      expired: false,
      size_in_bytes: 1024,
      digest: `sha256:${'4'.repeat(64)}`,
      workflow_run: { id: 701, head_sha: sourceSha },
    },
    workflowBytes,
    localWorkflowBytes: Buffer.from(workflowBytes),
  };
  assert.doesNotThrow(() => validateSignedMobileArtifactFacts(facts));
  const stale = structuredClone({
    ...facts,
    workflowBytes: undefined,
    localWorkflowBytes: undefined,
  });
  stale.workflowBytes = workflowBytes;
  stale.localWorkflowBytes = Buffer.from(workflowBytes);
  stale.run.run_attempt = 2;
  assert.throws(
    () => validateSignedMobileArtifactFacts(stale),
    /run_attempt/,
  );
  const unprotected = {
    ...facts,
    branch: { ...facts.branch, protected: false },
  };
  assert.throws(
    () => validateSignedMobileArtifactFacts(unprotected),
    /protected branch policy/,
  );
  const substituted = {
    ...facts,
    localWorkflowBytes: Buffer.from('substituted workflow\n'),
  };
  assert.throws(
    () => validateSignedMobileArtifactFacts(substituted),
    /differs from exact checked source bytes/,
  );
});
