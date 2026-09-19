import assert from 'node:assert/strict';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
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
  validateManualInputs,
} from './mission_spine_manual_at_evidence.mjs';

const root = resolve(import.meta.dirname, '..');
const sourceSha = '1234567890abcdef1234567890abcdef12345678';
const candidateSha256 = '1'.repeat(64);
const releaseId = 'release-2026-08-17';

const expectedCases = {
  'manual-nvda': [
    'nvda-web-today-mission-spine',
    'nvda-web-next-action-navigation',
  ],
};

const evidenceKeyOrder = [
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
  'approval_environment',
  'approval_environment_id',
  'approval_job_name',
  'approved_by',
  'approved_by_id',
  'approval_effective_at',
];

const legacySignedBinding = {
  schema_version: 'leva.mission-spine.signed-android-build-binding.v2',
  repository: 'DevPathAi/devpath-frontend',
  source_sha: sourceSha,
  event: 'workflow_dispatch',
  workflow_path: '.github/workflows/mission-spine-signed-mobile-build.yml',
  workflow_sha256: '3'.repeat(64),
  workflow_run_id: 701,
  run_attempt: 1,
  artifact_id: 801,
  artifact_name: 'release-2026-08-17-signed-android-build-run-701-attempt-1',
  artifact_archive_sha256: '4'.repeat(64),
  build_provenance_file: 'build-provenance.v2.json',
  build_provenance_sha256: '5'.repeat(64),
  signed_apk_file: 'mobile/android/leva-release.apk',
  signed_apk_sha256: '6'.repeat(64),
};

function approval() {
  return {
    approval_environment: 'manual-at-nvda',
    approval_environment_id: 100,
    approval_job_name: 'Approve manual NVDA evidence',
    approved_by: 'independent-reviewer',
    approved_by_id: 501,
    approval_effective_at: '2025-08-17T01:02:03Z',
    workflow_sha256: '2'.repeat(64),
  };
}

function candidateFromCatalogs(catalogs) {
  const bindings = {
    'frontend-visual': {},
    'home-visual': {},
    'frontend-automated-a11y': {},
    'home-axe-browser-a11y': {},
  };
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
    release_id: releaseId,
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
    },
    rollout: {},
  };
}

function evidenceArguments(candidate, overrides = {}) {
  return {
    lane: 'manual-nvda',
    candidate,
    candidateSpecSha256: candidateSha256,
    releaseId,
    sourceSha,
    producerRunId: 901,
    producerRunAttempt: 1,
    approval: approval(),
    repositoryRoot: root,
    ...overrides,
  };
}

test('manual catalogs and static provenance have exact reviewed order and bytes', () => {
  const catalogs = validateAllManualCatalogs(root);
  assert.deepEqual(Object.keys(catalogs), ['manual-nvda']);
  for (const [lane, expected] of Object.entries(expectedCases)) {
    assert.deepEqual(catalogs[lane].case_ids, expected);
    assert.equal(catalogs[lane].case_count, expected.length);
    assert.match(catalogs[lane].catalog_sha256, /^[0-9a-f]{64}$/);
    assert.match(catalogs[lane].provenance_sha256, /^[0-9a-f]{64}$/);
  }
});

test('manual NVDA evidence keeps its exact key order and approval identity', () => {
  const candidate = candidateFromCatalogs(validateAllManualCatalogs(root));
  const evidence = createManualEvidence(evidenceArguments(candidate));
  assert.equal(evidence.status, 'passed');
  assert.equal(evidence.case_count, 2);
  assert.equal(evidence.passed_case_count, 2);
  assert.equal(evidence.failed_case_count, 0);
  assert.equal(evidence.assistive_technology, 'NVDA+Chromium');
  assert.equal(evidence.approval_environment, 'manual-at-nvda');
  assert.deepEqual(Object.keys(evidence), evidenceKeyOrder);
});

