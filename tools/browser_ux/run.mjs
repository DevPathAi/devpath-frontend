// 브라우저 UX·접근성 러너(N03).
//
// mock 릴리스 빌드(build/web)를 루프백으로 서빙하고 실제 Chromium 에서
// deep link · 새로고침 · back/forward · 키보드 순회 · focus 복귀 · overflow ·
// 24px 타깃(WCAG 2.2 AA 2.5.8, 계약 2.0.0) · reduced-motion · axe 를 검증한다. 외부 네트워크 요청은 차단하고 기록한다.
//
// 사용: node run.mjs --dist=<build/web> --out=<report.json> [--built-from=<sha>] [--only=<id,id>]
import { execFileSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { SCHEMA_VERSION, summarize, validateReport } from './report.mjs';
import { serve } from './serve.mjs';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = dirname(fileURLToPath(import.meta.url));

export const WIDTHS = [390, 768, 1024, 1440];
export const ROUTES = [
  '/dashboard',
  '/path',
  '/community',
  '/community?board=QNA',
  '/community?board=FEEDBACK',
  '/mentor',
  '/sandbox',
  '/content/future-async-await',
];
const HEIGHT = 900;
const MIN_TARGET = 24; // = DpDensity.minTarget (packages/dp_design/lib/src/theme/dp_spacing.dart)
const AXE_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'best-practice'];
const READY_TIMEOUT_MS = 20000;

function parseArgs(argv) {
  const options = {};
  for (const arg of argv) {
    const match = /^--([a-z-]+)=(.*)$/.exec(arg);
    if (match) options[match[1]] = match[2];
  }
  if (!options.dist || !options.out) {
    throw new Error('usage: node run.mjs --dist=<build/web> --out=<report.json> [--built-from=<sha>] [--only=<ids>]');
  }
  return options;
}

function gitSha() {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], { cwd: here, encoding: 'utf8' }).trim();
  } catch {
    return '0'.repeat(40);
  }
}

/** 페이지 컨텍스트: 루프백 이외 요청은 차단하고 기록한다. */
async function openPage(browser, base, { width, textScale = 100, reducedMotion = false, colorScheme = 'light' }) {
  const context = await browser.newContext({
    viewport: { width, height: HEIGHT },
    locale: 'ko-KR',
    reducedMotion: reducedMotion ? 'reduce' : 'no-preference',
    colorScheme,
    serviceWorkers: 'block',
  });
  const external = [];
  const pageErrors = [];
  await context.route('**/*', (route) => {
    const url = new URL(route.request().url());
    if (url.origin === base) return route.continue();
    external.push(url.href);
    return route.abort('blockedbyclient');
  });
  if (textScale !== 100) {
    const px = Math.round((16 * textScale) / 100);
    await context.addInitScript((size) => {
      document.addEventListener('DOMContentLoaded', () => {
        document.documentElement.style.fontSize = `${size}px`;
      });
    }, px);
  }
  const page = await context.newPage();
  page.on('pageerror', (error) => pageErrors.push(String(error)));
  return { context, page, external, pageErrors };
}

/** Flutter 시맨틱스 트리를 켜고 첫 상호작용 요소가 나타날 때까지 기다린다. */
async function ready(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.first().waitFor({ state: 'attached', timeout: READY_TIMEOUT_MS });
  await placeholder.first().dispatchEvent('click');
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: READY_TIMEOUT_MS });
  await page.waitForLoadState('networkidle');
  // mock 응답이 도착해 로딩 상태('… 불러오는 중')가 사라질 때까지 기다린다. 남아 있으면
  // 측정(라벨 집합·axe)이 타이밍에 따라 달라진다. 끝내 남으면 그 자체가 관찰 결과다.
  await page
    .locator('flt-semantics[aria-label*="불러오는 중"], flt-semantics[aria-label*="확인하는 중"]')
    .first()
    .waitFor({ state: 'detached', timeout: 8000 })
    .catch(() => {});
  await page.waitForTimeout(400);
}

async function goto(page, base, path) {
  await page.goto(base + path, { waitUntil: 'load' });
  await ready(page);
}

