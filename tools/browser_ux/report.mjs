// 브라우저 UX 리포트 스키마(leva.browser-ux.v1)와 요약.
export const SCHEMA_VERSION = 'leva.browser-ux.v1';
const STATUSES = new Set(['passed', 'failed', 'skipped']);

export function summarize(scenarios) {
  let passed = 0;
  let failed = 0;
  for (const scenario of scenarios) {
    if (scenario.status === 'passed') passed += 1;
    else if (scenario.status === 'failed') failed += 1;
  }
  return { passed, failed };
}

/** 위반 목록을 돌려준다. 비어 있으면 유효하다. */
export function validateReport(report) {
  const problems = [];
  if (!report || typeof report !== 'object') return ['report must be an object'];
  if (report.schema_version !== SCHEMA_VERSION) problems.push('schema_version must be ' + SCHEMA_VERSION);
  if (!/^[0-9a-f]{40}$/.test(String(report.built_from ?? ''))) problems.push('built_from must be a 40-char git sha');
  if (!Array.isArray(report.scenarios)) {
    problems.push('scenarios must be an array');
  } else {
    report.scenarios.forEach((scenario, index) => {
      for (const key of ['id', 'width', 'text_scale', 'reduced_motion', 'status', 'details']) {
        if (!(key in scenario)) problems.push(`scenarios[${index}] missing ${key}`);
      }
      if (!STATUSES.has(scenario.status)) problems.push(`scenarios[${index}] has invalid status ${scenario.status}`);
    });
    const expected = summarize(report.scenarios);
    if (!report.summary || report.summary.passed !== expected.passed || report.summary.failed !== expected.failed) {
      problems.push('summary does not match scenarios');
    }
  }
  return problems;
}
