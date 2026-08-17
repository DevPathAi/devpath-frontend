import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

const allowedRepositories = new Map([
  ['ghcr.io/devpathai/devpath-web', {
    path: 'devpathai/devpath-web',
    tag: /^[0-9a-f]{40}-mission-(?:off|on)$/,
  }],
  ['ghcr.io/devpathai/devpath-admin', {
    path: 'devpathai/devpath-admin',
    tag: /^[0-9a-f]{40}$/,
  }],
]);

const manifestTypes = new Set([
  'application/vnd.oci.image.index.v1+json',
  'application/vnd.oci.image.manifest.v1+json',
  'application/vnd.docker.distribution.manifest.list.v2+json',
  'application/vnd.docker.distribution.manifest.v2+json',
]);

function fail(message) {
  throw new Error(message);
}

function exactKeys(value, allowed, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object`);
  }
  const actual = Object.keys(value).sort();
  const expected = [...allowed].sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    fail(`${label} has unexpected keys`);
  }
}

async function readBounded(response, limit, label) {
  const declared = response.headers.get('content-length');
  let declaredSize = null;
  if (declared !== null) {
    if (!/^(?:0|[1-9][0-9]*)$/.test(declared)) {
      fail(`${label} content-length is malformed`);
    }
    declaredSize = Number(declared);
    if (declaredSize > limit) fail(`${label} exceeds size limit`);
  }
  if (response.body === null) fail(`${label} body is absent`);
  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) {
      await reader.cancel();
      fail(`${label} exceeds size limit`);
    }
    chunks.push(value);
  }
  if (declaredSize !== null && size !== declaredSize) {
    fail(`${label} content-length does not match received bytes`);
  }
  if (size < 2) fail(`${label} body is too small`);
  return Buffer.concat(chunks.map((chunk) => Buffer.from(chunk)), size);
}

function parseJson(bytes, label) {
  let text;
  try {
    text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    fail(`${label} is not UTF-8`);
  }
  try {
    return JSON.parse(text);
  } catch {
    fail(`${label} is not JSON`);
  }
}

function requireNoRedirect(response, expectedUrl, label) {
  if (response.status >= 300 && response.status < 400) {
    fail(`${label} redirected`);
  }
  if (response.url !== expectedUrl.href) {
    fail(`${label} response URL drifted`);
  }
}

async function fetchScopedToken(repositoryPath, actor, token, fetchImpl) {
  if (!/^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(actor)) {
    fail('GHCR_ACTOR is invalid');
  }
  if (!/^[A-Za-z0-9_]+$/.test(token) || token.length > 512) {
    fail('GHCR_TOKEN is invalid');
  }
  const tokenUrl = new URL('https://ghcr.io/token');
  tokenUrl.searchParams.set('service', 'ghcr.io');
  tokenUrl.searchParams.set('scope', `repository:${repositoryPath}:pull`);
  const response = await fetchImpl(tokenUrl, {
    method: 'GET',
    redirect: 'manual',
    headers: {
      accept: 'application/json',
      'accept-encoding': 'identity',
      authorization: `Basic ${Buffer.from(`${actor}:${token}`).toString('base64')}`,
    },
    signal: AbortSignal.timeout(60_000),
  });
  requireNoRedirect(response, tokenUrl, 'GHCR token request');
  if (response.status !== 200) {
    fail(`GHCR token request failed with HTTP ${response.status}`);
  }
  const contentType = response.headers.get('content-type')?.split(';')[0];
  if (contentType !== 'application/json') {
    fail('GHCR token response is not JSON');
  }
  const payload = parseJson(
    await readBounded(response, 64 * 1024, 'GHCR token response'),
    'GHCR token response',
  );
  const allowedKeys = new Set(['token', 'access_token', 'expires_in', 'issued_at']);
  const actualKeys = Object.keys(payload);
  if (actualKeys.some((key) => !allowedKeys.has(key))) {
    fail('GHCR token response has unexpected keys');
  }
  const scopedToken = payload.token ?? payload.access_token;
  if (typeof scopedToken !== 'string' ||
      scopedToken.length < 16 || scopedToken.length > 16 * 1024 ||
      !/^[A-Za-z0-9._~-]+$/.test(scopedToken)) {
    fail('GHCR scoped token is invalid');
  }
  if (payload.token !== undefined && payload.access_token !== undefined &&
      payload.token !== payload.access_token) {
    fail('GHCR token aliases disagree');
  }
  return scopedToken;
}

export async function lookupGhcrManifest({
  imageRepository,
  imageTag,
  actor,
  token,
  fetchImpl = globalThis.fetch,
}) {
  const config = allowedRepositories.get(imageRepository);
  if (config === undefined) fail('registry lookup repository is not allowlisted');
  if (!config.tag.test(imageTag)) fail('immutable image tag is invalid');
  if (typeof fetchImpl !== 'function') fail('fetch implementation is absent');

  const scopedToken = await fetchScopedToken(
    config.path,
    actor,
    token,
    fetchImpl,
  );
  const manifestUrl = new URL(
    `https://ghcr.io/v2/${config.path}/manifests/${imageTag}`,
  );
  const response = await fetchImpl(manifestUrl, {
    method: 'GET',
    redirect: 'manual',
    headers: {
      accept: [...manifestTypes].join(', '),
      'accept-encoding': 'identity',
      authorization: `Bearer ${scopedToken}`,
    },
    signal: AbortSignal.timeout(60_000),
  });
  requireNoRedirect(response, manifestUrl, 'GHCR manifest request');
  const bytes = await readBounded(
    response,
    1024 * 1024,
    'GHCR manifest response',
  );
  const payload = parseJson(bytes, 'GHCR manifest response');

  if (response.status === 200) {
    const contentType = response.headers.get('content-type')?.split(';')[0];
    if (!manifestTypes.has(contentType)) {
      fail('GHCR response is not an image manifest');
    }
    if (payload === null || typeof payload !== 'object' ||
        Array.isArray(payload) || payload.schemaVersion !== 2) {
      fail('GHCR manifest body is malformed');
    }
    const digest = response.headers.get('docker-content-digest');
    if (digest === null || digest.includes(',') ||
        !/^sha256:[0-9a-f]{64}$/.test(digest)) {
      fail('GHCR manifest response digest is invalid');
    }
    const computed = `sha256:${createHash('sha256').update(bytes).digest('hex')}`;
    if (computed !== digest) fail('GHCR manifest raw body digest mismatch');
    return { state: 'present', digest };
  }

  if (response.status === 404) {
    const contentType = response.headers.get('content-type')?.split(';')[0];
    if (contentType !== 'application/json') {
      fail('GHCR absent response is not JSON');
    }
    exactKeys(payload, ['errors'], 'GHCR absent response');
    if (!Array.isArray(payload.errors) || payload.errors.length !== 1) {
      fail('GHCR absent response error cardinality is invalid');
    }
    const error = payload.errors[0];
    exactKeys(error, ['code', 'message'], 'GHCR absent error');
    if (
        error.code !== 'MANIFEST_UNKNOWN' ||
        error.message !== 'manifest unknown') {
      fail('GHCR 404 is not an exact MANIFEST_UNKNOWN response');
    }
    if (response.headers.get('docker-content-digest') !== null) {
      fail('absent GHCR response cannot carry a manifest digest');
    }
    return { state: 'absent', digest: null };
  }

  fail(`GHCR manifest request failed closed with HTTP ${response.status}`);
}

async function main() {
  if (process.argv.slice(2).join(' ') !== 'lookup') {
    fail('usage: immutable_registry.mjs lookup');
  }
  const result = await lookupGhcrManifest({
    imageRepository: process.env.IMAGE_REPOSITORY ?? '',
    imageTag: process.env.IMAGE_TAG ?? '',
    actor: process.env.GHCR_ACTOR ?? '',
    token: process.env.GHCR_TOKEN ?? '',
  });
  if (result.state === 'present') {
    process.stdout.write(`present ${result.digest}\n`);
  } else {
    process.stdout.write('absent\n');
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
