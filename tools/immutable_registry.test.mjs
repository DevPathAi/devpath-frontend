import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';

import { lookupGhcrManifest } from './immutable_registry.mjs';

const repository = 'ghcr.io/devpathai/devpath-admin';
const tag = '1'.repeat(40);
const actor = 'ci-contract';
const token = 'ghs_contract_token';
const scopedToken = 'scoped.token.value';

function response(body, status, headers = {}, url) {
  const filteredHeaders = Object.fromEntries(
    Object.entries(headers).filter(([, value]) => value !== undefined),
  );
  const result = new Response(body, { status, headers: filteredHeaders });
  Object.defineProperty(result, 'url', { configurable: true, value: url });
  return result;
}

function fetchFixture({
  manifestStatus = 200,
  manifestBody,
  manifestHeaders = {},
  tokenStatus = 200,
  tokenHeaders = { 'content-type': 'application/json' },
  tokenBody = JSON.stringify({ token: scopedToken }),
} = {}) {
  const manifest = manifestBody ?? JSON.stringify({ schemaVersion: 2 });
  const digest = `sha256:${createHash('sha256').update(manifest).digest('hex')}`;
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({ url: url.toString(), options });
    if (calls.length === 1) {
      return response(tokenBody, tokenStatus, tokenHeaders, url.toString());
    }
    return response(manifest, manifestStatus, {
      'content-type': 'application/vnd.oci.image.manifest.v1+json',
      'docker-content-digest': digest,
      ...manifestHeaders,
    }, url.toString());
  };
  return { calls, digest, fetchImpl };
}

test('authenticates exact token and manifest endpoints without redirects', async () => {
  const fixture = fetchFixture();
  const result = await lookupGhcrManifest({
    imageRepository: repository,
    imageTag: tag,
    actor,
    token,
    fetchImpl: fixture.fetchImpl,
  });

  assert.deepEqual(result, { state: 'present', digest: fixture.digest });
  assert.equal(fixture.calls.length, 2);
  assert.equal(
    fixture.calls[0].url,
    'https://ghcr.io/token?service=ghcr.io&scope=repository%3Adevpathai%2Fdevpath-admin%3Apull',
  );
  assert.equal(fixture.calls[0].options.redirect, 'manual');
  assert.equal(fixture.calls[0].options.headers['accept-encoding'], 'identity');
  assert.equal(
    fixture.calls[0].options.headers.authorization,
    `Basic ${Buffer.from(`${actor}:${token}`).toString('base64')}`,
  );
  assert.equal(
    fixture.calls[1].url,
    `https://ghcr.io/v2/devpathai/devpath-admin/manifests/${tag}`,
  );
  assert.equal(fixture.calls[1].options.redirect, 'manual');
  assert.equal(fixture.calls[1].options.headers['accept-encoding'], 'identity');
  assert.equal(
    fixture.calls[1].options.headers.authorization,
    `Bearer ${scopedToken}`,
  );
});

test('only exact manifest endpoint 404 MANIFEST_UNKNOWN is absent', async () => {
  const fixture = fetchFixture({
    manifestStatus: 404,
    manifestBody: JSON.stringify({
      errors: [{ code: 'MANIFEST_UNKNOWN', message: 'manifest unknown' }],
    }),
    manifestHeaders: {
      'content-type': 'application/json',
      'docker-content-digest': undefined,
    },
  });
  const result = await lookupGhcrManifest({
    imageRepository: repository,
    imageTag: tag,
    actor,
    token,
    fetchImpl: fixture.fetchImpl,
  });
  assert.deepEqual(result, { state: 'absent', digest: null });

  for (const status of [401, 403]) {
    const rejected = fetchFixture({
      manifestStatus: status,
      manifestBody: JSON.stringify({ errors: [] }),
    });
    await assert.rejects(
      lookupGhcrManifest({
        imageRepository: repository,
        imageTag: tag,
        actor,
        token,
        fetchImpl: rejected.fetchImpl,
      }),
      new RegExp(`failed closed with HTTP ${status}`),
    );
  }
});

test('rejects wrong endpoint and malformed 404 without registry mutation', async () => {
  let calls = 0;
  await assert.rejects(
    lookupGhcrManifest({
      imageRepository: 'ghcr.io/attacker/devpath-admin',
      imageTag: tag,
      actor,
      token,
      fetchImpl: async () => {
        calls += 1;
        return response('', 404, {}, 'https://ghcr.io/wrong');
      },
    }),
    /repository is not allowlisted/,
  );
  assert.equal(calls, 0);

  const malformed = fetchFixture({
    manifestStatus: 404,
    manifestBody: JSON.stringify({
      errors: [{ code: 'NAME_UNKNOWN', message: 'repository unknown' }],
    }),
    manifestHeaders: {
      'content-type': 'application/json',
      'docker-content-digest': undefined,
    },
  });
  await assert.rejects(
    lookupGhcrManifest({
      imageRepository: repository,
      imageTag: tag,
      actor,
      token,
      fetchImpl: malformed.fetchImpl,
    }),
    /not an exact MANIFEST_UNKNOWN/,
  );
});

