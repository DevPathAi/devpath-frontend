import { createHash } from 'node:crypto';
import {
  lstatSync,
  readFileSync,
  readdirSync,
  realpathSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { pathToFileURL } from 'node:url';
import process from 'node:process';

export const frontendRepository = 'DevPathAi/devpath-frontend';
export const signedMobileWorkflow =
  '.github/workflows/mission-spine-signed-mobile-build.yml';
export const signedMobileSchemaVersion =
  'leva.mission-spine.signed-mobile-build.v1';

const sha1Pattern = /^(?!0{40}$)[0-9a-f]{40}$/;
const sha256Pattern = /^(?!0{64}$)[0-9a-f]{64}$/;
const releaseIdPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const utcPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/;
const uuidPattern = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/;

const toolchain = Object.freeze({
  flutter_version: '3.44.1',
  flutter_revision: '924134a44c189315be2148659913dda1671cbe99',
  dart_sdk_version: '3.12.1',
  android: Object.freeze({
    java_runtime:
      'OpenJDK Runtime Environment Temurin-17.0.20+8 (build 17.0.20+8)',
    compile_sdk: 36,
  }),
  ios: Object.freeze({
    xcode_version: '26.4.1',
    xcode_build: '17E202',
    iphoneos_sdk: '26.4',
  }),
});

const buildConfiguration = Object.freeze({
  use_mock: false,
  api_base_url: 'https://api.leva.ai.kr',
  web_app_url: 'https://app.leva.ai.kr',
});

function fail(message) {
  throw new Error(`Mission Spine release evidence failed: ${message}`);
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
    actual.some((key) => !expected.includes(key))
  ) {
    fail(`${name} key set mismatch`);
  }
}

