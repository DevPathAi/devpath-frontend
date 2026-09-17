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

test('gate: 절대 임계(INP·CLS·ready) 초과는 기준선과 무관하게 실패한다', () => {
  const baseline = report([row()]);
  const current = report([row({ p75: { fcp_ms: 800, ready_ms: 2600, lcp_ms: null, inp_ms: 250, cls: 0.2 } })]);
  const violations = evaluate(current, baseline, budget);
  assert.equal(violations.length, 3);
});

test('gate: lcp 가 있으면 lcp 를, 없으면 ready 를 판정한다', () => {
  const baseline = report([row()]);
  const withLcp = report([row({ p75: { fcp_ms: 800, ready_ms: 3000, lcp_ms: 2000, inp_ms: 80, cls: 0.02 } })]);
  assert.deepEqual(evaluate(withLcp, baseline, budget), []);
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
