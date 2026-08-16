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

function approval(platform) {
  return {
    approval_environment: `mission-spine-mobile-signing-${platform}`,
    approval_environment_id: platform === 'android' ? 101 : 102,
    approval_job_name:
      platform === 'android' ? 'Sign Android release' : 'Sign iOS release',
    approved_by: `reviewer-${platform}`,
    approved_by_id: platform === 'android' ? 201 : 202,
    approval_effective_at: '2026-08-17T01:02:03Z',
  };
}

function fixtureRoot() {
  const root = mkdtempSync(join(tmpdir(), 'signed-mobile-contract-'));
  const apkPath = join(root, 'mobile', 'android', 'leva-release.apk');
  const ipaPath = join(root, 'mobile', 'ios', 'leva-release.ipa');
  mkdirSync(join(root, 'mobile', 'android'), { recursive: true });
  mkdirSync(join(root, 'mobile', 'ios'), { recursive: true });
  writeFileSync(apkPath, Buffer.from('signed release-test apk'));
  writeFileSync(ipaPath, Buffer.from('signed distribution ipa'));
  return { root, apkPath, ipaPath };
}

function createFixture(root, apkPath, ipaPath) {
  return createSignedMobileBuildProvenance({
    releaseId: 'release-2026-08-17',
    repository: 'DevPathAi/devpath-frontend',
    sourceSha,
    workflowSha256,
    producerRunId: 901,
    producerRunAttempt: 1,
    pubspecLockSha256,
    apkPath,
    ipaPath,
    android: {
      applicationId: 'ai.devpath.devpath_mobile',
      versionName: '1.0.0',
      versionCode: 1,
      signatureVerified: true,
      signingCertificateSha256: '3'.repeat(64),
      approval: approval('android'),
    },
    ios: {
      bundleId: 'ai.devpath.devpathMobile',
      shortVersion: '1.0.0',
      bundleVersion: '1',
      signatureVerified: true,
      teamId: 'ABCDE12345',
      signingCertificateSha256: '4'.repeat(64),
      provisioningProfileUuid: '12345678-1234-1234-1234-1234567890AB',
      provisioningProfileExpiresAt: '2027-08-17T01:02:03Z',
      approval: approval('ios'),
    },
  });
}