function nonemptyString(value, name) {
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
  if (
    typeof value !== 'number' ||
    !Number.isSafeInteger(value) ||
    value < 1
  ) {
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

function fileEvidence(path, name) {
  const info = regularFile(path, name);
  return { sha256: rawSha256(readFileSync(path)), bytes: info.size };
}

function validateApproval(value, platform) {
  const name = `approvals.${platform}`;
  exactKeys(
    value,
    [
      'approval_environment',
      'approval_environment_id',
      'approval_job_name',
      'approved_by',
      'approved_by_id',
      'approval_effective_at',
    ],
    name,
  );
  exact(
    value.approval_environment,
    `mission-spine-mobile-signing-${platform}`,
    `${name}.approval_environment`,
  );
  exact(
    value.approval_job_name,
    platform === 'android' ? 'Sign Android release' : 'Sign iOS release',
    `${name}.approval_job_name`,
  );
  positiveInteger(value.approval_environment_id, `${name}.approval_environment_id`);
  nonemptyString(value.approved_by, `${name}.approved_by`);
  positiveInteger(value.approved_by_id, `${name}.approved_by_id`);
  utc(value.approval_effective_at, `${name}.approval_effective_at`);
  return value;
}

function validateToolchain(value) {
  exactKeys(
    value,
    ['flutter_version', 'flutter_revision', 'dart_sdk_version', 'android', 'ios'],
    'toolchain',
  );
  exact(value.flutter_version, toolchain.flutter_version, 'toolchain.flutter_version');
  exact(value.flutter_revision, toolchain.flutter_revision, 'toolchain.flutter_revision');
  exact(value.dart_sdk_version, toolchain.dart_sdk_version, 'toolchain.dart_sdk_version');
  exactKeys(value.android, ['java_runtime', 'compile_sdk'], 'toolchain.android');
  exact(value.android.java_runtime, toolchain.android.java_runtime, 'toolchain.android.java_runtime');
  exact(value.android.compile_sdk, toolchain.android.compile_sdk, 'toolchain.android.compile_sdk');
  exactKeys(
    value.ios,
    ['xcode_version', 'xcode_build', 'iphoneos_sdk'],
    'toolchain.ios',
  );
  exact(value.ios.xcode_version, toolchain.ios.xcode_version, 'toolchain.ios.xcode_version');
  exact(value.ios.xcode_build, toolchain.ios.xcode_build, 'toolchain.ios.xcode_build');
  exact(value.ios.iphoneos_sdk, toolchain.ios.iphoneos_sdk, 'toolchain.ios.iphoneos_sdk');
}

function validateBuildConfiguration(value) {
  exactKeys(value, ['use_mock', 'api_base_url', 'web_app_url'], 'build_configuration');
  exact(value.use_mock, false, 'build_configuration.use_mock');
  exact(value.api_base_url, buildConfiguration.api_base_url, 'build_configuration.api_base_url');
  exact(value.web_app_url, buildConfiguration.web_app_url, 'build_configuration.web_app_url');
}

function validateAndroid(value, apkPath) {
  exactKeys(
    value,
    [
      'artifact_path',
      'sha256',
      'bytes',
      'application_id',
      'version_name',
      'version_code',
      'signature_verified',
      'signing_classification',
      'play_app_signing',
      'signing_certificate_sha256',
    ],
    'android',
  );
  exact(value.artifact_path, 'mobile/android/leva-release.apk', 'android.artifact_path');
  sha256(value.sha256, 'android.sha256');
  positiveInteger(value.bytes, 'android.bytes');
  exact(value.application_id, 'ai.devpath.devpath_mobile', 'android.application_id');
  nonemptyString(value.version_name, 'android.version_name');
  positiveInteger(value.version_code, 'android.version_code');
  exact(value.signature_verified, true, 'android.signature_verified');
  exact(
    value.signing_classification,
    'org_keystore_release_test_distribution',
    'android.signing_classification',
  );
  exact(value.play_app_signing, false, 'android.play_app_signing');
  sha256(value.signing_certificate_sha256, 'android.signing_certificate_sha256');
  const actual = fileEvidence(apkPath, 'signed Android APK');
  exact(value.sha256, actual.sha256, 'android.sha256');
  exact(value.bytes, actual.bytes, 'android.bytes');
}

function validateIos(value, ipaPath, approval) {
  exactKeys(
    value,
    [
      'artifact_path',
      'sha256',
      'bytes',
      'bundle_id',
      'short_version',
      'bundle_version',
      'signature_verified',
      'signing_classification',
      'export_method',
      'distribution_scope',
      'team_id',
      'signing_certificate_sha256',
      'provisioning_profile_uuid',
      'provisioning_profile_expires_at',
    ],
    'ios',
  );
  exact(value.artifact_path, 'mobile/ios/leva-release.ipa', 'ios.artifact_path');
  sha256(value.sha256, 'ios.sha256');
  positiveInteger(value.bytes, 'ios.bytes');
  exact(value.bundle_id, 'ai.devpath.devpathMobile', 'ios.bundle_id');
  nonemptyString(value.short_version, 'ios.short_version');
  nonemptyString(value.bundle_version, 'ios.bundle_version');
  exact(value.signature_verified, true, 'ios.signature_verified');
  exact(
    value.signing_classification,
    'organization_distribution',
    'ios.signing_classification',
  );
  exact(value.export_method, 'ad-hoc', 'ios.export_method');
  exact(
    value.distribution_scope,
    'protected_manual_at_test_devices',
    'ios.distribution_scope',
  );
  if (typeof value.team_id !== 'string' || !/^[A-Z0-9]{10}$/.test(value.team_id)) {
    fail('ios.team_id must be a 10-character Apple team identifier');
  }
  sha256(value.signing_certificate_sha256, 'ios.signing_certificate_sha256');
  if (
    typeof value.provisioning_profile_uuid !== 'string' ||
    !uuidPattern.test(value.provisioning_profile_uuid)
  ) {
    fail('ios.provisioning_profile_uuid must be an uppercase UUID');
  }
  const expiresAt = utc(
    value.provisioning_profile_expires_at,
    'ios.provisioning_profile_expires_at',
  );
  if (Date.parse(expiresAt) <= Date.parse(approval.approval_effective_at)) {
    fail('iOS provisioning profile must outlive approval_effective_at');
  }
  const actual = fileEvidence(ipaPath, 'signed iOS IPA');
  exact(value.sha256, actual.sha256, 'ios.sha256');
  exact(value.bytes, actual.bytes, 'ios.bytes');
}

export function createSignedMobileBuildProvenance({
  releaseId,
  repository = frontendRepository,
  sourceSha,
  workflowSha256,
  producerRunId,
  producerRunAttempt,
  pubspecLockSha256,
  apkPath,
  ipaPath,
  android,
  ios,
}) {
  const apk = fileEvidence(apkPath, 'signed Android APK');
  const ipa = fileEvidence(ipaPath, 'signed iOS IPA');
  const document = {
    schema_version: signedMobileSchemaVersion,
    release_id: releaseId,
    repository,
    source_sha: sourceSha,
    event: 'workflow_dispatch',
    workflow_path: signedMobileWorkflow,
    workflow_sha256: workflowSha256,
    producer_run_id: producerRunId,
    producer_run_attempt: producerRunAttempt,
    pubspec_lock_sha256: pubspecLockSha256,
    toolchain: structuredClone(toolchain),
    build_configuration: structuredClone(buildConfiguration),
    android: {
      artifact_path: 'mobile/android/leva-release.apk',
      sha256: apk.sha256,
      bytes: apk.bytes,
      application_id: android.applicationId,
      version_name: android.versionName,
      version_code: android.versionCode,
      signature_verified: android.signatureVerified,
      signing_classification: 'org_keystore_release_test_distribution',
      play_app_signing: false,
      signing_certificate_sha256: android.signingCertificateSha256,
    },
    ios: {
      artifact_path: 'mobile/ios/leva-release.ipa',
      sha256: ipa.sha256,
      bytes: ipa.bytes,
      bundle_id: ios.bundleId,
      short_version: ios.shortVersion,
      bundle_version: ios.bundleVersion,
      signature_verified: ios.signatureVerified,
      signing_classification: 'organization_distribution',
      export_method: 'ad-hoc',
      distribution_scope: 'protected_manual_at_test_devices',
      team_id: ios.teamId,
      signing_certificate_sha256: ios.signingCertificateSha256,
      provisioning_profile_uuid: ios.provisioningProfileUuid,
      provisioning_profile_expires_at: ios.provisioningProfileExpiresAt,
    },
    approvals: {
      android: android.approval,
      ios: ios.approval,
    },
  };
  validateSignedMobileBuildProvenance(document, {
    releaseId,
    sourceSha,
    workflowSha256,
    producerRunId,
    producerRunAttempt,
    pubspecLockSha256,
    apkPath,
    ipaPath,
  });
  return document;
}

export function validateSignedMobileBuildProvenance(
  value,
  {
    releaseId,
    sourceSha,
    workflowSha256,
    producerRunId,
    producerRunAttempt,
    pubspecLockSha256,
    apkPath,
    ipaPath,
  },
) {
  exactKeys(
    value,
    [
      'schema_version',
      'release_id',
      'repository',
      'source_sha',
      'event',
      'workflow_path',
      'workflow_sha256',
      'producer_run_id',
      'producer_run_attempt',
      'pubspec_lock_sha256',
      'toolchain',
      'build_configuration',
      'android',
      'ios',
      'approvals',
    ],
    'build provenance',
  );
  if (typeof value.release_id !== 'string' || !releaseIdPattern.test(value.release_id)) {
    fail('release_id is not a safe immutable identifier');
  }
  exact(value.schema_version, signedMobileSchemaVersion, 'schema_version');
  exact(value.release_id, releaseId, 'release_id');
  exact(value.repository, frontendRepository, 'repository');
  exact(sha1(value.source_sha, 'source_sha'), sourceSha, 'source_sha');
  exact(value.event, 'workflow_dispatch', 'event');
  exact(value.workflow_path, signedMobileWorkflow, 'workflow_path');
  exact(sha256(value.workflow_sha256, 'workflow_sha256'), workflowSha256, 'workflow_sha256');
  exact(positiveInteger(value.producer_run_id, 'producer_run_id'), producerRunId, 'producer_run_id');
  exact(
    positiveInteger(value.producer_run_attempt, 'producer_run_attempt'),
    producerRunAttempt,
    'producer_run_attempt',
  );
  exact(
    sha256(value.pubspec_lock_sha256, 'pubspec_lock_sha256'),
    pubspecLockSha256,
    'pubspec_lock_sha256',
  );
  validateToolchain(value.toolchain);
  validateBuildConfiguration(value.build_configuration);
  exactKeys(value.approvals, ['android', 'ios'], 'approvals');
  const androidApproval = validateApproval(value.approvals.android, 'android');
  const iosApproval = validateApproval(value.approvals.ios, 'ios');
  validateAndroid(value.android, apkPath);
  validateIos(value.ios, ipaPath, iosApproval);
  if (androidApproval.approved_by_id === iosApproval.approved_by_id) {
    // The approved policy allows the exact configured reviewer to approve both lanes.
  }
  return value;
}

function walk(root, directory = root) {
  const entities = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    const relativePath = relative(root, path).split(sep).join('/');
    const info = lstatSync(path);
    if (info.isSymbolicLink()) fail(`bundle link is forbidden: ${relativePath}`);
    if (info.isDirectory()) {
      entities.push(`${relativePath}/`);
      entities.push(...walk(root, path));
    } else if (info.isFile()) {
      entities.push(relativePath);
    } else {
      fail(`bundle special file is forbidden: ${relativePath}`);
    }
  }
  return entities;
}

export function validateExactSignedMobileBundle(root, expectations) {
  const resolvedRoot = resolve(root);
  const rootInfo = lstatSync(resolvedRoot);
  if (!rootInfo.isDirectory() || rootInfo.isSymbolicLink()) {
    fail('signed mobile bundle root must be one regular directory');
  }
  exact(realpathSync(resolvedRoot), resolvedRoot, 'signed mobile bundle root');
  const expected = [
    'build-provenance.v1.json',
    'mobile/',
    'mobile/android/',
    'mobile/android/leva-release.apk',
    'mobile/ios/',
    'mobile/ios/leva-release.ipa',
  ];
  const actual = walk(resolvedRoot).sort();
  if (
    actual.length !== expected.length ||
    actual.some((entry, index) => entry !== [...expected].sort()[index])
  ) {
    fail('signed mobile bundle must contain exactly three regular files and canonical directories');
  }
  const provenancePath = join(resolvedRoot, 'build-provenance.v1.json');
  const provenanceInfo = regularFile(provenancePath, 'build provenance');
  if (provenanceInfo.size > 256 * 1024) fail('build provenance exceeds 256 KiB');
  const bytes = readFileSync(provenancePath);
  if (bytes.length >= 3 && bytes.subarray(0, 3).equals(Buffer.from([0xef, 0xbb, 0xbf]))) {
    fail('build provenance must be UTF-8 without BOM');
  }
  let provenance;
  try {
    provenance = JSON.parse(bytes.toString('utf8'));
  } catch (error) {
    fail(`build provenance is not valid UTF-8 JSON: ${error.message}`);
  }
  validateSignedMobileBuildProvenance(provenance, {
    ...expectations,
    apkPath: join(resolvedRoot, 'mobile', 'android', 'leva-release.apk'),
    ipaPath: join(resolvedRoot, 'mobile', 'ios', 'leva-release.ipa'),
  });
  return {
    provenance,
    buildProvenanceSha256: rawSha256(bytes),
    signedApkSha256: provenance.android.sha256,
    signedIpaSha256: provenance.ios.sha256,
  };
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

function integerOption(options, key) {
  const value = required(options, key);
  if (!/^[1-9][0-9]*$/.test(value)) fail(`${key} must be a positive integer`);
  return positiveInteger(Number(value), key);
}

function loadJson(path, name) {
  regularFile(path, name);
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    fail(`${name} is not valid JSON: ${error.message}`);
  }
}

function platformInput(value, platform, workflowSha256) {
  const approvalValue = value.approval;
  validateApproval(approvalValue, platform);
  exact(
    sha256(value.workflow_sha256, `${platform} metadata.workflow_sha256`),
    workflowSha256,
    `${platform} metadata.workflow_sha256`,
  );
  if (platform === 'android') {
    exactKeys(
      value,
      [
        'workflow_sha256',
        'application_id',
        'version_name',
        'version_code',
        'signature_verified',
        'signing_certificate_sha256',
        'approval',
      ],
      'Android metadata',
    );
    return {
      applicationId: value.application_id,
      versionName: value.version_name,
      versionCode: value.version_code,
      signatureVerified: value.signature_verified,
      signingCertificateSha256: value.signing_certificate_sha256,
      approval: approvalValue,
    };
  }
  exactKeys(
    value,
    [
      'workflow_sha256',
      'bundle_id',
      'short_version',
      'bundle_version',
      'signature_verified',
      'signing_classification',
      'export_method',
      'distribution_scope',
      'team_id',
      'signing_certificate_sha256',
      'provisioning_profile_uuid',
      'provisioning_profile_expires_at',
      'approval',
    ],
    'iOS metadata',
  );
  exact(
    value.signing_classification,
    'organization_distribution',
    'iOS metadata.signing_classification',
  );
  exact(value.export_method, 'ad-hoc', 'iOS metadata.export_method');
  exact(
    value.distribution_scope,
    'protected_manual_at_test_devices',
    'iOS metadata.distribution_scope',
  );
  return {
    bundleId: value.bundle_id,
    shortVersion: value.short_version,
    bundleVersion: value.bundle_version,
    signatureVerified: value.signature_verified,
    teamId: value.team_id,
    signingCertificateSha256: value.signing_certificate_sha256,
    provisioningProfileUuid: value.provisioning_profile_uuid,
    provisioningProfileExpiresAt: value.provisioning_profile_expires_at,
    approval: approvalValue,
  };
}

function main() {
  const [command, ...args] = process.argv.slice(2);
  const options = parseOptions(args);
  if (command === 'signed-provenance') {
    const workflowSha256 = required(options, 'workflow-sha256');
    const document = createSignedMobileBuildProvenance({
      releaseId: required(options, 'release-id'),
      sourceSha: required(options, 'source-sha'),
      workflowSha256,
      producerRunId: integerOption(options, 'producer-run-id'),
      producerRunAttempt: integerOption(options, 'producer-run-attempt'),
      pubspecLockSha256: rawSha256(
        readFileSync(required(options, 'pubspec-lock')),
      ),
      apkPath: required(options, 'apk'),
      ipaPath: required(options, 'ipa'),
      android: platformInput(
        loadJson(required(options, 'android-metadata'), 'Android metadata'),
        'android',
        workflowSha256,
      ),
      ios: platformInput(
        loadJson(required(options, 'ios-metadata'), 'iOS metadata'),
        'ios',
        workflowSha256,
      ),
    });
    const output = required(options, 'output');
    regularDirectory(dirname(output), 'output parent');
    writeFileSync(output, `${JSON.stringify(document, null, 2)}\n`, {
      encoding: 'utf8',
      flag: 'wx',
    });
    process.stdout.write('Signed mobile build provenance created\n');
    return;
  }
  if (command === 'validate-signed-bundle') {
    validateExactSignedMobileBundle(required(options, 'root'), {
      releaseId: required(options, 'release-id'),
      sourceSha: required(options, 'source-sha'),
      workflowSha256: required(options, 'workflow-sha256'),
      producerRunId: integerOption(options, 'producer-run-id'),
      producerRunAttempt: integerOption(options, 'producer-run-attempt'),
      pubspecLockSha256: sha256(
        required(options, 'pubspec-lock-sha256'),
        'pubspec-lock-sha256',
      ),
    });
    process.stdout.write('Signed mobile build bundle valid\n');
    return;
  }
  fail('command must be signed-provenance or validate-signed-bundle');
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  main();
}