test('rejects token or manifest redirects and unavailable transport', async () => {
  const tokenRedirect = fetchFixture({
    tokenStatus: 302,
    tokenBody: null,
    tokenHeaders: { location: 'https://attacker.example/token' },
  });
  await assert.rejects(
    lookupGhcrManifest({
      imageRepository: repository,
      imageTag: tag,
      actor,
      token,
      fetchImpl: tokenRedirect.fetchImpl,
    }),
    /token request redirected/,
  );

  const manifestRedirect = fetchFixture({
    manifestStatus: 302,
    manifestBody: null,
    manifestHeaders: { location: 'https://attacker.example/manifest' },
  });
  await assert.rejects(
    lookupGhcrManifest({
      imageRepository: repository,
      imageTag: tag,
      actor,
      token,
      fetchImpl: manifestRedirect.fetchImpl,
    }),
    /manifest request redirected/,
  );

  await assert.rejects(
    lookupGhcrManifest({
      imageRepository: repository,
      imageTag: tag,
      actor,
      token,
      fetchImpl: async () => {
        throw new Error('transport unavailable');
      },
    }),
    /transport unavailable/,
  );

  await assert.rejects(
    lookupGhcrManifest({
      imageRepository: repository,
      imageTag: tag,
      actor,
      token,
      fetchImpl: null,
    }),
    /fetch implementation is absent/,
  );
});

test('rejects same-origin wrong-path and empty response URLs', async () => {
  for (const responseUrl of ['https://ghcr.io/token/other', '']) {
    let calls = 0;
    await assert.rejects(
      lookupGhcrManifest({
        imageRepository: repository,
        imageTag: tag,
        actor,
        token,
        fetchImpl: async (url) => {
          calls += 1;
          return response(
            JSON.stringify({ token: scopedToken }),
            200,
            { 'content-type': 'application/json' },
            calls === 1 ? responseUrl : url.toString(),
          );
        },
      }),
      /token request response URL drifted/,
    );
    assert.equal(calls, 1);
  }

  for (const responseUrl of [
    'https://ghcr.io/v2/devpathai/devpath-admin/manifests/wrong',
    '',
  ]) {
    const fixture = fetchFixture();
    const baseFetch = fixture.fetchImpl;
    let calls = 0;
    await assert.rejects(
      lookupGhcrManifest({
        imageRepository: repository,
        imageTag: tag,
        actor,
        token,
        fetchImpl: async (url, options) => {
          calls += 1;
          const result = await baseFetch(url, options);
          if (calls === 2) {
            Object.defineProperty(result, 'url', { value: responseUrl });
          }
          return result;
        },
      }),
      /manifest request response URL drifted/,
    );
  }
});

test('requires JSON content type for absent manifests', async () => {
  const fixture = fetchFixture({
    manifestStatus: 404,
    manifestBody: JSON.stringify({
      errors: [{ code: 'MANIFEST_UNKNOWN', message: 'manifest unknown' }],
    }),
    manifestHeaders: {
      'content-type': 'text/plain',
      'docker-content-digest': undefined,
    },
  });
  await assert.rejects(
    lookupGhcrManifest({
      imageRepository: repository,
      imageTag: tag,
      actor,
      token,
      fetchImpl: fixture.fetchImpl,
    }),
    /absent response is not JSON/,
  );
});

test('rejects noncanonical MANIFEST_UNKNOWN error objects', async () => {
  for (const error of [
    {
      code: 'MANIFEST_UNKNOWN',
      message: 'manifest unknown',
      detail: 'tag missing',
    },
    { code: 'MANIFEST_UNKNOWN', message: 'unknown manifest' },
  ]) {
    const fixture = fetchFixture({
      manifestStatus: 404,
      manifestBody: JSON.stringify({ errors: [error] }),
      manifestHeaders: {
        'content-type': 'application/json',
        'docker-content-digest': undefined,
      },
    });
    await assert.rejects(
      lookupGhcrManifest({
        imageRepository: repository,
        imageTag: tag,
        actor,
        token,
        fetchImpl: fixture.fetchImpl,
      }),
      /unexpected keys|not an exact MANIFEST_UNKNOWN/,
    );
  }
});

test('requires declared content length to equal received bytes', async () => {
  const tokenBody = JSON.stringify({ token: scopedToken });
  const byteLength = Buffer.byteLength(tokenBody);
  for (const declared of [byteLength - 1, byteLength + 1]) {
    const fixture = fetchFixture({
      tokenBody,
      tokenHeaders: {
        'content-type': 'application/json',
        'content-length': String(declared),
      },
    });
    await assert.rejects(
      lookupGhcrManifest({
        imageRepository: repository,
        imageTag: tag,
        actor,
        token,
        fetchImpl: fixture.fetchImpl,
      }),
      /content-length does not match received bytes/,
    );
  }

  const malformed = fetchFixture({
    tokenBody,
    tokenHeaders: {
      'content-type': 'application/json',
      'content-length': '12x',
    },
  });
  await assert.rejects(
    lookupGhcrManifest({
      imageRepository: repository,
      imageTag: tag,
      actor,
      token,
      fetchImpl: malformed.fetchImpl,
    }),
    /content-length is malformed/,
  );
});

test('rejects manifest byte, digest, and content-type drift', async () => {
  const badDigest = fetchFixture({
    manifestHeaders: { 'docker-content-digest': `sha256:${'f'.repeat(64)}` },
  });
  await assert.rejects(
    lookupGhcrManifest({
      imageRepository: repository,
      imageTag: tag,
      actor,
      token,
      fetchImpl: badDigest.fetchImpl,
    }),
    /raw body digest mismatch/,
  );

  const badType = fetchFixture({
    manifestHeaders: { 'content-type': 'text/plain' },
  });
  await assert.rejects(
    lookupGhcrManifest({
      imageRepository: repository,
      imageTag: tag,
      actor,
      token,
      fetchImpl: badType.fetchImpl,
    }),
    /not an image manifest/,
  );
});
