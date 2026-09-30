import assert from 'node:assert/strict';
import { test } from 'node:test';

import { evaluate } from './gate.mjs';

const budget = { lcp_ms_max: 2500, ready_ms_max: 2500, inp_ms_max: 200, cls_max: 0.1, transfer_regression_pct_max: 5 };
const row = (overrides = {}) => ({
  route: '/dashboard',
  profile: 'mobile',
  phase: 'cold',
  samples: 5,
  p75: { fcp_ms: 800, ready_ms: 1500, lcp_ms: null, inp_ms: 80, cls: 0.02 },
  transfer_bytes: { total: 1000, js: 600, canvaskit_or_wasm: 300, fonts: 50, images: 0, other: 50 },
  ...overrides,
});
const report = (rows) => ({ schema_version: 'leva.perf-measure.v1', built_from: 'a'.repeat(40), renderer: 'canvaskit', conditions: {}, routes: rows });

test('gate: 예산 안이고 기준선 대비 +5.0% 까지는 통과한다', () => {
  const baseline = report([row()]);
  const current = report([row({ transfer_bytes: { total: 1050, js: 630, canvaskit_or_wasm: 300, fonts: 50, images: 0, other: 70 } })]);
  assert.deepEqual(evaluate(current, baseline, budget), []);
});

test('gate: +5.01% 전송량 회귀는 실패한다', () => {
  const baseline = report([row()]);
  const current = report([row({ transfer_bytes: { total: 1051, js: 600, canvaskit_or_wasm: 300, fonts: 50, images: 0, other: 101 } })]);
  const violations = evaluate(current, baseline, budget);
  assert.equal(violations.length, 1);
  assert.match(violations[0], /total/);
});

test('gate: 회귀 %가 넘어도 절대 증가가 transfer_regression_min_bytes 미만이면 통과한다', () => {
  // CI 실측(PR #217): warm 전송은 HTML+매니페스트 13 KB 뿐이라 스플래시 1.4 KB 가 +10.98% 로 잡혔다.
  // 퍼센트 게이트는 작은 총량에서 과민하므로 바이트 바닥을 함께 본다.
  const floored = { ...budget, transfer_regression_min_bytes: 4096 };
  const baseline = report([row({ phase: 'warm', transfer_bytes: { total: 13000, js: 0, canvaskit_or_wasm: 0, fonts: 0, images: 0, other: 13000 } })]);
  const small = report([row({ phase: 'warm', transfer_bytes: { total: 14500, js: 0, canvaskit_or_wasm: 0, fonts: 0, images: 0, other: 14500 } })]);
  assert.deepEqual(evaluate(small, baseline, floored), []);
  // 바닥을 넘는 증가는 여전히 실패한다(+40%, +5.2 KB).
  const large = report([row({ phase: 'warm', transfer_bytes: { total: 18200, js: 0, canvaskit_or_wasm: 0, fonts: 0, images: 0, other: 18200 } })]);
  assert.equal(evaluate(large, baseline, floored).length, 1);
  // 바닥이 없으면(기존 예산) 종전대로 퍼센트만 본다.
  assert.equal(evaluate(small, baseline, budget).length, 1);
});

test('gate: 절대 임계(INP·CLS·ready) 초과는 기준선과 무관하게 실패한다', () => {
  const baseline = report([row()]);
  const current = report([row({ p75: { fcp_ms: 800, ready_ms: 2600, lcp_ms: null, inp_ms: 250, cls: 0.2 } })]);
  const violations = evaluate(current, baseline, budget);
  assert.equal(violations.length, 3);
});

test('gate: lcp 가 있어도 ready 를 함께 판정한다', () => {
  // 옛 계약은 「lcp 가 있으면 lcp 를, 없으면 ready 를」였다. 그러면 페인트 후보가
  // 하나 생기는 순간 ready 검사가 죽는다 — 2026-09-17 의 부트 스플래시(c482b54)가
  // 정확히 그 일을 했다. 그 뒤 20행 전부 lcp 가 붙어(44~228 ms) 21.5초짜리 모바일
  // 첫 상호작용 시점이 절대 예산에 보이지 않게 됐다. 스플래시는 LCP 후보일 뿐
  // 화면이 쓸 수 있게 된 시점이 아니다 — 둘은 따로 봐야 한다.
  const baseline = report([row()]);
  const withLcp = report([row({ p75: { fcp_ms: 800, ready_ms: 3000, lcp_ms: 2000, inp_ms: 80, cls: 0.02 } })]);
  const violations = evaluate(withLcp, baseline, budget);
  assert.equal(violations.length, 1);
  assert.match(violations[0], /ready_ms 3000 > 2500/);

  // lcp 가 없을 때의 거동은 그대로다.
  const noLcp = report([row({ p75: { fcp_ms: 800, ready_ms: 3000, lcp_ms: null, inp_ms: 80, cls: 0.02 } })]);
  assert.match(evaluate(noLcp, baseline, budget)[0], /ready_ms 3000 > 2500/);

  // 둘 다 넘으면 둘 다 보고한다.
  const both = report([row({ p75: { fcp_ms: 800, ready_ms: 3000, lcp_ms: 2600, inp_ms: 80, cls: 0.02 } })]);
  const two = evaluate(both, baseline, budget);
  assert.equal(two.length, 2);
  assert.ok(two.some((v) => /lcp_ms/.test(v)));
  assert.ok(two.some((v) => /ready_ms/.test(v)));
});

test('gate: 기준선에 없는 행은 회귀 비교 없이 절대 임계만 본다', () => {
  const baseline = report([]);
  assert.deepEqual(evaluate(report([row()]), baseline, budget), []);
});

test('gate: enforce_absolute=false 면 절대 임계 초과는 경고로만 남고 회귀만 실패한다', () => {
  const soft = { ...budget, enforce_absolute: false };
  const baseline = report([row()]);
  const current = report([row({ p75: { fcp_ms: 800, ready_ms: 40000, lcp_ms: null, inp_ms: 800, cls: 0.5 }, transfer_bytes: { total: 1100, js: 600, canvaskit_or_wasm: 300, fonts: 50, images: 0, other: 150 } })]);
  const warnings = [];
  const violations = evaluate(current, baseline, soft, { warnings });
  assert.equal(warnings.length, 3);
  assert.equal(violations.length, 1);
  assert.match(violations[0], /total/);
});
