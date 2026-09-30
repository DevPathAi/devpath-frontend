import assert from 'node:assert/strict';
import { mkdtemp, writeFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import { serve } from './serve.mjs';
import { validateReport, summarize } from './report.mjs';
import {
  ROUTES,
  routesOf,
  externalRequestFailure,
  axeFailures,
  staleWaiverFailures,
  AXE_WAIVERS,
} from './routes.mjs';

test('serve: 존재하는 파일은 그대로, 미존재 경로는 index.html(SPA fallback), feed 는 stub', async () => {
  const dist = await mkdtemp(join(tmpdir(), 'bux-dist-'));
  await writeFile(join(dist, 'index.html'), '<!doctype html><title>app</title>');
  await mkdir(join(dist, 'assets'), { recursive: true });
  await writeFile(join(dist, 'assets', 'a.json'), '{"ok":true}');
  const { base, close } = await serve(dist);
  try {
    const asset = await fetch(`${base}/assets/a.json`);
    assert.equal(asset.status, 200);
    assert.equal(asset.headers.get('content-type'), 'application/json');
    assert.deepEqual(await asset.json(), { ok: true });

    const deep = await fetch(`${base}/community?board=QNA`);
    assert.equal(deep.status, 200);
    assert.match(await deep.text(), /<title>app<\/title>/);

    const feed = await fetch(`${base}/updates/feed.json`);
    assert.equal(feed.status, 200);
    assert.deepEqual(await feed.json(), { items: [] });
  } finally {
    await close();
  }
});

test('validateReport: 필수 키와 시나리오 상태를 검증한다', () => {
  const good = {
    schema_version: 'leva.browser-ux.v1',
    built_from: 'a'.repeat(40),
    scenarios: [
      { id: 'deep-link-returns', width: 390, text_scale: 100, reduced_motion: false, status: 'passed', details: {} },
    ],
    summary: { passed: 1, failed: 0 },
  };
  assert.deepEqual(validateReport(good), []);
  const bad = { ...good, scenarios: [{ ...good.scenarios[0], status: 'maybe' }] };
  assert.ok(validateReport(bad).length > 0);
  assert.ok(validateReport({}).length > 0);
});

test('summarize: passed/failed 를 센다', () => {
  const scenarios = [
    { id: 'a', status: 'passed' },
    { id: 'b', status: 'failed' },
    { id: 'c', status: 'passed' },
  ];
  assert.deepEqual(summarize(scenarios), { passed: 2, failed: 1 });
});

test('routesOf: 기본은 ROUTES, --routes 는 그것을 덮는다', () => {
  assert.deepEqual(routesOf({}), ROUTES);
  assert.deepEqual(routesOf({ routes: '/login, /consent' }), ['/login', '/consent']);
});

test('routesOf: --routes= 가 비면 기본값으로 조용히 넘어가지 않고 던진다', () => {
  // 넘어가면 온보딩 잡이 한 라우트가 아니라 16개를 재고도 초록으로 끝난다.
  assert.throws(() => routesOf({ routes: '' }), /empty/);
  assert.throws(() => routesOf({ routes: ' , ' }), /empty/);
});

test('ROUTES 는 S3-P4 가 바꾼 화면을 담는다', () => {
  for (const route of [
    '/community/post/10',
    '/community/post/10/edit',
    '/community/1',
    '/community/1/edit',
    '/community/new',
    '/community/new/post',
    '/settings',
    '/mypage',
  ]) {
    assert.ok(ROUTES.includes(route), route);
  }
});

test('ROUTES 는 onboarded 빌드가 돌려보내는 라우트를 담지 않는다', () => {
  // 담으면 다른 화면(리다이렉트 대상)을 두 번 재는 테스트가 된다.
  // apps/web/test/app/gate_redirect_test.dart 의 「온보딩 라우트는 전부 돌려보낸다」와 짝이다.
  for (const route of ['/login', '/consent', '/diagnostic', '/beta-pending', '/auth/callback']) {
    assert.ok(!ROUTES.includes(route), route);
  }
});




const serious = (id, nodes = 3) => ({ id, impact: 'serious', nodes, help: id });
const fixed = (n) => Array.from({ length: n }, (_, i) => `https://x.example/${i}`);
const repeated = (url, n) => Array.from({ length: n }, () => url);

test('externalRequestFailure: 폭주는 같은 URL 의 반복으로 잡는다', () => {
  // 2026-09-26 실측: 한 화면에서 같은 청크가 695회. S3-P5 실측: 5청크 × 약 435회.
  // 정상 폰트 로딩은 서로 다른 URL 을 한 번씩 받는다 — 반복이 폭주의 표지다.
  assert.match(
    externalRequestFailure({
      route: '/content',
      added: repeated('https://fonts.gstatic.com/a.woff2', 230),
      total: 240,
      routeCount: 16,
    }),
    /\/content .*230x/,
  );
});

test('externalRequestFailure: 로컬에서 보였던 작은 폭주도 잡는다', () => {
  // /community/1 은 로컬에서 +5 로 정착해 옛 게이트(라우트당 40)를 지나갔다.
  // 그 +5 안에 같은 청크의 재요청이 있었다 — 그것이 CI 에서 2651건이 됐다.
  assert.match(
    externalRequestFailure({
      route: '/community/1',
      added: [
        'https://pagead2.googlesyndication.com/x.js',
        'http://127.0.0.1:1/updates/feed.json',
        ...repeated('https://fonts.gstatic.com/notocoloremoji.9.woff2', 4),
      ],
      total: 34,
      routeCount: 16,
    }),
    /4x/,
  );
});

test('externalRequestFailure: 서로 다른 URL 을 한 번씩 받는 것은 실패가 아니다', () => {
  // /sandbox 실측: 폰트 청크 첫 수신으로 +12, 전부 서로 다른 URL.
  assert.equal(
    externalRequestFailure({
      route: '/sandbox',
      added: fixed(12),
      total: 24,
      routeCount: 16,
    }),
    null,
  );
  // 라우트당 고정 2건(광고 스크립트 + 업데이트 피드)은 매 라우트에 있다.
  assert.equal(
    externalRequestFailure({ route: '/settings', added: fixed(2), total: 42, routeCount: 16 }),
    null,
  );
});

test('externalRequestFailure: 한 라우트가 정상값의 여러 배를 부르면 잡는다', () => {
  // 반복이 없어도 라우트당 상한이 두 번째 그물이다. 옛 상한 40 은 정상값(+2)의
  // 20배라 이 구간을 통째로 흘려보냈다.
  assert.match(
    externalRequestFailure({ route: '/x', added: fixed(17), total: 40, routeCount: 16 }),
    /17 > 16/,
  );
});

test('externalRequestFailure: 라우트 한 개짜리 잡에서 폰트 청크가 실패가 되지 않는다', () => {
  // browser-ux-onboarding (consent) 는 routeCount 가 1 이다. 비례 총합만 쓰면
  // 예산이 8 이 되어 /sandbox 의 실측 +12 보다 엄격해진다 — 바닥이 필요하다.
  assert.equal(
    externalRequestFailure({ route: '/consent', added: fixed(12), total: 12, routeCount: 1 }),
    null,
  );
});

test('externalRequestFailure: 총합도 라우트 수에 비례해 지킨다', () => {
  assert.equal(
    externalRequestFailure({ route: '/x', added: fixed(8), total: 128, routeCount: 16 }),
    null,
  );
  assert.match(
    externalRequestFailure({ route: '/x', added: fixed(8), total: 129, routeCount: 16 }),
    /total 129/,
  );
});

test('axeFailures: critical·serious 만 막고 minor·moderate 는 통과한다', () => {
  const seen = new Map();
  assert.deepEqual(
    axeFailures({
      route: '/dashboard',
      violations: [{ id: 'region', impact: 'moderate', nodes: 46, help: 'r' }],
      seen,
    }),
    [],
  );
  assert.deepEqual(
    axeFailures({ route: '/dashboard', violations: [serious('color-contrast')], seen }),
    ['/dashboard color-contrast'],
  );
});

test('axeFailures: 유보한 규칙은 그 라우트에서 유보한 노드 수까지만 통과한다', () => {
  const waived = AXE_WAIVERS[0];
  const route = waived.routes[0];
  const [rule, cap] = Object.entries(waived.rules)[0];
  const seen = new Map();

  // 원인이 만드는 노드 수까지는 유보.
  assert.deepEqual(axeFailures({ route, violations: [serious(rule, cap)], seen }), []);
  // 그보다 적어도 유보(반응형으로 줄어들 수 있다).
  assert.deepEqual(axeFailures({ route, violations: [serious(rule, cap - 1)], seen }), []);
  // **한 노드라도 늘면 막는다** — 우리 코드가 만든 새 위반이 유보에 숨지 못하게.
  assert.match(
    axeFailures({ route, violations: [serious(rule, cap + 1)], seen })[0],
    new RegExp(`${rule}.*${cap + 1} nodes`),
  );
  // 같은 규칙이라도 유보 목록에 없는 라우트에서는 막는다.
  assert.deepEqual(
    axeFailures({ route: '/dashboard', violations: [serious(rule, 1)], seen }),
    ['/dashboard ' + rule],
  );
});

test('axeFailures: seen 은 심각도 필터보다 먼저 기록한다', () => {
  // axe-core 승급으로 유보 규칙이 moderate 로 내려가면, 여전히 발생하는데도
  // 「낡은 유보」로 보고돼 버린다.
  const waived = AXE_WAIVERS[0];
  const route = waived.routes[0];
  const rule = Object.keys(waived.rules)[0];
  const seen = new Map();
  axeFailures({
    route,
    violations: [{ id: rule, impact: 'moderate', nodes: 8, help: rule }],
    seen,
  });
  assert.ok(seen.get(route).has(rule));
});

test('staleWaiverFailures: 유보가 낡으면 그 자체를 실패로 보고한다', () => {
  const waived = AXE_WAIVERS[0];
  const route = waived.routes[0];
  const seen = new Map([[route, new Set()]]);
  const failures = staleWaiverFailures(seen);
  for (const rule of Object.keys(waived.rules)) {
    assert.ok(
      failures.some((f) => f.includes(route) && f.includes(rule) && /stale/.test(f)),
      rule,
    );
  }
});

test('staleWaiverFailures: 한 폭에서만 안 나는 것은 낡은 것이 아니다', () => {
  // axe 는 390 과 1240 두 폭에서 돈다. 폭마다 따로 판정하면 1240 에서만 나는
  // 규칙이 390 에서 하드 실패가 된다 — 전 폭을 모아 한 번만 판정해야 한다.
  const waived = AXE_WAIVERS[0];
  const route = waived.routes[0];
  const rules = Object.keys(waived.rules);
  const seen = new Map();
  // 390 에서는 아무것도 안 났고, 1240 에서 둘 다 났다.
  axeFailures({ route, violations: [], seen });
  axeFailures({ route, violations: rules.map((r) => serious(r, waived.rules[r])), seen });
  assert.deepEqual(staleWaiverFailures(seen), []);
});

test('staleWaiverFailures: 방문하지 않은 라우트는 판정하지 않는다', () => {
  // 순회가 그 라우트에 닿지 못했으면(다른 라우트가 실패해 continue) 유보가
  // 낡았는지 알 수 없다 — 모른다고 실패시키면 안 된다.
  assert.deepEqual(staleWaiverFailures(new Map()), []);
});

test('AXE_WAIVERS: 각 항목은 이유와 후속 과제와 노드 수를 적어 둔다', () => {
  for (const w of AXE_WAIVERS) {
    assert.ok(w.routes.length > 0);
    assert.ok(Object.keys(w.rules).length > 0);
    for (const cap of Object.values(w.rules)) {
      assert.ok(Number.isInteger(cap) && cap > 0, 'rules 의 값은 유보하는 노드 수다');
    }
    assert.ok(w.why && w.why.length > 20, 'why');
    assert.ok(w.followUp && w.followUp.length > 20, 'followUp');
  }
});
