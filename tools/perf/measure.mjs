// 성능 측정기(N04). mock 릴리스 빌드를 루프백으로 서빙하고 고정 조건(CPU 4×,
// 느린 네트워크)에서 라우트별 cold/warm p75 와 초기 전송량을 잰다.
//
// Flutter CanvasKit 은 <canvas> 에 그리므로 브라우저 LCP 후보가 없을 수 있다.
// 그래서 fcp_ms(브라우저 first-contentful-paint), ready_ms(시맨틱스 플레이스홀더
// 등장 = 첫 상호작용 가능 시점), lcp_ms(있으면), inp_ms(주 행동 클릭의 event
// duration 최댓값), cls 를 함께 기록한다. null 은 "측정 불가"이며 0 으로 적지 않는다.
//
// 사용: node measure.mjs --dist=<build/web> --renderer=<canvaskit|wasm> --out=<json> [--runs=5] [--built-from=<sha>]
import { execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { serve } from '../browser_ux/serve.mjs';

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));

export const SCHEMA_VERSION = 'leva.perf-measure.v1';
export const ROUTES = ['/login', '/dashboard', '/path', '/mentor', '/community'];
// Lighthouse 관례를 따른다: 모바일은 CPU 4× + Slow 4G, 데스크톱은 CPU 1× + 광대역.
export const PROFILES = {
  mobile: { width: 390, height: 844, dpr: 3, cpu_throttle: 4, download_bps: 625000, upload_bps: 187500, latency_ms: 80 },
  desktop: { width: 1440, height: 900, dpr: 1, cpu_throttle: 1, download_bps: 3750000, upload_bps: 1250000, latency_ms: 20 },
};
export const CONDITIONS = {
  locale: 'ko-KR',
  profiles: Object.fromEntries(
    Object.entries(PROFILES).map(([name, spec]) => [
      name,
      { cpu_throttle: spec.cpu_throttle, download_bps: spec.download_bps, upload_bps: spec.upload_bps, latency_ms: spec.latency_ms },
    ]),
  ),
};
const RENDERERS = new Set(['canvaskit', 'wasm']);
const PHASES = new Set(['cold', 'warm']);
const READY_TIMEOUT_MS = 120000;
const NAV_TIMEOUT_MS = 120000;

/** nearest-rank p75. null/undefined 표본은 제외하고, 표본이 없으면 null. */
export function p75(values) {
  const sorted = values.filter((value) => typeof value === 'number' && Number.isFinite(value)).sort((a, b) => a - b);
  if (!sorted.length) return null;
  return sorted[Math.ceil(0.75 * sorted.length) - 1];
}

export function classifyResource(url, mimeType = '') {
  const path = new URL(url, 'http://x').pathname.toLowerCase();
  if (path.includes('canvaskit') || path.endsWith('.wasm') || mimeType === 'application/wasm') return 'canvaskit_or_wasm';
  if (/\.(otf|ttf|woff2?)$/.test(path) || mimeType.startsWith('font/')) return 'fonts';
  if (/\.(png|jpe?g|gif|webp|svg|ico)$/.test(path) || mimeType.startsWith('image/')) return 'images';
  if (/\.(m?js)$/.test(path) || mimeType.includes('javascript')) return 'js';
  return 'other';
}

