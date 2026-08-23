import { createHash } from 'node:crypto';
import {
  lstatSync,
  readFileSync,
  readdirSync,
  realpathSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import process from 'node:process';

import {
  frontendRepository,
  signedMobileWorkflow,
  validateExactSignedMobileBundle,
} from './mission_spine_release_evidence.mjs';

export const manualWorkflow =
  '.github/workflows/mission-spine-manual-at-evidence.yml';

const catalogSchema = 'leva.mission-spine.manual-at-catalog.v1';
const provenanceSchema =
  'leva.mission-spine.manual-at-test-provenance.v1';
const signedBindingSchema =
  'leva.mission-spine.signed-android-build-binding.v2';
const sha1Pattern = /^(?!0{40}$)[0-9a-f]{40}$/;
const sha256Pattern = /^(?!0{64}$)[0-9a-f]{64}$/;
const releaseIdPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const utcPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/;

const laneDefinitions = Object.freeze({
  'manual-nvda': Object.freeze({
    artifactLane: 'nvda',
    assistiveTechnology: 'NVDA+Chromium',
    surface: 'web',
    environment: 'manual-at-nvda',
    jobName: 'Approve manual NVDA evidence',
    requiredPlatform: 'windows_physical_host',
    requiredClient: 'chromium',
    requiredArtifact: 'exact_source_web_release_build',
    cases: Object.freeze([
      Object.freeze({ id: 'nvda-web-today-mission-spine', entry: 'today' }),
      Object.freeze({
        id: 'nvda-web-next-action-navigation',
        entry: 'next_action',
      }),
    ]),
  }),
  'manual-talkback': Object.freeze({
    artifactLane: 'talkback',
    assistiveTechnology: 'TalkBack+Android',
    surface: 'android',
    environment: 'manual-at-talkback',
    jobName: 'Approve manual TalkBack evidence',
    requiredPlatform: 'android_physical_device',
    requiredClient: 'native_flutter_android',
    requiredArtifact: 'candidate_signed_apk',
    cases: Object.freeze([
      Object.freeze({ id: 'talkback-android-today-mission-spine', entry: 'today' }),
      Object.freeze({
        id: 'talkback-android-next-action-navigation',
        entry: 'next_action',
      }),
      Object.freeze({ id: 'talkback-android-content-reading', entry: 'content' }),
      Object.freeze({ id: 'talkback-android-offline-status', entry: 'offline_status' }),
    ]),
  }),
});

const candidateCatalogKeys = Object.freeze([
  'frontend-visual',
  'home-visual',
  'frontend-automated-a11y',
  'home-axe-browser-a11y',
  ...Object.keys(laneDefinitions),
]);

function fail(message) {
  throw new Error(`Mission Spine manual AT evidence failed: ${message}`);
}

function exact(actual, expected, name) {
  if (actual !== expected) fail(`${name} mismatch`);
}

function object(value, name) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${name} must be an object`);
  }
  return value;
}

function exactKeys(value, expected, name) {
  const actual = Object.keys(object(value, name));
  if (
    actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])
  ) {
    fail(`${name} exact ordered key set mismatch`);
  }
}

function nonemptyLine(value, name) {
  if (
    typeof value !== 'string' ||
    value.length < 1 ||
    value !== value.trim() ||
    /[\r\n\0]/.test(value)
  ) {
    fail(`${name} must be one nonempty sanitized line`);
  }
  return value;
}

function positiveInteger(value, name) {
  if (!Number.isSafeInteger(value) || value < 1) {
    fail(`${name} must be a positive integer`);
  }
  return value;
}

function sha1(value, name) {
  if (typeof value !== 'string' || !sha1Pattern.test(value)) {
    fail(`${name} must be a nonzero lowercase Git SHA`);
  }
  return value;
}

function sha256(value, name) {
  if (typeof value !== 'string' || !sha256Pattern.test(value)) {
    fail(`${name} must be a nonzero lowercase SHA-256 digest`);
  }
  return value;
}

function utc(value, name) {
  if (
    typeof value !== 'string' ||
    !utcPattern.test(value) ||
    !Number.isFinite(Date.parse(value))
  ) {
    fail(`${name} must be an exact UTC timestamp ending in Z`);
  }
  return value;
}

function rawSha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function regularFile(path, name) {
  const info = lstatSync(path);
  if (!info.isFile() || info.isSymbolicLink()) {
    fail(`${name} must be one regular non-link file`);
  }
  return info;
}

function regularDirectory(path, name) {
  const info = lstatSync(path);
  if (!info.isDirectory() || info.isSymbolicLink()) {
    fail(`${name} must be one regular non-link directory`);
  }
  return info;
}

function parseJsonFile(path, name, maximumBytes = 256 * 1024) {
  const info = regularFile(path, name);
  if (info.size > maximumBytes) fail(`${name} exceeds ${maximumBytes} bytes`);
  const bytes = readFileSync(path);
  if (
    bytes.length >= 3 &&
    bytes.subarray(0, 3).equals(Buffer.from([0xef, 0xbb, 0xbf]))
  ) {
    fail(`${name} must be UTF-8 without BOM`);
  }
  let value;
  try {
    value = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
  } catch (error) {
    fail(`${name} must be valid UTF-8 JSON: ${error.message}`);
  }
  return { bytes, value };
}

function exactStringArray(value, expected, name) {
  if (
    !Array.isArray(value) ||
    value.length !== expected.length ||
    value.some((entry, index) => entry !== expected[index])
  ) {
    fail(`${name} exact order mismatch`);
  }
}

function validateCatalog(value, lane) {
  const definition = laneDefinitions[lane];
  exactKeys(
    value,
    [
      'schema_version',
      'lane',
      'assistive_technology',
      'test_provenance_path',
      'case_count',
      'cases',
    ],
    `${lane} catalog`,
  );
  exact(value.schema_version, catalogSchema, `${lane}.schema_version`);
  exact(value.lane, lane, `${lane}.lane`);
  exact(
    value.assistive_technology,
    definition.assistiveTechnology,
    `${lane}.assistive_technology`,
  );
  exact(
    value.test_provenance_path,
    `tool/release-evidence/provenance/${lane}.v1.json`,
    `${lane}.test_provenance_path`,
  );
  exact(value.case_count, definition.cases.length, `${lane}.case_count`);
  if (!Array.isArray(value.cases) || value.cases.length !== definition.cases.length) {
    fail(`${lane}.cases exact count mismatch`);
  }
  value.cases.forEach((entry, index) => {
    const expected = definition.cases[index];
    exactKeys(
      entry,
      ['id', 'surface', 'entry_point', 'procedure', 'expected'],
      `${lane}.cases[${index}]`,
    );
    exact(entry.id, expected.id, `${lane}.cases[${index}].id`);
    exact(entry.surface, definition.surface, `${lane}.cases[${index}].surface`);
    exact(entry.entry_point, expected.entry, `${lane}.cases[${index}].entry_point`);
    for (const key of ['procedure', 'expected']) {
      if (!Array.isArray(entry[key]) || entry[key].length < 1) {
        fail(`${lane}.cases[${index}].${key} must be nonempty`);
      }
      entry[key].forEach((line, lineIndex) =>
        nonemptyLine(line, `${lane}.cases[${index}].${key}[${lineIndex}]`),
      );
    }
  });
}

function validateProvenance(value, lane, catalogPath, catalogSha256) {
  const definition = laneDefinitions[lane];
  exactKeys(
    value,
    [
      'schema_version',
      'lane',
      'catalog_path',
      'catalog_sha256',
      'assistive_technology',
      'execution_mode',
      'required_platform',
      'required_client',
      'required_artifact',
      'case_ids',
      'pass_policy',
    ],
    `${lane} provenance`,
  );
  exact(value.schema_version, provenanceSchema, `${lane}.provenance.schema_version`);
  exact(value.lane, lane, `${lane}.provenance.lane`);
  exact(value.catalog_path, catalogPath, `${lane}.provenance.catalog_path`);
  exact(value.catalog_sha256, catalogSha256, `${lane}.provenance.catalog_sha256`);
  exact(
    value.assistive_technology,
    definition.assistiveTechnology,
    `${lane}.provenance.assistive_technology`,
  );
  exact(value.execution_mode, 'manual_human', `${lane}.execution_mode`);
  exact(value.required_platform, definition.requiredPlatform, `${lane}.required_platform`);
  exact(value.required_client, definition.requiredClient, `${lane}.required_client`);
  exact(value.required_artifact, definition.requiredArtifact, `${lane}.required_artifact`);
  exactStringArray(
    value.case_ids,
    definition.cases.map((entry) => entry.id),
    `${lane}.case_ids`,
  );
  exactKeys(
    value.pass_policy,
    [
      'all_cases_required',
      'failed_case_count',
      'synthetic_results_allowed',
      'emulator_allowed',
    ],
    `${lane}.pass_policy`,
  );
  exact(value.pass_policy.all_cases_required, true, `${lane}.all_cases_required`);
  exact(value.pass_policy.failed_case_count, 0, `${lane}.failed_case_count`);
  exact(
    value.pass_policy.synthetic_results_allowed,
    false,
    `${lane}.synthetic_results_allowed`,
  );
  exact(value.pass_policy.emulator_allowed, false, `${lane}.emulator_allowed`);
}

export function validateAllManualCatalogs(repositoryRoot) {
  const root = resolve(repositoryRoot);
  const result = {};
  for (const [lane, definition] of Object.entries(laneDefinitions)) {
    const catalogPath = `tool/release-evidence/catalogs/${lane}.v1.json`;
    const provenancePath = `tool/release-evidence/provenance/${lane}.v1.json`;
    const catalogFile = parseJsonFile(join(root, catalogPath), `${lane} catalog`);
    const provenanceFile = parseJsonFile(
      join(root, provenancePath),
      `${lane} provenance`,
    );
    validateCatalog(catalogFile.value, lane);
    const catalogSha256 = rawSha256(catalogFile.bytes);
    validateProvenance(
      provenanceFile.value,
      lane,
      catalogPath,
      catalogSha256,
    );
    result[lane] = {
      catalog_path: catalogPath,
      catalog_sha256: catalogSha256,
      case_count: definition.cases.length,
      case_ids: definition.cases.map((entry) => entry.id),
      provenance_path: provenancePath,
      provenance_sha256: rawSha256(provenanceFile.bytes),
    };
  }
  return result;
}

const candidateTopKeys = [
  '$schema',
  'schema_version',
  'document_type',
  'release_id',
  'created_at',
  'gitops',
  'services',
  'shared_migration',
  'frontend',
  'home',
  'analytics_privacy',
  'ai_release_eval_config',
  'environments',
  'journey_harness',
  'quality_evidence_inputs',
  'rollout',
];

const manualBindingKeys = [
  'repository',
  'source_sha',
  'path',
  'sha256',
  'case_count',
  'provenance_sha256',
];

const signedBindingKeys = [
  'schema_version',
  'repository',
  'source_sha',
  'event',
  'workflow_path',
  'workflow_sha256',
  'workflow_run_id',
  'run_attempt',
  'artifact_id',
  'artifact_name',
  'artifact_archive_sha256',
  'build_provenance_file',
  'build_provenance_sha256',
  'signed_apk_file',
  'signed_apk_sha256',
];

function validateCandidate(candidate, {
  catalogs,
  releaseId,
  sourceSha,
}) {
  exactKeys(candidate, candidateTopKeys, 'canonical candidate');
  if (!releaseIdPattern.test(releaseId)) fail('release_id is not a safe identifier');
  exact(candidate.release_id, releaseId, 'candidate.release_id');
  const frontend = object(candidate.frontend, 'candidate.frontend');
  exact(frontend.repository, frontendRepository, 'candidate.frontend.repository');
  exact(sha1(frontend.source_sha, 'candidate.frontend.source_sha'), sourceSha, 'candidate.frontend.source_sha');
  const quality = object(candidate.quality_evidence_inputs, 'candidate.quality_evidence_inputs');
  const bindings = object(quality.catalogs, 'candidate catalog bindings');
  exactKeys(bindings, candidateCatalogKeys, 'candidate catalog bindings');
  for (const [lane, local] of Object.entries(catalogs)) {
    const binding = object(bindings[lane], `${lane} candidate binding`);
    exactKeys(binding, manualBindingKeys, `${lane} candidate binding`);
    exact(binding.repository, frontendRepository, `${lane}.repository`);
    exact(binding.source_sha, sourceSha, `${lane}.source_sha`);
    exact(binding.path, local.catalog_path, `${lane}.path`);
    exact(sha256(binding.sha256, `${lane}.sha256`), local.catalog_sha256, `${lane}.sha256`);
    exact(binding.case_count, local.case_count, `${lane}.case_count`);
    exact(
      sha256(binding.provenance_sha256, `${lane}.provenance_sha256`),
      local.provenance_sha256,
      `${lane}.provenance_sha256`,
    );
  }
  const mobile = object(quality.mobile_test_artifacts, 'mobile_test_artifacts');
  exactKeys(mobile, signedBindingKeys, 'mobile_test_artifacts');
  exact(mobile.schema_version, signedBindingSchema, 'mobile_test_artifacts.schema_version');
  exact(mobile.repository, frontendRepository, 'mobile_test_artifacts.repository');
  exact(mobile.source_sha, sourceSha, 'mobile_test_artifacts.source_sha');
  exact(mobile.event, 'workflow_dispatch', 'mobile_test_artifacts.event');
  exact(mobile.workflow_path, signedMobileWorkflow, 'mobile_test_artifacts.workflow_path');
  sha256(mobile.workflow_sha256, 'mobile_test_artifacts.workflow_sha256');
  positiveInteger(mobile.workflow_run_id, 'mobile_test_artifacts.workflow_run_id');
  exact(mobile.run_attempt, 1, 'mobile_test_artifacts.run_attempt');
  positiveInteger(mobile.artifact_id, 'mobile_test_artifacts.artifact_id');
  exact(
    mobile.artifact_name,
    `${releaseId}-signed-android-build-run-${mobile.workflow_run_id}-attempt-1`,
    'mobile_test_artifacts.artifact_name',
  );
  sha256(mobile.artifact_archive_sha256, 'mobile_test_artifacts.artifact_archive_sha256');
  exact(mobile.build_provenance_file, 'build-provenance.v2.json', 'mobile_test_artifacts.build_provenance_file');
  exact(mobile.signed_apk_file, 'mobile/android/leva-release.apk', 'mobile_test_artifacts.signed_apk_file');
  const distinct = [
    sha256(mobile.build_provenance_sha256, 'mobile_test_artifacts.build_provenance_sha256'),
    sha256(mobile.signed_apk_sha256, 'mobile_test_artifacts.signed_apk_sha256'),
  ];
  if (new Set(distinct).size !== distinct.length) {
    fail('mobile_test_artifacts hashes must be distinct');
  }
  return mobile;
}

function validateApproval(value, lane) {
  const definition = laneDefinitions[lane];
  exactKeys(
    value,
    [
      'approval_environment',
      'approval_environment_id',
      'approval_job_name',
      'approved_by',
      'approved_by_id',
      'approval_effective_at',
      'workflow_sha256',
    ],
    `${lane} approval`,
  );
  exact(value.approval_environment, definition.environment, `${lane}.approval_environment`);
  exact(value.approval_job_name, definition.jobName, `${lane}.approval_job_name`);
  positiveInteger(value.approval_environment_id, `${lane}.approval_environment_id`);
  if (
    typeof value.approved_by !== 'string' ||
    !/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$/.test(value.approved_by)
  ) {
    fail(`${lane}.approved_by is not one sanitized GitHub user login`);
  }
  positiveInteger(value.approved_by_id, `${lane}.approved_by_id`);
  utc(value.approval_effective_at, `${lane}.approval_effective_at`);
  sha256(value.workflow_sha256, `${lane}.workflow_sha256`);
  return value;
}

const commonEvidenceKeys = [
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

function evidenceKeys(lane) {
  if (lane === 'manual-nvda') return commonEvidenceKeys;
  return [
    ...commonEvidenceKeys.slice(0, 12),
    'build_provenance_sha256',
    'signed_apk_sha256',
    ...commonEvidenceKeys.slice(12),
  ];
}

export function createManualEvidence({
  lane,
  candidate,
  candidateSpecSha256,
  releaseId,
  sourceSha,
  producerRunId,
  producerRunAttempt,
  approval,
  repositoryRoot,
}) {
  const definition = laneDefinitions[lane];
  if (!definition) fail('unknown manual lane');
  sha1(sourceSha, 'sourceSha');
  sha256(candidateSpecSha256, 'candidateSpecSha256');
  positiveInteger(producerRunId, 'producerRunId');
  if (producerRunAttempt !== 1) {
    fail('protected approvals require attempt 1 and a fresh workflow_dispatch');
  }
  const catalogs = validateAllManualCatalogs(repositoryRoot);
  const mobile = validateCandidate(candidate, { catalogs, releaseId, sourceSha });
  const checkedApproval = validateApproval(approval, lane);
  const local = catalogs[lane];
  const evidence = {
    candidate_spec_sha256: candidateSpecSha256,
    status: 'passed',
    producer_run_id: producerRunId,
    producer_run_attempt: producerRunAttempt,
    repository: frontendRepository,
    source_sha: sourceSha,
    case_catalog_sha256: local.catalog_sha256,
    case_count: local.case_count,
    passed_case_count: local.case_count,
    failed_case_count: 0,
    assistive_technology: definition.assistiveTechnology,
    test_provenance_sha256: local.provenance_sha256,
  };
  if (lane !== 'manual-nvda') {
    evidence.build_provenance_sha256 = mobile.build_provenance_sha256;
    evidence.signed_apk_sha256 = mobile.signed_apk_sha256;
  }
  Object.assign(evidence, {
    approval_environment: checkedApproval.approval_environment,
    approval_environment_id: checkedApproval.approval_environment_id,
    approval_job_name: checkedApproval.approval_job_name,
    approved_by: checkedApproval.approved_by,
    approved_by_id: checkedApproval.approved_by_id,
    approval_effective_at: checkedApproval.approval_effective_at,
  });
  validateEvidence(evidence, lane, {
    candidateSpecSha256,
    sourceSha,
    producerRunId,
    producerRunAttempt,
    catalogs,
    mobile,
  });
  return evidence;
}

function validateEvidence(value, lane, expected) {
  const definition = laneDefinitions[lane];
  const local = expected.catalogs[lane];
  exactKeys(value, evidenceKeys(lane), `${lane} evidence`);
  exact(value.candidate_spec_sha256, expected.candidateSpecSha256, `${lane}.candidate_spec_sha256`);
  exact(value.status, 'passed', `${lane}.status`);
  exact(value.producer_run_id, expected.producerRunId, `${lane}.producer_run_id`);
  exact(value.producer_run_attempt, 1, `${lane}.producer_run_attempt`);
  exact(value.repository, frontendRepository, `${lane}.repository`);
  exact(value.source_sha, expected.sourceSha, `${lane}.source_sha`);
  exact(value.case_catalog_sha256, local.catalog_sha256, `${lane}.case_catalog_sha256`);
  exact(value.case_count, local.case_count, `${lane}.case_count`);
  exact(value.passed_case_count, local.case_count, `${lane}.passed_case_count`);
  exact(value.failed_case_count, 0, `${lane}.failed_case_count`);
  exact(value.assistive_technology, definition.assistiveTechnology, `${lane}.assistive_technology`);
  exact(value.test_provenance_sha256, local.provenance_sha256, `${lane}.test_provenance_sha256`);
  validateApproval(
    {
      approval_environment: value.approval_environment,
      approval_environment_id: value.approval_environment_id,
      approval_job_name: value.approval_job_name,
      approved_by: value.approved_by,
      approved_by_id: value.approved_by_id,
      approval_effective_at: value.approval_effective_at,
      workflow_sha256: '1'.repeat(64),
    },
    lane,
  );
  if (lane !== 'manual-nvda') {
    exact(value.build_provenance_sha256, expected.mobile.build_provenance_sha256, `${lane}.build_provenance_sha256`);
    exact(value.signed_apk_sha256, expected.mobile.signed_apk_sha256, `${lane}.signed_apk_sha256`);
  }
}

function exactPackageDirectory(root, lane) {
  const laneRoot = join(root, lane);
  regularDirectory(laneRoot, `${lane} package root`);
  exact(realpathSync(laneRoot), resolve(laneRoot), `${lane} package root`);
  const entries = readdirSync(laneRoot, { withFileTypes: true });
  if (entries.length !== 1 || entries[0].name !== 'evidence.json') {
    fail(`${lane} package must contain exactly evidence.json`);
  }
  const evidencePath = join(laneRoot, 'evidence.json');
  regularFile(evidencePath, `${lane} evidence`);
  return evidencePath;
}

export function validateManualEvidencePackages({
  packageRoot,
  candidate,
  candidateSpecSha256,
  releaseId,
  sourceSha,
  producerRunId,
  producerRunAttempt,
  repositoryRoot,
}) {
  regularDirectory(packageRoot, 'manual package root');
  if (producerRunAttempt !== 1) fail('protected approvals require attempt 1');
  const rootEntries = readdirSync(packageRoot, { withFileTypes: true });
  const lanes = Object.keys(laneDefinitions);
  if (
    rootEntries.length !== lanes.length ||
    rootEntries.some((entry) => !entry.isDirectory() || !lanes.includes(entry.name))
  ) {
    fail('manual package root must contain exactly the two lane directories');
  }
  const catalogs = validateAllManualCatalogs(repositoryRoot);
  const mobile = validateCandidate(candidate, { catalogs, releaseId, sourceSha });
  for (const lane of lanes) {
    const evidenceFile = parseJsonFile(
      exactPackageDirectory(packageRoot, lane),
      `${lane} evidence`,
    );
    validateEvidence(evidenceFile.value, lane, {
      candidateSpecSha256,
      sourceSha,
      producerRunId,
      producerRunAttempt,
      catalogs,
      mobile,
    });
  }
  return true;
}

export function validateManualInputs({
  repositoryRoot,
  candidate,
  candidateSpecSha256,
  releaseId,
  sourceSha,
  signedBundleRoot,
}) {
  const catalogs = validateAllManualCatalogs(repositoryRoot);
  const mobile = validateCandidate(candidate, { catalogs, releaseId, sourceSha });
  const candidateBytesSha = sha256(candidateSpecSha256, 'candidateSpecSha256');
  const signed = validateExactSignedMobileBundle(signedBundleRoot, {
    releaseId,
    sourceSha,
    workflowSha256: mobile.workflow_sha256,
    producerRunId: mobile.workflow_run_id,
    producerRunAttempt: mobile.run_attempt,
    pubspecLockSha256: rawSha256(readFileSync(join(repositoryRoot, 'pubspec.lock'))),
  });
  exact(signed.buildProvenanceSha256, mobile.build_provenance_sha256, 'signed build provenance SHA');
  exact(signed.signedApkSha256, mobile.signed_apk_sha256, 'signed APK SHA');
  return { catalogs, mobile, candidateSpecSha256: candidateBytesSha };
}

function validateRunPath(path, expected) {
  const allowed = new Set([
    expected,
    `${expected}@main`,
    `${expected}@refs/heads/main`,
  ]);
  if (!allowed.has(path)) fail('signed producer run workflow path/ref mismatch');
}

export function validateSignedMobileArtifactFacts({
  binding,
  releaseId,
  sourceSha,
  run,
  branch,
  artifact,
  workflowBytes,
  localWorkflowBytes,
}) {
  exact(binding.run_attempt, 1, 'signed producer run_attempt');
  exact(run.id, binding.workflow_run_id, 'signed producer run.id');
  exact(run.run_attempt, 1, 'signed producer run.run_attempt');
  exact(run.event, 'workflow_dispatch', 'signed producer run.event');
  exact(run.status, 'completed', 'signed producer run.status');
  exact(run.conclusion, 'success', 'signed producer run.conclusion');
  exact(run.head_sha, sourceSha, 'signed producer run.head_sha');
  exact(run.head_branch, 'main', 'signed producer run.head_branch');
  exact(run.repository?.full_name, frontendRepository, 'signed producer run.repository');
  exact(run.head_repository?.full_name, frontendRepository, 'signed producer run.head_repository');
  validateRunPath(run.path, signedMobileWorkflow);
  exact(branch.name, 'main', 'signed producer protected branch name');
  exact(branch.commit?.sha, sourceSha, 'signed producer protected branch SHA');
  exact(branch.protected, true, 'signed producer protected branch policy');
  exact(artifact.id, binding.artifact_id, 'signed artifact.id');
  exact(
    artifact.name,
    `${releaseId}-signed-android-build-run-${binding.workflow_run_id}-attempt-1`,
    'signed artifact.name',
  );
  exact(artifact.expired, false, 'signed artifact.expired');
  positiveInteger(artifact.size_in_bytes, 'signed artifact.size_in_bytes');
  if (artifact.size_in_bytes > 550 * 1024 * 1024) {
    fail('signed artifact exceeds the 550 MiB archive limit');
  }
  exact(artifact.workflow_run?.id, binding.workflow_run_id, 'signed artifact.workflow_run.id');
  exact(artifact.workflow_run?.head_sha, sourceSha, 'signed artifact.workflow_run.head_sha');
  const digest = artifact.digest;
  if (typeof digest !== 'string' || !/^sha256:[0-9a-f]{64}$/.test(digest)) {
    fail('signed artifact API digest is absent or malformed');
  }
  exact(digest.slice(7), binding.artifact_archive_sha256, 'signed artifact archive SHA-256');
  if (!Buffer.isBuffer(workflowBytes) || workflowBytes.length < 1) {
    fail('signed producer workflow bytes are absent');
  }
  if (!Buffer.isBuffer(localWorkflowBytes) || !workflowBytes.equals(localWorkflowBytes)) {
    fail('signed producer workflow differs from exact checked source bytes');
  }
  exact(rawSha256(workflowBytes), binding.workflow_sha256, 'signed producer workflow SHA-256');
  return binding;
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
  if (!response.ok) fail(`GitHub API ${path} returned HTTP ${response.status}`);
  return response.json();
}

async function authenticateSignedArtifact(common, outputPath) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) fail('GITHUB_TOKEN is absent');
  const catalogs = validateAllManualCatalogs(common.repositoryRoot);
  const binding = validateCandidate(common.candidate, {
    catalogs,
    releaseId: common.releaseId,
    sourceSha: common.sourceSha,
  });
  const repository = frontendRepository;
  const run = await github(
    `/repos/${repository}/actions/runs/${binding.workflow_run_id}/attempts/1`,
    token,
  );
  const branch = await github(`/repos/${repository}/branches/main`, token);
  const artifact = await github(
    `/repos/${repository}/actions/artifacts/${binding.artifact_id}`,
    token,
  );
  const encodedWorkflow = signedMobileWorkflow
    .split('/')
    .map((part) => encodeURIComponent(part))
    .join('/');
  const workflow = await github(
    `/repos/${repository}/contents/${encodedWorkflow}?ref=${common.sourceSha}`,
    token,
  );
  exact(workflow.type, 'file', 'signed producer workflow.type');
  exact(workflow.path, signedMobileWorkflow, 'signed producer workflow.path');
  exact(workflow.encoding, 'base64', 'signed producer workflow.encoding');
  const workflowBytes = Buffer.from(
    (workflow.content ?? '').replace(/\s/g, ''),
    'base64',
  );
  const localWorkflowBytes = readFileSync(
    join(common.repositoryRoot, signedMobileWorkflow),
  );
  validateSignedMobileArtifactFacts({
    binding,
    releaseId: common.releaseId,
    sourceSha: common.sourceSha,
    run,
    branch,
    artifact,
    workflowBytes,
    localWorkflowBytes,
  });
  const result = {
    signed_run_id: binding.workflow_run_id,
    signed_run_attempt: binding.run_attempt,
    signed_artifact_id: binding.artifact_id,
    signed_artifact_name: binding.artifact_name,
    signed_artifact_archive_sha256: binding.artifact_archive_sha256,
    signed_workflow_sha256: binding.workflow_sha256,
  };
  if (outputPath) {
    writeFileSync(outputPath, `${JSON.stringify(result, null, 2)}\n`, {
      encoding: 'utf8',
      flag: 'wx',
    });
  }
  if (process.env.GITHUB_OUTPUT) {
    const { appendFileSync } = await import('node:fs');
    appendFileSync(
      process.env.GITHUB_OUTPUT,
      Object.entries(result)
        .map(([key, value]) => `${key}=${value}\n`)
        .join(''),
      'utf8',
    );
  }
  return result;
}

function parseOptions(argv) {
  const values = new Map();
  for (const argument of argv) {
    if (!argument.startsWith('--') || !argument.includes('=')) fail(`invalid option ${argument}`);
    const split = argument.indexOf('=');
    const key = argument.slice(2, split);
    if (values.has(key)) fail(`duplicate --${key}`);
    values.set(key, argument.slice(split + 1));
  }
  return values;
}

function required(options, key) {
  const value = options.get(key);
  if (!value) fail(`missing --${key}`);
  return value;
}

function integerOption(options, key) {
  const raw = required(options, key);
  if (!/^[1-9][0-9]*$/.test(raw)) fail(`${key} must be a positive integer`);
  return positiveInteger(Number(raw), key);
}

function loadJson(path, name) {
  return parseJsonFile(path, name).value;
}

async function cli() {
  const [command, ...args] = process.argv.slice(2);
  const options = parseOptions(args);
  const root = resolve(options.get('repository-root') ?? '.');
  const candidatePath = required(options, 'candidate');
  const candidateFile = parseJsonFile(candidatePath, 'canonical candidate');
  const claimedCandidateSha = sha256(required(options, 'candidate-sha256'), 'candidate-sha256');
  exact(rawSha256(candidateFile.bytes), claimedCandidateSha, 'candidate raw SHA-256');
  const common = {
    candidate: candidateFile.value,
    candidateSpecSha256: claimedCandidateSha,
    releaseId: required(options, 'release-id'),
    sourceSha: required(options, 'source-sha'),
    repositoryRoot: root,
  };
  if (command === 'authenticate-signed-artifact') {
    await authenticateSignedArtifact(common, options.get('output'));
    process.stdout.write('Signed mobile artifact metadata authenticated\n');
    return;
  }
  if (command === 'validate-manual-inputs') {
    validateManualInputs({
      ...common,
      signedBundleRoot: required(options, 'signed-root'),
    });
    process.stdout.write('Manual AT source and signed inputs valid\n');
    return;
  }
  if (command === 'manual-evidence') {
    const document = createManualEvidence({
      ...common,
      lane: required(options, 'lane'),
      producerRunId: integerOption(options, 'producer-run-id'),
      producerRunAttempt: integerOption(options, 'producer-run-attempt'),
      approval: loadJson(required(options, 'approval'), 'protected approval'),
    });
    const output = required(options, 'output');
    regularDirectory(dirname(output), 'evidence output parent');
    writeFileSync(output, `${JSON.stringify(document, null, 2)}\n`, {
      encoding: 'utf8',
      flag: 'wx',
    });
    process.stdout.write('Manual AT sanitized evidence created\n');
    return;
  }
  if (command === 'validate-manual-packages') {
    validateManualEvidencePackages({
      ...common,
      packageRoot: required(options, 'package-root'),
      producerRunId: integerOption(options, 'producer-run-id'),
      producerRunAttempt: integerOption(options, 'producer-run-attempt'),
    });
    process.stdout.write('Manual AT sanitized packages valid\n');
    return;
  }
  fail('command must be authenticate-signed-artifact, validate-manual-inputs, manual-evidence, or validate-manual-packages');
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    cli().catch((error) => {
      console.error(error.message);
      process.exitCode = 1;
    });
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