test('manual evidence rejects attempt reuse, catalog drift, and unsafe review data', () => {
  const candidate = candidateFromCatalogs(validateAllManualCatalogs(root));
  assert.throws(
    () => createManualEvidence(evidenceArguments(candidate, { producerRunAttempt: 2 })),
    /attempt 1/,
  );

  const drift = structuredClone(candidate);
  drift.quality_evidence_inputs.catalogs['manual-nvda'].case_count = 3;
  assert.throws(
    () => createManualEvidence(evidenceArguments(drift)),
    /case_count/,
  );

  const unsafe = approval();
  unsafe.approved_by = 'data:text/plain,reviewer';
  assert.throws(
    () => createManualEvidence(evidenceArguments(candidate, { approval: unsafe })),
    /approved_by/,
  );

  const legacyVoiceOver = structuredClone(candidate);
  legacyVoiceOver.quality_evidence_inputs.catalogs['manual-voiceover'] = {
    repository: 'DevPathAi/devpath-frontend',
  };
  assert.throws(
    () => createManualEvidence(evidenceArguments(legacyVoiceOver)),
    /candidate catalog bindings/,
  );
});

test('legacy signed-mobile and TalkBack candidate shapes fail closed', () => {
  const candidate = candidateFromCatalogs(validateAllManualCatalogs(root));

  const legacySigned = structuredClone(candidate);
  legacySigned.quality_evidence_inputs.mobile_test_artifacts = legacySignedBinding;
  assert.throws(
    () => createManualEvidence(evidenceArguments(legacySigned)),
    /candidate\.quality_evidence_inputs exact ordered key set mismatch/,
  );

  const legacyTalkBack = structuredClone(candidate);
  legacyTalkBack.quality_evidence_inputs.catalogs['manual-talkback'] = {
    repository: 'DevPathAi/devpath-frontend',
    source_sha: sourceSha,
    path: 'tool/release-evidence/catalogs/manual-talkback.v1.json',
    sha256: '7'.repeat(64),
    case_count: 4,
    provenance_sha256: '8'.repeat(64),
  };
  assert.throws(
    () => createManualEvidence(evidenceArguments(legacyTalkBack)),
    /candidate catalog bindings/,
  );

  assert.throws(
    () => createManualEvidence(evidenceArguments(candidate, { lane: 'manual-talkback' })),
    /unknown manual lane/,
  );
});

test('manual inputs validate without any signed bundle', () => {
  const catalogs = validateAllManualCatalogs(root);
  const candidate = candidateFromCatalogs(catalogs);
  const result = validateManualInputs({
    repositoryRoot: root,
    candidate,
    candidateSpecSha256: candidateSha256,
    releaseId,
    sourceSha,
  });
  assert.deepEqual(Object.keys(result), ['catalogs', 'candidateSpecSha256']);
  assert.deepEqual(Object.keys(result.catalogs), ['manual-nvda']);
  assert.equal(result.candidateSpecSha256, candidateSha256);
});

test('the single manual package is exact and rejects extras', () => {
  const candidate = candidateFromCatalogs(validateAllManualCatalogs(root));
  const packageRoot = mkdtempSync(join(tmpdir(), 'manual-at-packages-'));
  const packageArguments = {
    packageRoot,
    candidate,
    candidateSpecSha256: candidateSha256,
    releaseId,
    sourceSha,
    producerRunId: 901,
    producerRunAttempt: 1,
    repositoryRoot: root,
  };
  try {
    mkdirSync(join(packageRoot, 'manual-nvda'));
    writeFileSync(
      join(packageRoot, 'manual-nvda', 'evidence.json'),
      `${JSON.stringify(createManualEvidence(evidenceArguments(candidate)), null, 2)}\n`,
    );
    assert.doesNotThrow(() => validateManualEvidencePackages(packageArguments));

    mkdirSync(join(packageRoot, 'manual-talkback'));
    assert.throws(
      () => validateManualEvidencePackages(packageArguments),
      /exactly the manual lane directories/,
    );
    rmSync(join(packageRoot, 'manual-talkback'), { recursive: true });

    writeFileSync(join(packageRoot, 'manual-nvda', 'raw-notes.txt'), 'forbidden');
    assert.throws(
      () => validateManualEvidencePackages(packageArguments),
      /exactly evidence.json/,
    );
  } finally {
    rmSync(packageRoot, { recursive: true, force: true });
  }
});

test('the tool source carries no signed-mobile or TalkBack residue', () => {
  const source = readFileSync(
    new URL('./mission_spine_manual_at_evidence.mjs', import.meta.url),
    'utf8',
  );
  assert.doesNotMatch(source, /talkback|signed|mobile_test_artifacts|\.apk/i);
  assert.doesNotMatch(source, /mission_spine_release_evidence/);
});