export function validateMeasureReport(report) {
  const problems = [];
  if (!report || typeof report !== 'object') return ['report must be an object'];
  if (report.schema_version !== SCHEMA_VERSION) problems.push(`schema_version must be ${SCHEMA_VERSION}`);
  if (!/^[0-9a-f]{40}$/.test(String(report.built_from ?? ''))) problems.push('built_from must be a 40-char git sha');
  if (!RENDERERS.has(report.renderer)) problems.push('renderer must be canvaskit or wasm');
  if (!report.conditions || report.conditions.locale !== CONDITIONS.locale) problems.push('conditions.locale missing');
  for (const profile of Object.keys(PROFILES)) {
    for (const key of ['cpu_throttle', 'download_bps', 'upload_bps', 'latency_ms']) {
      if (!report.conditions?.profiles?.[profile] || !(key in report.conditions.profiles[profile])) {
        problems.push(`conditions.profiles.${profile}.${key} missing`);
      }
    }
  }
  if (!Array.isArray(report.routes)) return [...problems, 'routes must be an array'];
  report.routes.forEach((row, index) => {
    if (!ROUTES.includes(row.route)) problems.push(`routes[${index}].route unknown`);
    if (!(row.profile in PROFILES)) problems.push(`routes[${index}].profile unknown`);
    if (!PHASES.has(row.phase)) problems.push(`routes[${index}].phase must be cold|warm`);
    if (!Number.isInteger(row.samples) || row.samples < 1) problems.push(`routes[${index}].samples invalid`);
    for (const key of ['fcp_ms', 'ready_ms', 'lcp_ms', 'inp_ms', 'cls']) {
      if (!row.p75 || !(key in row.p75)) problems.push(`routes[${index}].p75.${key} missing`);
    }
    for (const key of ['total', 'js', 'canvaskit_or_wasm', 'fonts', 'images', 'other']) {
      if (!row.transfer_bytes || typeof row.transfer_bytes[key] !== 'number') problems.push(`routes[${index}].transfer_bytes.${key} missing`);
    }
  });
  return problems;
}

function parseArgs(argv) {
  const options = { runs: 5 };
  for (const arg of argv) {
    const match = /^--([a-z-]+)=(.*)$/.exec(arg);
    if (match) options[match[1]] = match[2];
  }
  if (!options.dist || !options.out || !RENDERERS.has(options.renderer)) {
    throw new Error('usage: node measure.mjs --dist=<build/web> --renderer=<canvaskit|wasm> --out=<json> [--runs=5]');
  }
  options.runs = Number(options.runs);
  return options;
}

function gitSha() {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], { cwd: here, encoding: 'utf8' }).trim();
  } catch {
    return '0'.repeat(40);
  }
}

// 페이지에 심는 관측기: LCP/CLS/INP 후보를 모은다. 라우트 진입 전에 등록된다.
const OBSERVER_SCRIPT = `
  globalThis.__leva = { lcp: null, cls: 0, inp: 0 };
  try {
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) globalThis.__leva.lcp = entry.startTime;
    }).observe({ type: 'largest-contentful-paint', buffered: true });
  } catch {}
  try {
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) if (!entry.hadRecentInput) globalThis.__leva.cls += entry.value;
    }).observe({ type: 'layout-shift', buffered: true });
  } catch {}
  try {
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) globalThis.__leva.inp = Math.max(globalThis.__leva.inp, entry.duration);
    }).observe({ type: 'event', buffered: true, durationThreshold: 16 });
  } catch {}
`;

const PRIMARY_ACTION = {
  '/login': { role: 'button', name: /GitHub로 계속하기/ },
  '/dashboard': { role: 'button', name: /미션 열기|미션 완료|경로 만들기/ },
  '/path': { role: 'button', name: /미션 열기|미션 완료|경로 만들기/ },
  '/mentor': { role: 'button', name: /전송/ },
  '/community': { role: 'button', name: /^Q\/A$/ },
};

async function throttle(context, page, spec) {
  const cdp = await context.newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: spec.cpu_throttle });
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false,
    latency: spec.latency_ms,
    downloadThroughput: spec.download_bps,
    uploadThroughput: spec.upload_bps,
  });
  const transfer = { total: 0, js: 0, canvaskit_or_wasm: 0, fonts: 0, images: 0, other: 0 };
  const kinds = new Map();
  cdp.on('Network.responseReceived', (event) => {
    kinds.set(event.requestId, classifyResource(event.response.url, event.response.mimeType ?? ''));
  });
  cdp.on('Network.loadingFinished', (event) => {
    const kind = kinds.get(event.requestId) ?? 'other';
    transfer[kind] += event.encodedDataLength;
    transfer.total += event.encodedDataLength;
  });
  return { cdp, transfer, reset: () => { for (const key of Object.keys(transfer)) transfer[key] = 0; } };
}

