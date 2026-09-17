import assert from 'node:assert/strict';
import { test } from 'node:test';

import { p75, classifyResource, validateMeasureReport, SCHEMA_VERSION } from './measure.mjs';

test('p75: nearest-rank 로 계산한다', () => {
  assert.equal(p75([1, 2, 3, 4, 5]), 4); // ceil(0.75*5)=4 번째 → 4
  assert.equal(p75([10]), 10);
  assert.equal(p75([5, 1, 3]), 5); // 정렬 후 ceil(2.25)=3 번째 → 5
  assert.equal(p75([]), null);
  assert.equal(p75([1, null, 3, undefined]), 3); // null 은 표본에서 제외
});

test('classifyResource: 자산 종류를 URL·MIME 으로 나눈다', () => {
  assert.equal(classifyResource('http://x/main.dart.js', 'text/javascript'), 'js');
  assert.equal(classifyResource('http://x/canvaskit/canvaskit.wasm', 'application/wasm'), 'canvaskit_or_wasm');
  assert.equal(classifyResource('http://x/canvaskit/canvaskit.js', 'text/javascript'), 'canvaskit_or_wasm');
  assert.equal(classifyResource('http://x/main.dart.wasm', 'application/wasm'), 'canvaskit_or_wasm');
  assert.equal(classifyResource('http://x/assets/fonts/Pretendard-Regular.otf', 'font/otf'), 'fonts');
  assert.equal(classifyResource('http://x/icons/Icon-192.png', 'image/png'), 'images');
  assert.equal(classifyResource('http://x/assets/AssetManifest.bin.json', 'application/json'), 'other');
});

test('validateMeasureReport: 스키마 필수 키와 라우트 행을 검증한다', () => {
  const row = {
    route: '/dashboard',
    profile: 'mobile',
    phase: 'cold',
    samples: 5,
    p75: { fcp_ms: 900, ready_ms: 1800, lcp_ms: null, inp_ms: 40, cls: 0.01 },
    transfer_bytes: { total: 100, js: 60, canvaskit_or_wasm: 30, fonts: 5, images: 0, other: 5 },
  };
  const good = {
    schema_version: SCHEMA_VERSION,
    built_from: 'a'.repeat(40),
    renderer: 'canvaskit',
    conditions: {
      locale: 'ko-KR',
      profiles: {
        mobile: { cpu_throttle: 4, download_bps: 625000, upload_bps: 187500, latency_ms: 80 },
        desktop: { cpu_throttle: 1, download_bps: 3750000, upload_bps: 1250000, latency_ms: 20 },
      },
    },
    routes: [row],
  };
  assert.deepEqual(validateMeasureReport(good), []);
  assert.ok(validateMeasureReport({ ...good, routes: [{ ...row, phase: 'lukewarm' }] }).length > 0);
  assert.ok(validateMeasureReport({ ...good, renderer: 'skia' }).length > 0);
  assert.ok(validateMeasureReport({ ...good, conditions: { locale: 'ko-KR' } }).length > 0);
  assert.ok(validateMeasureReport({}).length > 0);
});

test('measureNavigation: 모든 Playwright 대기에 명시적 타임아웃이 있다', async () => {
  // CI 실측(run 35174425725): Slow 4G 프로파일에서 waitForLoadState('networkidle') 가
  // 기본 30s 로 만료돼 측정이 죽었다. 기본 타임아웃에 기대는 대기를 금지한다.
  const { readFile } = await import('node:fs/promises');
  const src = await readFile(new URL('./measure.mjs', import.meta.url), 'utf8');
  assert.doesNotMatch(src, /waitForLoadState\('networkidle'\)/);
  // 2차 CI 실측(run 35174425725 후속, 릴리스 PR #213): networkidle 은 120s 로도 안 온다 —
  // 차단된 외부 호스트로의 반복 요청 때문. 루프백 요청만 보는 quiet() 로 판정한다.
  assert.doesNotMatch(src, /waitForLoadState\('networkidle'/);
  assert.match(src, /await net\.quiet\(\{ idleMs: 1000, timeout: READY_TIMEOUT_MS \}\)/);
});
