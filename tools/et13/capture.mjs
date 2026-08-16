import { createHash } from 'node:crypto';
import { readFileSync, statSync, writeFileSync } from 'node:fs';
import { mkdir, readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { dirname, extname, resolve, sep } from 'node:path';
import { createRequire } from 'node:module';

import pixelmatch from 'pixelmatch';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const require = createRequire(import.meta.url);
const axeSource = readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');
const standard = 'WCAG 2.2 AA';
const captureSurface = 'flutter_web_release_projection';
const allowedAxeTags = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'];

function fail(message) {
  throw new Error(`ET13 capture failed: ${message}`);
}

function options(argv) {
  const parsed = new Map();
  for (const value of argv) {
    if (!value.startsWith('--') || !value.includes('=')) fail(`invalid option ${value}`);
    const split = value.indexOf('=');
    parsed.set(value.slice(2, split), value.slice(split + 1));
  }
  return parsed;
}

function required(parsed, name) {
  const value = parsed.get(name);
  if (!value) fail(`missing --${name}`);
  return value;
}

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function pretty(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

function mime(path) {
  return {
    '.css': 'text/css; charset=utf-8',
    '.html': 'text/html; charset=utf-8',
    '.ico': 'image/x-icon',
    '.js': 'text/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.otf': 'font/otf',
    '.png': 'image/png',
    '.svg': 'image/svg+xml',
    '.ttf': 'font/ttf',
    '.wasm': 'application/wasm',
  }[extname(path)] ?? 'application/octet-stream';
}

async function serve(root, port) {
  const absoluteRoot = resolve(root);
  const rootPrefix = `${absoluteRoot}${sep}`;
  const fontManifestRequests = [];
  let nextFontManifestRequestId = 0;
  const server = createServer((request, response) => {
    const url = new URL(request.url, `http://127.0.0.1:${port}`);
    const isFontManifest = url.pathname === '/assets/FontManifest.json';
    const transport = isFontManifest
      ? {
          request_id: ++nextFontManifestRequestId,
          started_at_ms: Date.now(),
          request_connection: request.headers.connection ?? null,
        }
      : null;
    if (transport !== null) {
      fontManifestRequests.push(transport);
      response.setHeader('X-ET13-Manifest-Request-Id', String(transport.request_id));
      request.once('aborted', () => {
        transport.request_aborted_at_ms = Date.now();
      });
      response.once('error', (error) => {
        transport.response_error = String(error);
      });
      response.once('finish', () => {
        transport.response_finished_at_ms = Date.now();
      });
      response.once('close', () => {
        transport.response_closed_at_ms = Date.now();
        transport.response_writable_finished = response.writableFinished;
      });
    }
    const relative = decodeURIComponent(url.pathname).replace(/^\/+/, '') || 'index.html';
    let target = resolve(absoluteRoot, relative);
    if (target !== absoluteRoot && !target.startsWith(rootPrefix)) {
      response.writeHead(400).end('invalid path');
      return;
    }
    try {
      if (statSync(target).isDirectory()) target = resolve(target, 'index.html');
    } catch {
      if (extname(target)) {
        response.writeHead(404).end('not found');
        return;
      }
      target = resolve(absoluteRoot, 'index.html');
    }
    if (target !== absoluteRoot && !target.startsWith(rootPrefix)) {
      response.writeHead(400).end('invalid path');
      return;
    }
    const bytes = readFileSync(target);
    if (transport !== null) transport.response_bytes = bytes.length;
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('Content-Length', String(bytes.length));
    response.setHeader('Content-Type', mime(target));
    response.end(bytes);
  });
  await new Promise((resolveListen, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', resolveListen);
  });
  return {
    server,
    fontManifestRequestsSince(startedAt) {
      return fontManifestRequests.filter((request) => request.started_at_ms >= startedAt);
    },
  };
}

function pngDiffPercent(candidatePath, baselinePath, diffPath) {
  const candidate = PNG.sync.read(readFileSync(candidatePath));
  const baseline = PNG.sync.read(readFileSync(baselinePath));
  if (candidate.width !== baseline.width || candidate.height !== baseline.height) {
    fail(`baseline dimensions differ for ${candidatePath}`);
  }
  const diff = new PNG({ width: candidate.width, height: candidate.height });
  const changed = pixelmatch(
    candidate.data,
    baseline.data,
    diff.data,
    candidate.width,
    candidate.height,
    { threshold: 0, includeAA: true },
  );
  if (changed > 0 && diffPath) writeFileSync(diffPath, PNG.sync.write(diff));
  return Number(((changed * 100) / (candidate.width * candidate.height)).toFixed(8));
}

async function main() {
  const parsed = options(process.argv.slice(2));
  const sourceSha = required(parsed, 'source-sha');
  if (!/^(?!0{40}$)[0-9a-f]{40}$/.test(sourceSha)) fail('invalid source SHA');
  const catalogPath = required(parsed, 'catalog');
  const buildMarkerPath = required(parsed, 'build-marker');
  const outputRoot = resolve(required(parsed, 'output-root'));
  const mode = required(parsed, 'mode');
  if (!['diagnostic', 'release_ready'].includes(mode)) fail('invalid mode');
  const baselineRoot = parsed.get('baseline-root');
  if (mode === 'release_ready' && !baselineRoot) fail('release capture requires baselines');

  const roots = {
    web: required(parsed, 'web-root'),
    admin: required(parsed, 'admin-root'),
    mobile: required(parsed, 'mobile-root'),
  };
  const buildMarker = JSON.parse(await readFile(buildMarkerPath, 'utf8'));
  if (buildMarker.source_sha !== sourceSha) fail('build marker source SHA drifted');
  for (const distribution of buildMarker.distributions) {
    if (resolve(distribution.artifact_root) !== resolve(roots[distribution.id])) {
      fail(`${distribution.id} build root differs from its marker`);
    }
    for (const font of distribution.font_assets) {
      const bytes = readFileSync(resolve(distribution.artifact_root, font.artifact_path));
      if (bytes.length !== font.bytes || sha256(bytes) !== font.sha256) {
        fail(`${distribution.id}/${font.artifact_path} differs from its exact font marker`);
      }
    }
  }
  const ports = { web: 4173, admin: 4174, mobile: 4175 };
  const servers = new Map();
  let browser;
  try {
    for (const distribution of Object.keys(roots)) {
      servers.set(distribution, await serve(roots[distribution], ports[distribution]));
    }
    browser = await chromium.launch({
      headless: true,
      args: [
        '--disable-background-networking',
        '--disable-component-update',
        '--disable-domain-reliability',
        '--disable-features=MediaRouter,OptimizationHints',
        '--disable-sync',
        '--metrics-recording-only',
        '--no-default-browser-check',
        '--no-first-run',
      ],
    });
    const catalog = JSON.parse(await readFile(catalogPath, 'utf8'));
    const summaries = [];
    async function openValidatedPage(entry) {
      const pageStartedAt = Date.now();
      const context = await browser.newContext({
        viewport: { width: entry.width, height: entry.height },
        deviceScaleFactor: entry.device_pixel_ratio,
        locale: entry.locale,
        timezoneId: entry.timezone,
        reducedMotion: entry.reduced_motion ? 'reduce' : 'no-preference',
        colorScheme: entry.theme,
        serviceWorkers: 'block',
      });
      const page = await context.newPage();
      const cdp = await context.newCDPSession(page);
      await cdp.send('Network.enable');
      const unexpected = [];
      const pageErrors = [];
      const fontManifestBrowserTrace = [];
      const fontManifestCdpTrace = [];
      const fontManifestCdpRequestIds = new Set();
      const fontManifestRequestIds = new Map();
      let nextFontManifestRequestId = 0;
      const isFontManifestRequest = (request) =>
        new URL(request.url()).pathname === '/assets/FontManifest.json';
      cdp.on('Network.requestWillBeSent', (event) => {
        if (new URL(event.request.url).pathname !== '/assets/FontManifest.json') return;
        fontManifestCdpRequestIds.add(event.requestId);
        fontManifestCdpTrace.push({
          event: 'requestWillBeSent',
          request_id: event.requestId,
          at_ms: Date.now(),
        });
      });
      cdp.on('Network.responseReceived', (event) => {
        if (!fontManifestCdpRequestIds.has(event.requestId)) return;
        fontManifestCdpTrace.push({
          event: 'responseReceived',
          request_id: event.requestId,
          at_ms: Date.now(),
          status: event.response.status,
        });
      });
      cdp.on('Network.loadingFinished', (event) => {
        if (!fontManifestCdpRequestIds.has(event.requestId)) return;
        fontManifestCdpTrace.push({
          event: 'loadingFinished',
          request_id: event.requestId,
          at_ms: Date.now(),
          encoded_data_length: event.encodedDataLength,
        });
      });
      cdp.on('Network.loadingFailed', (event) => {
        if (!fontManifestCdpRequestIds.has(event.requestId)) return;
        fontManifestCdpTrace.push({
          event: 'loadingFailed',
          request_id: event.requestId,
          at_ms: Date.now(),
          error: event.errorText,
          canceled: event.canceled,
        });
      });
      page.on('request', (request) => {
        if (!isFontManifestRequest(request)) return;
        const requestId = ++nextFontManifestRequestId;
        fontManifestRequestIds.set(request, requestId);
        fontManifestBrowserTrace.push({
          event: 'request',
          request_id: requestId,
          at_ms: Date.now(),
        });
      });
      page.on('pageerror', (error) => pageErrors.push(String(error)));
      page.on('console', (message) => {
        if (message.type() === 'error') pageErrors.push(message.text());
      });
      page.on('requestfailed', (request) => {
        if (isFontManifestRequest(request)) {
          fontManifestBrowserTrace.push({
            event: 'requestfailed',
            request_id: fontManifestRequestIds.get(request) ?? null,
            at_ms: Date.now(),
            error: request.failure()?.errorText ?? 'unknown',
          });
        }
        pageErrors.push(
          `request failed: ${request.url()} (${request.failure()?.errorText ?? 'unknown'})`,
        );
      });
      page.on('requestfinished', (request) => {
        if (!isFontManifestRequest(request)) return;
        fontManifestBrowserTrace.push({
          event: 'requestfinished',
          request_id: fontManifestRequestIds.get(request) ?? null,
          at_ms: Date.now(),
        });
      });
      page.on('response', (response) => {
        if (isFontManifestRequest(response.request())) {
          fontManifestBrowserTrace.push({
            event: 'response',
            request_id: fontManifestRequestIds.get(response.request()) ?? null,
            at_ms: Date.now(),
            status: response.status(),
            server_request_id:
              response.headers()['x-et13-manifest-request-id'] ?? null,
          });
        }
        if (response.status() >= 400) {
          pageErrors.push(`HTTP ${response.status()}: ${response.url()}`);
        }
      });
      await page.route('**/*', async (route) => {
        const url = new URL(route.request().url());
        if (url.protocol === 'http:' && url.hostname === '127.0.0.1') {
          await route.continue();
          return;
        }
        unexpected.push(route.request().url());
        await route.abort('blockedbyclient');
      });
      const query = new URLSearchParams({
        fixture: entry.fixture_id,
        theme: entry.theme,
        textScalePercent: String(entry.text_scale_percent),
      });
      const url = `http://127.0.0.1:${ports[entry.distribution]}/?${query}`;
      await page.goto(url, { waitUntil: 'load' });
      const ready = `ET13_READY:${entry.fixture_id}`;
      const source = `ET13_SOURCE_SHA:${sourceSha}`;
      const surface = `ET13_CAPTURE_SURFACE:${captureSurface}`;
      const runtime =
        `ET13_RUNTIME_PROFILE:fixture=${entry.fixture_id}` +
        `;width=${entry.width};height=${entry.height}` +
        `;dpr=${entry.device_pixel_ratio};brightness=${entry.theme}` +
        `;textScalePercent=${entry.text_scale_percent}`;
      await page.getByLabel(surface, { exact: true }).waitFor({ state: 'attached' });
      for (const label of [ready, source, runtime]) {
        await page.getByText(label, { exact: true }).waitFor({ state: 'attached' });
      }
      await page.evaluate(() => document.fonts.ready);
      const fontResources = await page.evaluate(() =>
        performance
          .getEntriesByType('resource')
          .map((resource) => new URL(resource.name).pathname),
      );
      const expectedFonts = buildMarker.distributions
        .find((value) => value.id === entry.distribution)
        .font_assets.map((font) => `/${font.artifact_path}`);
      for (const fontPath of expectedFonts) {
        if (!fontResources.some((value) => value.endsWith(fontPath))) {
          fail(`${entry.case_id} did not load exact renderer font ${fontPath}`);
        }
      }
      const assertClean = () => {
        if (unexpected.length) fail(`${entry.case_id} attempted network: ${unexpected}`);
        if (pageErrors.length) {
          const serverTrace = servers
            .get(entry.distribution)
            .fontManifestRequestsSince(pageStartedAt);
          fail(
            `${entry.case_id} browser errors: ${pageErrors}; ` +
              `font manifest transport trace: ${JSON.stringify({
                browser: fontManifestBrowserTrace,
                cdp: fontManifestCdpTrace,
                server: serverTrace,
              })}`,
          );
        }
      };
      assertClean();
      return { context, page, assertClean };
    }

    const webHostedFixtures = catalog.fixtures.filter(
      (fixture) => fixture.distribution === 'web',
    );
    if (webHostedFixtures.length !== 8) fail('browser smoke requires 8 web-hosted fixtures');
    for (const fixture of webHostedFixtures) {
      for (const theme of ['light', 'dark']) {
        const smokeId = `${fixture.id}--browser-smoke--w320--${theme}--text200`;
        const entry = {
          case_id: smokeId,
          fixture_id: fixture.id,
          distribution: 'web',
          width: 320,
          height: 900,
          device_pixel_ratio: 1,
          theme,
          text_scale_percent: 200,
          locale: 'ko-KR',
          timezone: 'UTC',
          reduced_motion: true,
        };
        const { context, page, assertClean } = await openValidatedPage(entry);
        const first = resolve(outputRoot, 'review/browser-smoke', `${smokeId}--first.png`);
        const second = resolve(outputRoot, 'review/browser-smoke', `${smokeId}--second.png`);
        await mkdir(dirname(first), { recursive: true });
        await page.screenshot({ path: first, animations: 'disabled' });
        await page.evaluate(() =>
          new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))),
        );
        await page.screenshot({ path: second, animations: 'disabled' });
        if (pngDiffPercent(first, second) !== 0) {
          fail(`${smokeId} was not pixel-stable across two captures`);
        }
        assertClean();
        await context.close();
      }
    }

    for (const lane of ['visual', 'a11y']) {
      const cases = JSON.parse(
        await readFile(
          resolve(`evidence/et13/generated/${lane}-cases.v1.json`),
          'utf8',
        ),
      ).cases;
      for (const entry of cases) {
        const { context, page, assertClean } = await openValidatedPage(entry);

        const artifactPath = resolve(outputRoot, entry.artifact_path);
        await mkdir(dirname(artifactPath), { recursive: true });
        if (lane === 'visual') {
          await page.screenshot({ path: artifactPath, animations: 'disabled' });
          const screenshot = PNG.sync.read(readFileSync(artifactPath));
          if (
            screenshot.width !== entry.width * entry.device_pixel_ratio ||
            screenshot.height !== entry.height * entry.device_pixel_ratio
          ) {
            fail(`${entry.case_id} PNG axes differ from its catalog profile`);
          }
          let pixelDiffPercent = null;
          if (mode === 'release_ready') {
            const baselinePath = resolve(baselineRoot, entry.artifact_path);
            const diffPath = resolve(
              outputRoot,
              'review',
              entry.artifact_path.replace(/\.png$/, '.diff.png'),
            );
            await mkdir(dirname(diffPath), { recursive: true });
            pixelDiffPercent = pngDiffPercent(artifactPath, baselinePath, diffPath);
            if (pixelDiffPercent !== 0) fail(`${entry.case_id} differs from approved baseline`);
          }
          summaries.push({
            case_id: entry.case_id,
            lane,
            status: 'passed',
            artifact_path: entry.artifact_path,
            pixel_diff_percent: pixelDiffPercent,
          });
        } else {
          await page.addScriptTag({ content: axeSource });
          const axe = await page.evaluate(async (tags) => globalThis.axe.run(
            document,
            { runOnly: { type: 'tag', values: tags }, resultTypes: ['violations', 'passes', 'incomplete'] },
          ), allowedAxeTags);
          const violations = [...axe.violations]
            .sort((left, right) => left.id.localeCompare(right.id))
            .map((item) => ({
              id: item.id,
              impact: item.impact ?? 'minor',
              description: item.description,
              node_count: item.nodes.length,
            }));
          const result = {
            schema_version: 'leva.et13.a11y-result.v1',
            case_id: entry.case_id,
            standard,
            critical_violations: violations.filter((item) => item.impact === 'critical').length,
            serious_violations: violations.filter((item) => item.impact === 'serious').length,
            other_violations: violations.filter((item) => ['moderate', 'minor'].includes(item.impact)).length,
            passes: axe.passes.length,
            incomplete: axe.incomplete.length,
            violations,
          };
          writeFileSync(artifactPath, pretty(result));
          if (result.critical_violations || result.serious_violations) {
            fail(`${entry.case_id} has critical/serious automated a11y violations`);
          }
          summaries.push({
            case_id: entry.case_id,
            lane,
            status: 'passed',
            artifact_path: entry.artifact_path,
          });
        }
        assertClean();
        await context.close();
      }
    }
    const summary = {
      schema_version: 'leva.et13.capture-summary.v1',
      source_sha: sourceSha,
      evidence_mode: mode,
      capture_surface: captureSurface,
      device_evidence: false,
      case_count: summaries.length,
      cases: summaries,
    };
    await mkdir(resolve(outputRoot, 'artifacts/et13'), { recursive: true });
    writeFileSync(resolve(outputRoot, 'artifacts/et13/capture-summary.v1.json'), pretty(summary));
    process.stdout.write(`ET13 browser capture: ${summaries.length}/120 passed\n`);
  } finally {
    if (browser) await browser.close();
    await Promise.all(
      [...servers.values()].map(
        ({ server }) => new Promise((done) => server.close(done)),
      ),
    );
  }
}

await main();