function location(page) {
  const url = new URL(page.url());
  return url.pathname + url.search;
}

async function headings(page) {
  return page.getByRole('heading').allTextContents();
}

async function activeElement(page) {
  return page.evaluate(() => {
    const el = document.activeElement;
    if (!el) return null;
    return {
      tag: el.tagName.toLowerCase(),
      role: el.getAttribute('role'),
      label: el.getAttribute('aria-label') ?? el.textContent?.trim() ?? '',
    };
  });
}

async function overflow(page) {
  return page.evaluate(() => ({
    scrollWidth: document.scrollingElement.scrollWidth,
    innerWidth: window.innerWidth,
  }));
}

async function smallTargets(page) {
  const buttons = page.getByRole('button');
  const count = await buttons.count();
  const offenders = [];
  for (let index = 0; index < count; index += 1) {
    const button = buttons.nth(index);
    const box = await button.boundingBox();
    if (!box) continue;
    if (Math.min(box.width, box.height) < MIN_TARGET) {
      offenders.push({
        label: (await button.getAttribute('aria-label')) ?? (await button.textContent())?.trim() ?? '',
        width: Math.round(box.width),
        height: Math.round(box.height),
      });
    }
  }
  return offenders;
}

async function semanticText(page) {
  return page.evaluate(() => {
    const texts = new Set();
    for (const node of document.querySelectorAll('flt-semantics, flt-semantics-host *')) {
      const label = node.getAttribute?.('aria-label');
      if (label) texts.add(label.trim());
    }
    return [...texts].sort();
  });
}

let axeSourceCache;
async function axeScan(page) {
  axeSourceCache ??= await readFile(require.resolve('axe-core/axe.min.js'), 'utf8');
  await page.addScriptTag({ content: axeSourceCache });
  const result = await page.evaluate(
    async (tags) => globalThis.axe.run(document, { runOnly: { type: 'tag', values: tags }, resultTypes: ['violations'] }),
    AXE_TAGS,
  );
  return result.violations.map((item) => ({ id: item.id, impact: item.impact ?? 'minor', nodes: item.nodes.length, help: item.help }));
}

/** 시나리오 실행 헬퍼: 결과 객체를 만들고 예외를 실패로 기록한다. */
async function scenario(list, meta, body) {
  const entry = { ...meta, status: 'passed', details: {} };
  try {
    const details = await body();
    entry.details = details ?? {};
    if (details?.failures?.length) entry.status = 'failed';
  } catch (error) {
    entry.status = 'failed';
    entry.details = { error: String(error).slice(0, 600) };
  }
  list.push(entry);
  const mark = entry.status === 'passed' ? 'PASS' : 'FAIL';
  console.log(`[${mark}] ${meta.id} w=${meta.width} ts=${meta.text_scale} rm=${meta.reduced_motion}${entry.status === 'failed' ? ' ' + JSON.stringify(entry.details).slice(0, 300) : ''}`);
}

