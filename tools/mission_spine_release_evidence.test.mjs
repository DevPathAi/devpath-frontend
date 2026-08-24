import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  createSignedMobileBuildProvenance,
  validateExactSignedMobileBundle,
  validateSignedMobileBuildProvenance,
} from './mission_spine_release_evidence.mjs';

const sourceSha = '1234567890abcdef1234567890abcdef12345678';
const workflowSha256 = '1'.repeat(64);
const pubspecLockSha256 = '2'.repeat(64);

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function approval() {
  return {
    approval_environment: 'mission-spine-mobile-signing-android',
    approval_environment_id: 101,
    approval_job_name: 'Sign Android release',
    approved_by: 'reviewer-android',
    approved_by_id: 201,
    approval_effective_at: '2026-08-17T01:02:03Z',
  };
}

function fixtureRoot() {
  const root = mkdtempSync(join(tmpdir(), 'signed-android-contract-'));
  const apkPath = join(root, 'mobile', 'android', 'leva-release.apk');
  mkdirSync(join(root, 'mobile', 'android'), { recursive: true });
  writeFileSync(apkPath, Buffer.from('signed release-test apk'));
  return { root, apkPath };
}

function createFixture(apkPath) {
  return createSignedMobileBuildProvenance({
    releaseId: 'release-2026-08-17',
    repository: 'DevPathAi/devpath-frontend',
    sourceSha,
    workflowSha256,
    producerRunId: 901,
    producerRunAttempt: 1,
    pubspecLockSha256,
    apkPath,
    android: {
      applicationId: 'ai.devpath.devpath_mobile',
      versionName: '1.0.0',
      versionCode: 1,
      signatureVerified: true,
      signingCertificateSha256: '3'.repeat(64),
      approval: approval(),
    },
  });
}

function expectations(apkPath) {
  return {
    releaseId: 'release-2026-08-17',
    sourceSha,
    workflowSha256,
    producerRunId: 901,
    producerRunAttempt: 1,
    pubspecLockSha256,
    ...(apkPath ? { apkPath } : {}),
  };
}

test('signed Android provenance v2 is exact and binds packaged APK bytes', () => {
  const fixture = fixtureRoot();
  try {
    const provenance = createFixture(fixture.apkPath);
    writeFileSync(
      join(fixture.root, 'build-provenance.v2.json'),
      `${JSON.stringify(provenance, null, 2)}\n`,
    );

    assert.equal(
      provenance.schema_version,
      'leva.mission-spine.signed-android-build.v2',
    );
    assert.deepEqual(Object.keys(provenance), [
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
      'approvals',
    ]);
    assert.deepEqual(Object.keys(provenance.toolchain), [
      'flutter_version',
      'flutter_revision',
      'dart_sdk_version',
      'android',
    ]);
    assert.deepEqual(Object.keys(provenance.approvals), ['android']);
    assert.equal(
      provenance.android.sha256,
      sha256(readFileSync(fixture.apkPath)),
    );
    assert.equal(
      provenance.android.signing_classification,
      'org_keystore_release_test_distribution',
    );
    assert.equal(provenance.android.play_app_signing, false);

    assert.doesNotThrow(() =>
      validateExactSignedMobileBundle(fixture.root, expectations()),
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('signed Android provenance rejects byte drift, legacy schema, and iOS fields', () => {
  const fixture = fixtureRoot();
  try {
    const provenance = createFixture(fixture.apkPath);
    writeFileSync(fixture.apkPath, Buffer.from('substituted apk'));
    assert.throws(
      () => validateSignedMobileBuildProvenance(provenance, expectations(fixture.apkPath)),
      /android\.sha256 mismatch/,
    );

    const legacySchema = structuredClone(provenance);
    legacySchema.schema_version = 'leva.mission-spine.signed-mobile-build.v1';
    assert.throws(
      () => validateSignedMobileBuildProvenance(legacySchema, expectations(fixture.apkPath)),
      /schema_version mismatch/,
    );

    const withIos = structuredClone(provenance);
    withIos.ios = { artifact_path: 'mobile/ios/leva-release.ipa' };
    assert.throws(
      () => validateSignedMobileBuildProvenance(withIos, expectations(fixture.apkPath)),
      /key set/,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('signed Android bundle rejects extras, legacy IPA, and links', () => {
  const fixture = fixtureRoot();
  try {
    const provenance = createFixture(fixture.apkPath);
    writeFileSync(
      join(fixture.root, 'build-provenance.v2.json'),
      `${JSON.stringify(provenance, null, 2)}\n`,
    );
    writeFileSync(join(fixture.root, 'unexpected.txt'), 'not allowed');
    assert.throws(
      () => validateExactSignedMobileBundle(fixture.root, expectations()),
      /exactly two regular files/,
    );
    rmSync(join(fixture.root, 'unexpected.txt'));

    const legacyIos = join(fixture.root, 'mobile', 'ios');
    mkdirSync(legacyIos);
    writeFileSync(join(legacyIos, 'leva-release.ipa'), 'legacy IPA');
    assert.throws(
      () => validateExactSignedMobileBundle(fixture.root, expectations()),
      /exactly two regular files/,
    );
    rmSync(legacyIos, { recursive: true });

    const linked = join(fixture.root, 'mobile', 'android', 'linked.apk');
    try {
      symlinkSync(fixture.apkPath, linked, 'file');
    } catch (error) {
      if (process.platform === 'win32' && error.code === 'EPERM') return;
      throw error;
    }
    assert.throws(
      () => validateExactSignedMobileBundle(fixture.root, expectations()),
      /link|exactly two regular files/,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('signed provenance CLI assembles exact Android metadata and revalidates', () => {
  const fixture = fixtureRoot();
  try {
    const androidMetadata = {
      workflow_sha256: workflowSha256,
      application_id: 'ai.devpath.devpath_mobile',
      version_name: '1.0.0',
      version_code: 1,
      signature_verified: true,
      signing_certificate_sha256: '3'.repeat(64),
      approval: approval(),
    };
    const androidMetadataPath = join(fixture.root, 'android-metadata.json');
    const lockPath = join(fixture.root, 'pubspec.lock');
    const outputPath = join(fixture.root, 'build-provenance.v2.json');
    writeFileSync(androidMetadataPath, JSON.stringify(androidMetadata));
    writeFileSync(lockPath, 'locked workspace\n');

    const result = spawnSync(
      process.execPath,
      [
        fileURLToPath(
          new URL('./mission_spine_release_evidence.mjs', import.meta.url),
        ),
        'signed-provenance',
        '--release-id=release-2026-08-17',
        `--source-sha=${sourceSha}`,
        `--workflow-sha256=${workflowSha256}`,
        '--producer-run-id=901',
        '--producer-run-attempt=1',
        `--pubspec-lock=${lockPath}`,
        `--apk=${fixture.apkPath}`,
        `--android-metadata=${androidMetadataPath}`,
        `--output=${outputPath}`,
      ],
      { encoding: 'utf8', windowsHide: true },
    );
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(
      Object.keys(JSON.parse(readFileSync(outputPath, 'utf8')).approvals),
      ['android'],
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});
