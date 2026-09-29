import assert from 'node:assert/strict';
import { mkdtemp, writeFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import { serve } from './serve.mjs';
import { validateReport, summarize } from './report.mjs';
import { ROUTES, routesOf } from './routes.mjs';

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