async function measureNavigation(page, base, route) {
  await page.goto(base + route, { waitUntil: 'domcontentloaded', timeout: NAV_TIMEOUT_MS });
  const placeholder = page.locator('flt-semantics-placeholder').first();
  await placeholder.waitFor({ state: 'attached', timeout: READY_TIMEOUT_MS });
  // 플레이스홀더는 flutter-view 의 shadow DOM 안에 있어 페이지 스크립트의
  // document.querySelector 로는 보이지 않는다. Playwright 대기가 풀린 시점을 ready 로 잰다.
  const readyMs = await page.evaluate(() => performance.now());
  await placeholder.dispatchEvent('click');
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: READY_TIMEOUT_MS });
  await page.waitForLoadState('networkidle');
  const fcp = await page.evaluate(() => performance.getEntriesByName('first-contentful-paint')[0]?.startTime ?? null);
  const action = PRIMARY_ACTION[route];
  const target = page.getByRole(action.role, { name: action.name }).first();
  let interacted = false;
  if (await target.count()) {
    await target.click({ trial: false, timeout: 5000 }).catch(() => {});
    interacted = true;
    await page.waitForTimeout(1200);
  }
  const metrics = await page.evaluate(() => globalThis.__leva);
  return {
    fcp_ms: fcp,
    ready_ms: readyMs,
    lcp_ms: metrics.lcp,
    inp_ms: interacted ? metrics.inp : null,
    cls: metrics.cls,
  };
}

export async function run(options) {
  const dist = resolve(options.dist);
  const builtFrom = options['built-from'] ?? gitSha();
  const server = await serve(dist, { cacheable: true });
  const { chromium } = require('playwright');
  const browser = await chromium.launch();
  const routes = [];
  try {
    for (const [profile, spec] of Object.entries(PROFILES)) {
      for (const route of ROUTES) {
        const samples = { cold: [], warm: [] };
        const transfers = { cold: [], warm: [] };
        for (let run = 0; run < options.runs; run += 1) {
          const context = await browser.newContext({
            viewport: { width: spec.width, height: spec.height },
            deviceScaleFactor: spec.dpr,
            locale: CONDITIONS.locale,
            serviceWorkers: 'block',
          });
          await context.route('**/*', (r) => (new URL(r.request().url()).origin === server.base ? r.continue() : r.abort('blockedbyclient')));
          await context.addInitScript(OBSERVER_SCRIPT);
          const page = await context.newPage();
          const net = await throttle(context, page, spec);
          try {
            samples.cold.push(await measureNavigation(page, base(server), route));
            transfers.cold.push({ ...net.transfer });
            net.reset();
            samples.warm.push(await measureNavigation(page, base(server), route));
            transfers.warm.push({ ...net.transfer });
          } finally {
            await context.close();
          }
          console.log(`${profile} ${route} run ${run + 1}/${options.runs} cold ready=${Math.round(samples.cold.at(-1).ready_ms ?? -1)}ms warm ready=${Math.round(samples.warm.at(-1).ready_ms ?? -1)}ms`);
        }
        for (const phase of ['cold', 'warm']) {
          const rows = samples[phase];
          const bytes = transfers[phase];
          const median = (key) => p75(bytes.map((item) => item[key]));
          routes.push({
            route,
            profile,
            phase,
            samples: rows.length,
            p75: {
              fcp_ms: p75(rows.map((row) => row.fcp_ms)),
              ready_ms: p75(rows.map((row) => row.ready_ms)),
              lcp_ms: p75(rows.map((row) => row.lcp_ms)),
              inp_ms: p75(rows.map((row) => row.inp_ms)),
              cls: p75(rows.map((row) => row.cls)),
            },
            transfer_bytes: {
              total: median('total') ?? 0,
              js: median('js') ?? 0,
              canvaskit_or_wasm: median('canvaskit_or_wasm') ?? 0,
              fonts: median('fonts') ?? 0,
              images: median('images') ?? 0,
              other: median('other') ?? 0,
            },
          });
        }
      }
    }
  } finally {
    await browser.close();
    await server.close();
  }
  const report = { schema_version: SCHEMA_VERSION, built_from: builtFrom, renderer: options.renderer, conditions: CONDITIONS, routes };
  const problems = validateMeasureReport(report);
  if (problems.length) throw new Error('report invalid: ' + problems.join('; '));
  await mkdir(dirname(resolve(options.out)), { recursive: true });
  await writeFile(resolve(options.out), JSON.stringify(report, null, 2) + '\n');
  console.log(`perf-measure: ${routes.length} rows → ${resolve(options.out)}`);
  return report;
}

function base(server) {
  return server.base;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  run(parseArgs(process.argv.slice(2))).catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
