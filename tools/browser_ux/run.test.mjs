import assert from 'node:assert/strict';
import { mkdtemp, writeFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import { serve } from './serve.mjs';
import { validateReport, summarize } from './report.mjs';
import { ROUTES, routesOf, externalRequestFailure, axeFailures, AXE_WAIVERS } from './routes.mjs';

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

test('externalRequestFailure: 폭주는 한 라우트의 증가분으로 잡는다', () => {
  // 2026-09-26 실측: /content 한 화면에서 230건 넘게, 심할 때 695건.
  assert.match(
    externalRequestFailure({ route: '/content', delta: 230, total: 240, routeCount: 16 }),
    /\/content .*\+230/,
  );
});

test('externalRequestFailure: 라우트를 늘린 산술 증가는 실패가 아니다', () => {
  // S3-P5 실측: 라우트당 고정 2건(광고 스크립트 + 업데이트 피드)이라 16라우트면
  // 32건이 정상이고, 폰트 청크를 처음 받는 라우트가 12건을 더한다. 옛 게이트는
  // 컨텍스트 총합 40 을 넘겨 42 에서 붉어졌다 — 그것이 게이트의 결함이었다.
  assert.equal(
    externalRequestFailure({ route: '/community/new/post', delta: 2, total: 42, routeCount: 16 }),
    null,
  );
  assert.equal(
    externalRequestFailure({ route: '/sandbox', delta: 12, total: 24, routeCount: 16 }),
    null,
  );
});

test('externalRequestFailure: 총합도 라우트 수에 비례해 지킨다', () => {
  // 모든 라우트가 조금씩 더 부르는 느린 증가는 증가분만으로는 안 잡힌다.
  assert.equal(externalRequestFailure({ route: '/x', delta: 8, total: 128, routeCount: 16 }), null);
  assert.match(
    externalRequestFailure({ route: '/x', delta: 8, total: 129, routeCount: 16 }),
    /total 129/,
  );
});

const serious = (id) => ({ id, impact: 'serious', nodes: 3, help: id });

test('axeFailures: critical·serious 만 막고 minor·moderate 는 통과한다', () => {
  assert.deepEqual(
    axeFailures({
      route: '/dashboard',
      violations: [{ id: 'region', impact: 'moderate', nodes: 46, help: 'r' }],
    }),
    [],
  );
  assert.deepEqual(
    axeFailures({ route: '/dashboard', violations: [serious('color-contrast')] }),
    ['/dashboard color-contrast'],
  );
});

test('axeFailures: 유보한 규칙은 그 라우트에서만 통과한다', () => {
  const waived = AXE_WAIVERS[0];
  const route = waived.routes[0];
  const rule = waived.rules[0];
  assert.deepEqual(
    axeFailures({ route, violations: waived.rules.map(serious) }),
    [],
  );
  // 같은 규칙이라도 유보 목록에 없는 라우트에서는 막는다.
  assert.deepEqual(
    axeFailures({ route: '/dashboard', violations: [serious(rule)] }),
    ['/dashboard ' + rule],
  );
});

test('axeFailures: 유보가 낡으면 그 자체를 실패로 보고한다', () => {
  // 고쳐진 뒤에도 예외가 남으면 다음 회귀를 가린다.
  const waived = AXE_WAIVERS[0];
  const route = waived.routes[0];
  const failures = axeFailures({ route, violations: [] });
  assert.equal(failures.length, waived.rules.length);
  for (const rule of waived.rules) {
    assert.ok(
      failures.some((f) => f.includes(rule) && /stale/.test(f)),
      rule,
    );
  }
});

test('axeFailures: 유보 항목은 이유와 후속 과제를 적어 둔다', () => {
  for (const w of AXE_WAIVERS) {
    assert.ok(w.routes.length > 0);
    assert.ok(w.rules.length > 0);
    assert.ok(w.why && w.why.length > 20, 'why');
    assert.ok(w.followUp && w.followUp.length > 20, 'followUp');
  }
});
