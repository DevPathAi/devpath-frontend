import assert from 'node:assert/strict';
import { mkdtemp, writeFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import { serve } from './serve.mjs';
import { validateReport, summarize } from './report.mjs';

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
