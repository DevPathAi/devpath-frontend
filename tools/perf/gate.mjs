// 성능 게이트(N04). 현재 측정 리포트를 예산(perf/budget.json)과 기준선(perf/baseline.json)에
// 대조해 위반 목록을 돌려준다. 위반이 하나라도 있으면 exit 1.
//
// 사용: node gate.mjs --report=<measure.json> --baseline=<baseline.json> --budget=<budget.json>
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const key = (row) => `${row.route}|${row.profile}|${row.phase}`;

function pct(current, base) {
  if (!base) return current ? Infinity : 0;
  return ((current - base) / base) * 100;
}

/** 위반 문자열 목록. 비어 있으면 통과. */
export function evaluate(current, baseline, budget, { warnings = [] } = {}) {
  const violations = [];
  // 절대 예산은 budget.enforce_absolute 가 true 일 때만 실패다. 첫 기준선이 예산 밖이면
  // (실측: cold 22MB, 모바일 FCP 수십 초) 경고로 기록하고 회귀 게이트만 강제한다.
  const absolute = budget.enforce_absolute === false ? warnings : violations;
  const baseRows = new Map((baseline?.routes ?? []).map((row) => [key(row), row]));
  for (const row of current.routes ?? []) {
    const id = key(row);
    const { p75, transfer_bytes: bytes } = row;
    // 절대 임계: LCP 가 있으면 LCP, 없으면 ready(첫 상호작용 가능 시점).
    if (p75.lcp_ms !== null && p75.lcp_ms !== undefined) {
      if (p75.lcp_ms > budget.lcp_ms_max) absolute.push(`${id} lcp_ms ${p75.lcp_ms} > ${budget.lcp_ms_max}`);
    } else if (p75.ready_ms !== null && p75.ready_ms !== undefined && p75.ready_ms > budget.ready_ms_max) {
      absolute.push(`${id} ready_ms ${p75.ready_ms} > ${budget.ready_ms_max}`);
    }
    if (p75.inp_ms !== null && p75.inp_ms !== undefined && p75.inp_ms > budget.inp_ms_max) {
      absolute.push(`${id} inp_ms ${p75.inp_ms} > ${budget.inp_ms_max}`);
    }
    if (p75.cls !== null && p75.cls !== undefined && p75.cls > budget.cls_max) {
      absolute.push(`${id} cls ${p75.cls} > ${budget.cls_max}`);
    }
    // 전송량 회귀: 기준선의 같은 행 대비 total 과 js+canvaskit/wasm.
    const base = baseRows.get(id);
    if (!base) continue;
    const limit = budget.transfer_regression_pct_max;
    // 퍼센트만 보면 warm(13 KB) 같은 작은 총량에서 1 KB 변화도 회귀로 잡힌다(PR #217 실측).
    // 바닥(transfer_regression_min_bytes) 이하의 절대 증가는 회귀로 보지 않는다.
    const floor = budget.transfer_regression_min_bytes ?? 0;
    const totalPct = pct(bytes.total, base.transfer_bytes.total);
    if (totalPct > limit && bytes.total - base.transfer_bytes.total > floor) {
      violations.push(`${id} transfer total +${totalPct.toFixed(2)}% > ${limit}%`);
    }
    const codeNow = bytes.js + bytes.canvaskit_or_wasm;
    const codeBase = base.transfer_bytes.js + base.transfer_bytes.canvaskit_or_wasm;
    const codePct = pct(codeNow, codeBase);
    if (codePct > limit && codeNow - codeBase > floor) {
      violations.push(`${id} transfer js+renderer +${codePct.toFixed(2)}% > ${limit}%`);
    }
  }
  return violations;
}

function parseArgs(argv) {
  const options = {};
  for (const arg of argv) {
    const match = /^--([a-z-]+)=(.*)$/.exec(arg);
    if (match) options[match[1]] = match[2];
  }
  if (!options.report || !options.baseline || !options.budget) {
    throw new Error('usage: node gate.mjs --report=<measure.json> --baseline=<baseline.json> --budget=<budget.json>');
  }
  return options;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const options = parseArgs(process.argv.slice(2));
  const load = async (path) => JSON.parse(await readFile(resolve(path), 'utf8'));
  const [report, baseline, budget] = await Promise.all([load(options.report), load(options.baseline), load(options.budget)]);
  const warnings = [];
  const violations = evaluate(report, baseline, budget, { warnings });
  for (const warning of warnings) console.warn(`[perf-gate] warning (absolute budget not enforced): ${warning}`);
  for (const violation of violations) console.error(`[perf-gate] ${violation}`);
  console.log(`perf-gate: ${violations.length ? 'FAIL' : 'PASS'} (${report.routes.length} rows, renderer=${report.renderer})`);
  process.exit(violations.length ? 1 : 0);
}