export async function run(options) {
  const dist = resolve(options.dist);
  const builtFrom = options['built-from'] ?? gitSha();
  const only = options.only ? new Set(options.only.split(',')) : null;
  const expectations = JSON.parse(await readFile(resolve(here, 'expectations.json'), 'utf8'));
  const server = await serve(dist);
  const browser = await chromium.launch();
  const scenarios = [];
  const wants = (id) => !only || only.has(id);

  try {
    // 1. deep link 가 세션 부트스트랩(AuthLoading → 인증) 을 지나 그대로 남는다.
    if (wants('deep-link-returns')) {
      for (const width of [390, 1440]) {
        await scenario(scenarios, { id: 'deep-link-returns', width, text_scale: 100, reduced_motion: false }, async () => {
          const { context, page, external } = await openPage(browser, server.base, { width });
          try {
            await goto(page, server.base, '/community?board=QNA');
            const failures = [];
            if (location(page) !== '/community?board=QNA') failures.push(`landed on ${location(page)}`);
            const h = await headings(page);
            if (!h.includes('Q/A')) failures.push(`headings ${JSON.stringify(h)}`);
            // 외부 요청은 차단한 채 기록만 한다(광고·홈 피드·CanvasKit 폴백 폰트는 앱의 정상 동작).
            return { location: location(page), headings: h, external: external.slice(0, 10), failures };
          } finally {
            await context.close();
          }
        });
      }
    }

    // 2. 새로고침 후 board 유지.
    if (wants('refresh-keeps-board')) {
      await scenario(scenarios, { id: 'refresh-keeps-board', width: 768, text_scale: 100, reduced_motion: false }, async () => {
        const { context, page } = await openPage(browser, server.base, { width: 768 });
        try {
          await goto(page, server.base, '/community?board=FEEDBACK');
          await page.reload({ waitUntil: 'load' });
          await ready(page);
          const failures = [];
          if (location(page) !== '/community?board=FEEDBACK') failures.push(`after reload ${location(page)}`);
          const h = await headings(page);
          if (!h.includes('피드백')) failures.push(`headings ${JSON.stringify(h)}`);
          return { location: location(page), headings: h, failures };
        } finally {
          await context.close();
        }
      });
    }

    // 3. board 전환 뒤 back/forward 가 URL 과 H1 을 함께 되돌린다.
    //    390 폭에서 게시판을 옮기는 유일한 수단은 헤더의 접힌 메뉴다(S3-P2).
    //    페이지 안 세그먼트도, 제목 메뉴도 쓰지 않는다.
    if (wants('back-forward-boards')) {
      await scenario(scenarios, { id: 'back-forward-boards', width: 390, text_scale: 100, reduced_motion: false }, async () => {
        const { context, page } = await openPage(browser, server.base, { width: 390 });
        try {
          await goto(page, server.base, '/community');
          const trail = [];
          const record = async (step) => trail.push({ step, location: location(page), headings: await headings(page) });
          await record('start');
          // 셸의 컨트롤을 role+name 으로 못 찾으면 30초 타임아웃만 남고 "그럼 뭐가
          // 있었는지" 가 사라진다. 실패 전에 브라우저가 실제로 내는 이름을 남긴다
          // (2026-09-26: 햄버거가 세 번 연속 이 자리에서 죽었는데 VM 시맨틱스는
          // 라벨을 '메뉴' 로 정상 보고했다).
          const exposed = await page.evaluate(() =>
            [...document.querySelectorAll('flt-semantics')]
              .map((el) => `${el.getAttribute('role') ?? '-'}:${el.getAttribute('aria-label') ?? ''}`)
              .filter((entry) => entry !== '-:')
              .slice(0, 40));
          try {
            for (const [label, expectedQuery] of [['Q/A', 'board=QNA'], ['피드백', 'board=FEEDBACK']]) {
              await page.getByRole('button', { name: '메뉴', exact: true }).first().click();
              // Flutter Web 은 접힘 메뉴 항목을 링크가 아니라 button 으로 낸다(함정 4).
              await page.getByRole('button', { name: label, exact: true }).first().click();
              await page.waitForURL((url) => url.search.includes(expectedQuery), { timeout: READY_TIMEOUT_MS });
              await page.waitForTimeout(300);
              await record(`select ${label}`);
            }
          } catch (error) {
            const first = String(error).split(String.fromCharCode(10))[0];
            return { trail, exposed, failures: [`board switch failed: ${first}`] };
          }
          await page.goBack({ waitUntil: 'load' });
          await page.waitForTimeout(500);
          await record('back');
          await page.goBack({ waitUntil: 'load' });
          await page.waitForTimeout(500);
          await record('back');
          await page.goForward({ waitUntil: 'load' });
          await page.waitForTimeout(500);
          await record('forward');
          const failures = [];
          const expect = (index, query, heading) => {
            const item = trail[index];
            if (!item.location.includes(query)) failures.push(`${item.step}: ${item.location}`);
            if (!item.headings.includes(heading)) failures.push(`${item.step}: headings ${JSON.stringify(item.headings)}`);
          };
          expect(1, 'board=QNA', 'Q/A');
          expect(2, 'board=FEEDBACK', '피드백');
          expect(3, 'board=QNA', 'Q/A');
          expect(5, 'board=QNA', 'Q/A');
          return { trail, failures };
        } finally {
          await context.close();
        }
      });
    }

    // 4. 키보드 순회 순서(desktop 커뮤니티). 기대값은 expectations.json 에 실측으로 고정.
    if (wants('keyboard-traversal')) {
      await scenario(scenarios, { id: 'keyboard-traversal', width: 1440, text_scale: 100, reduced_motion: false }, async () => {
        const { context, page } = await openPage(browser, server.base, { width: 1440 });
        try {
          await goto(page, server.base, '/community');
          const sequence = [];
          for (let index = 0; index < 14; index += 1) {
            await page.keyboard.press('Tab');
            await page.waitForTimeout(80);
            const active = await activeElement(page);
            sequence.push(active?.label ?? '');
          }
          const expected = expectations.keyboard_traversal?.community_desktop ?? null;
          const failures = [];
          if (expected === null) {
            failures.push('expectations.keyboard_traversal.community_desktop is not recorded yet');
          } else {
            const trimmed = sequence.slice(0, expected.length);
            if (JSON.stringify(trimmed) !== JSON.stringify(expected)) failures.push(`order ${JSON.stringify(trimmed)}`);
          }
          return { sequence, expected, failures };
        } finally {
          await context.close();
        }
      });
    }

    // 5. 오버레이(메뉴) 닫힘 후 focus 가 여는 버튼으로 복귀.
    //    셸의 계정·커뮤니티 메뉴도 같은 DpMenuButton 을 쓴다(S3-P2) — 여기서는 화면 안
    //    정렬 메뉴로 재고, 셸 메뉴는 axe 와 키보드 순회가 덮는다.
    //    커뮤니티의 작성 버튼은 시트 없이 작성 화면으로 직행하므로, 같은 화면의 정렬 메뉴로 잰다.
    if (wants('dialog-focus-return')) {
      await scenario(scenarios, { id: 'dialog-focus-return', width: 1024, text_scale: 100, reduced_motion: false }, async () => {
        const { context, page } = await openPage(browser, server.base, { width: 1024 });
        try {
          await goto(page, server.base, '/community');
          const opener = page.getByRole('button', { name: '최신순', exact: true }).first();
          await opener.focus();
          const openerLabel = (await opener.getAttribute('aria-label')) ?? (await opener.textContent())?.trim();
          await page.keyboard.press('Enter');
          await page.waitForTimeout(600);
          const item = page.getByRole('button', { name: '추천순', exact: true });
          const opened = await item.count();
          await page.keyboard.press('Escape');
          await page.waitForTimeout(600);
          const closed = await item.count();
          const active = await activeElement(page);
          const failures = [];
          if (opened === 0) failures.push('sort menu did not open on Enter');
          if (closed !== 0) failures.push('sort menu did not close on Escape');
          if ((active?.label ?? '') !== openerLabel) failures.push(`focus on ${JSON.stringify(active)} not ${openerLabel}`);
          return { opener: openerLabel, opened, closed, active, failures };
        } finally {
          await context.close();
        }
      });
    }

    // 6. overflow(4폭 × 100/200%) 와 44px 타깃(390).
    if (wants('overflow-and-targets')) {
      for (const width of WIDTHS) {
        for (const textScale of [100, 200]) {
          await scenario(scenarios, { id: 'overflow-and-targets', width, text_scale: textScale, reduced_motion: false }, async () => {
            const { context, page, external, pageErrors } = await openPage(browser, server.base, { width, textScale });
            try {
              const failures = [];
              const routes = {};
              for (const route of ROUTES) {
                // goto 안의 ready() 는 networkidle 을 기다린다. 여기서 그냥 던지면
                // "어느 라우트에서" "브라우저가 무엇을 불평하며" 안 가라앉았는지가
                // 통째로 사라진다(2026-09-26 실측: 390x200% 가 이 자리에서 30초 타임아웃).
                try {
                  await goto(page, server.base, route);
                } catch (error) {
                  const first = String(error).split(String.fromCharCode(10))[0];
                  failures.push(`${route} did not settle: ${first}`);
                  break;
                }
                const size = await overflow(page);
                const targets = width === 390 && textScale === 100 ? await smallTargets(page) : [];
                routes[route] = { location: location(page), ...size, small_targets: targets };
                if (size.scrollWidth > size.innerWidth) failures.push(`${route} overflows ${size.scrollWidth}>${size.innerWidth}`);
                if (targets.length) failures.push(`${route} small targets ${JSON.stringify(targets.slice(0, 4))}`);
              }
              return {
                routes,
                external: [...new Set(external)].slice(0, 10),
                // 중복 제거 전 총 건수. 차단된 요청을 앱이 재시도하면
                // networkidle 이 영원히 안 온다 — 그 폭주를 고유 목록으로는
                // 구별할 수 없다(390x200% 가 이 자리에서 624건으로 멈춘다).
                external_total: external.length,
                // 무엇을 몇 번 다시 부르는지. 총 건수만으로는 범인을 못 고른다.
                external_top: Object.entries(
                  external.reduce((counts, url) => {
                    const key = url.replace(/\?.*$/, '');
                    counts[key] = (counts[key] ?? 0) + 1;
                    return counts;
                  }, {}),
                )
                  .sort((a, b) => b[1] - a[1])
                  .slice(0, 5)
                  .map(([url, count]) => `${count}x ${url}`),
                page_errors: [...new Set(pageErrors)].slice(0, 5),
                failures,
              };
            } finally {
              await context.close();
            }
          });
        }
      }
    }

    // 7. reduced-motion 에서도 같은 정보가 노출된다.
    if (wants('reduced-motion-parity')) {
      await scenario(scenarios, { id: 'reduced-motion-parity', width: 768, text_scale: 100, reduced_motion: true }, async () => {
        const failures = [];
        const diff = {};
        for (const route of ['/dashboard', '/community', '/path']) {
          const texts = [];
          for (const reducedMotion of [false, true]) {
            const { context, page } = await openPage(browser, server.base, { width: 768, reducedMotion });
            try {
              await goto(page, server.base, route);
              texts.push(await semanticText(page));
            } finally {
              await context.close();
            }
          }
          const missing = texts[0].filter((text) => !texts[1].includes(text));
          diff[route] = { without: texts[0].length, with: texts[1].length, missing };
          if (missing.length) failures.push(`${route} loses ${missing.slice(0, 5)}`);
        }
        return { diff, failures };
      });
    }

    // 8. axe (390 light / 1240 dark).
    if (wants('axe')) {
      for (const [width, colorScheme] of [[390, 'light'], [1240, 'dark']]) {
        await scenario(scenarios, { id: 'axe', width, text_scale: 100, reduced_motion: false }, async () => {
          const { context, page } = await openPage(browser, server.base, { width, colorScheme });
          try {
            const failures = [];
            const routes = {};
            for (const route of ROUTES) {
              await goto(page, server.base, route);
              const violations = await axeScan(page);
              routes[route] = violations;
              const blocking = violations.filter((item) => ['critical', 'serious'].includes(item.impact));
              if (blocking.length) failures.push(`${route} ${blocking.map((item) => item.id).join(',')}`);
            }
            return { color_scheme: colorScheme, routes, failures };
          } finally {
            await context.close();
          }
        });
      }
    }
  } finally {
    await browser.close();
    await server.close();
  }

  const report = { schema_version: SCHEMA_VERSION, built_from: builtFrom, scenarios, summary: summarize(scenarios) };
  const problems = validateReport(report);
  if (problems.length) throw new Error('report invalid: ' + problems.join('; '));
  await mkdir(dirname(resolve(options.out)), { recursive: true });
  await writeFile(resolve(options.out), JSON.stringify(report, null, 2) + '\n');
  console.log(`browser-ux: passed=${report.summary.passed} failed=${report.summary.failed} → ${resolve(options.out)}`);
  return report;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  run(parseArgs(process.argv.slice(2)))
    .then((report) => process.exit(report.summary.failed ? 1 : 0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