test('signed mobile provenance is exact and binds packaged binary bytes', () => {
  const fixture = fixtureRoot();
  try {
    const provenance = createFixture(
      fixture.root,
      fixture.apkPath,
      fixture.ipaPath,
    );
    writeFileSync(
      join(fixture.root, 'build-provenance.v1.json'),
      `${JSON.stringify(provenance, null, 2)}\n`,
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
      'ios',
      'approvals',
    ]);
    assert.equal(
      provenance.android.sha256,
      sha256(readFileSync(fixture.apkPath)),
    );
    assert.equal(
      provenance.ios.sha256,
      sha256(readFileSync(fixture.ipaPath)),
    );
    assert.deepEqual(Object.keys(provenance.android), [
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
    ]);
    assert.equal(
      provenance.android.signing_classification,
      'org_keystore_release_test_distribution',
    );
    assert.equal(provenance.android.play_app_signing, false);
    assert.deepEqual(Object.keys(provenance.ios), [
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
    ]);
    assert.equal(provenance.ios.signing_classification, 'organization_distribution');
    assert.equal(provenance.ios.export_method, 'ad-hoc');
    assert.equal(
      provenance.ios.distribution_scope,
      'protected_manual_at_test_devices',
    );

    assert.doesNotThrow(() =>
      validateExactSignedMobileBundle(fixture.root, {
        releaseId: 'release-2026-08-17',
        sourceSha,
        workflowSha256,
        producerRunId: 901,
        producerRunAttempt: 1,
        pubspecLockSha256,
      }),
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('signed mobile provenance rejects byte drift and non-exact documents', () => {
  const fixture = fixtureRoot();
  try {
    const provenance = createFixture(
      fixture.root,
      fixture.apkPath,
      fixture.ipaPath,
    );
    writeFileSync(fixture.apkPath, Buffer.from('substituted apk'));
    assert.throws(
      () =>
        validateSignedMobileBuildProvenance(provenance, {
          releaseId: 'release-2026-08-17',
          sourceSha,
          workflowSha256,
          producerRunId: 901,
          producerRunAttempt: 1,
          pubspecLockSha256,
          apkPath: fixture.apkPath,
          ipaPath: fixture.ipaPath,
        }),
      /android\.sha256 mismatch/,
    );

    const withExtra = structuredClone(provenance);
    withExtra.play_store_signed = true;
    assert.throws(
      () =>
        validateSignedMobileBuildProvenance(withExtra, {
          releaseId: 'release-2026-08-17',
          sourceSha,
          workflowSha256,
          producerRunId: 901,
          producerRunAttempt: 1,
          pubspecLockSha256,
          apkPath: fixture.apkPath,
          ipaPath: fixture.ipaPath,
        }),
      /key set/,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('signed mobile bundle rejects extras and links', () => {
  const fixture = fixtureRoot();
  try {
    const provenance = createFixture(
      fixture.root,
      fixture.apkPath,
      fixture.ipaPath,
    );
    writeFileSync(
      join(fixture.root, 'build-provenance.v1.json'),
      `${JSON.stringify(provenance, null, 2)}\n`,
    );
    writeFileSync(join(fixture.root, 'unexpected.txt'), 'not allowed');
    assert.throws(
      () =>
        validateExactSignedMobileBundle(fixture.root, {
          releaseId: 'release-2026-08-17',
          sourceSha,
          workflowSha256,
          producerRunId: 901,
          producerRunAttempt: 1,
          pubspecLockSha256,
        }),
      /exactly three regular files/,
    );
    rmSync(join(fixture.root, 'unexpected.txt'));

    const linked = join(fixture.root, 'mobile', 'android', 'linked.apk');
    try {
      symlinkSync(fixture.apkPath, linked, 'file');
    } catch (error) {
      if (process.platform === 'win32' && error.code === 'EPERM') return;
      throw error;
    }
    assert.throws(
      () =>
        validateExactSignedMobileBundle(fixture.root, {
          releaseId: 'release-2026-08-17',
          sourceSha,
          workflowSha256,
          producerRunId: 901,
          producerRunAttempt: 1,
          pubspecLockSha256,
        }),
      /link|exactly three regular files/,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('signed provenance CLI assembles exact platform metadata and revalidates', () => {
  const fixture = fixtureRoot();
  try {
    const androidMetadata = {
      workflow_sha256: workflowSha256,
      application_id: 'ai.devpath.devpath_mobile',
      version_name: '1.0.0',
      version_code: 1,
      signature_verified: true,
      signing_certificate_sha256: '3'.repeat(64),
      approval: approval('android'),
    };
    const iosMetadata = {
      workflow_sha256: workflowSha256,
      bundle_id: 'ai.devpath.devpathMobile',
      short_version: '1.0.0',
      bundle_version: '1',
      signature_verified: true,
      signing_classification: 'organization_distribution',
      export_method: 'ad-hoc',
      distribution_scope: 'protected_manual_at_test_devices',
      team_id: 'ABCDE12345',
      signing_certificate_sha256: '4'.repeat(64),
      provisioning_profile_uuid: '12345678-1234-1234-1234-1234567890AB',
      provisioning_profile_expires_at: '2027-08-17T01:02:03Z',
      approval: approval('ios'),
    };
    const androidMetadataPath = join(fixture.root, 'android-metadata.json');
    const iosMetadataPath = join(fixture.root, 'ios-metadata.json');
    const lockPath = join(fixture.root, 'pubspec.lock');
    const outputPath = join(fixture.root, 'build-provenance.v1.json');
    writeFileSync(androidMetadataPath, JSON.stringify(androidMetadata));
    writeFileSync(iosMetadataPath, JSON.stringify(iosMetadata));
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
        `--ipa=${fixture.ipaPath}`,
        `--android-metadata=${androidMetadataPath}`,
        `--ios-metadata=${iosMetadataPath}`,
        `--output=${outputPath}`,
      ],
      { encoding: 'utf8', windowsHide: true },
    );
    assert.equal(result.status, 0, result.stderr);
    assert.equal(
      JSON.parse(readFileSync(outputPath, 'utf8')).ios.export_method,
      'ad-hoc',
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});
