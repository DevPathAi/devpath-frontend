# 성능 기준선과 예산(N04) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/login` `/dashboard` `/path` `/mentor` `/community` 의 cold/warm p75 Core Web Vitals(LCP·INP·CLS)와 초기 전송량을 mock 릴리스 빌드에서 측정해 기준선으로 저장하고, 기본(JS/CanvasKit) 빌드와 `--wasm` 빌드를 A/B 하며, CI 에서 LCP ≤ 2.5s · INP ≤ 200ms · CLS ≤ 0.1 및 초기 전송량 +5% 회귀를 게이트로 건다.

**Architecture:** N03 의 `tools/browser_ux/serve.mjs` 를 재사용하는 `tools/perf/measure.mjs`(Playwright + `web-vitals` 는 CDN 불가이므로 `PerformanceObserver` 로 직접 LCP/CLS 수집, INP 는 `event` 타이밍의 최대 `duration` 을 primary action 클릭으로 유도해 수집). 각 라우트를 cold(새 컨텍스트, 캐시 없음) 5회 · warm(같은 컨텍스트 재방문) 5회 측정해 p75 를 저장한다. 전송량은 CDP `Network` 이벤트의 `encodedDataLength` 합(라우트 첫 로드, 리소스 종류별 분리: JS/CanvasKit·wasm/폰트/이미지/기타). 기준선은 `perf/baseline.json`(커밋), 예산은 `perf/budget.json`(커밋). CI job `perf-gate` 가 현재 빌드를 측정해 예산·기준선 대비 판정한다.

**Tech Stack:** Playwright 1.55.0, Chromium headless(CPU 4× throttling + 'Fast 3G' 유사 네트워크 조건을 CDP `Network.emulateNetworkConditions`/`Emulation.setCPUThrottlingRate` 로 고정해 러너 간 편차를 줄임), Flutter `build web --release` / `build web --release --wasm`.

**Spec:** `task.md` §5 N04 · `handoff.md` §9.4(단일 warm 숫자 금지, cold/warm·mobile/desktop 분리, 자산 기여도 route 별 분리).

## Global Constraints

- 브랜치 `feat/perf-baseline-20260917`(N03 머지 후 분기). 커밋 Conventional Commits + Co-Authored-By.
- 측정 조건은 코드로 고정한다(뷰포트 mobile 390×844 DPR 3 / desktop 1440×900 DPR 1, CPU 4×, 다운 1.6Mbps·업 750kbps·RTT 150ms, locale ko-KR). 조건이 바뀌면 기준선을 새로 만든다(둘을 섞지 않는다).
- 회귀 판정: 초기 전송량(전체·JS+CanvasKit/wasm) 이 기준선 대비 +5% 초과 → fail. CWV 절대 임계 초과 → fail. 기준선 갱신은 PR 리뷰 승인 + `perf/baseline.json` 의 `built_from` SHA 기록으로만.
- 외부 네트워크 0(N03 러너와 같은 차단 규칙).

---

### Task 1: 측정기 `tools/perf/measure.mjs`

**Files:** `tools/perf/package.json`(N03 과 같은 playwright 고정), `tools/perf/measure.mjs`, `tools/perf/measure.test.mjs`(p75 계산·리포트 스키마 단위 테스트, `node --test`)

**Interfaces:**
- CLI: `node measure.mjs --dist=<build/web> --renderer=<canvaskit|wasm> --out=<json>`.
- 리포트 스키마 `leva.perf-measure.v1`: `{ built_from, renderer, conditions:{…}, routes:[{ route, profile:'mobile'|'desktop', phase:'cold'|'warm', samples:5, p75:{ lcp_ms, inp_ms, cls }, transfer_bytes:{ total, js, canvaskit_or_wasm, fonts, images, other } }] }`.
- INP 유도 행동: `/login` 'GitHub로 계속하기' 클릭, `/dashboard` '미션 열기', `/path` '미션 열기', `/mentor` 입력 후 '전송', `/community` 'Q/A' 세그먼트 클릭.
- 인증: `MOCK_PROFILE=onboarded` 빌드에서 `/login` 을 먼저 통과한 storageState 를 저장해 나머지 라우트에 재사용(cold 는 캐시만 비우고 세션은 유지: `context.clearCookies()` 대신 새 컨텍스트 + storageState).

- [ ] Step 1 `measure.test.mjs`: `p75([...])` 가 nearest-rank 로 계산되는지, 리포트가 스키마 필수 키를 모두 갖는지 → 실패 확인 → 구현 → 통과. 커밋 `feat(tools): add CWV and transfer-size measurer`.

---

### Task 2: 두 렌더러 빌드 + 첫 기준선

- [ ] `flutter build web --release --no-pub --dart-define=USE_MOCK=true --dart-define=MISSION_SPINE_ENABLED=true --dart-define=MOCK_PROFILE=onboarded --dart-define=HOME_BASE_URL=http://127.0.0.1:1 -o build/web-canvaskit` 와 `… --wasm -o build/web-wasm`(wasm 빌드 실패 시 원인을 기록하고 이 축은 보류 — 추측 금지).
- [ ] 두 산출물을 측정해 `perf/baseline.json`(canvaskit) 과 `perf/renderer-ab-2026-09-17.json`(둘 비교) 저장. 결과 표를 `docs/design/perf-baseline.md` 에 기록(라우트 × 프로파일 × 단계 × p75, 자산 기여도).
- [ ] 임계 초과 항목이 있으면 이 Task 에서 기준선을 낮추지 않고 별도 이슈/Task 로 원인을 분리한다(예: Monaco 는 `/sandbox` 전용 지연 로드인지, 폰트 preload 여부).
- [ ] 커밋 `perf: record first CWV and transfer baselines for mock release builds`.

---

### Task 3: 예산과 CI 게이트

**Files:** `perf/budget.json`(`{ lcp_ms_max: 2500, inp_ms_max: 200, cls_max: 0.1, transfer_regression_pct_max: 5 }`), `tools/perf/gate.mjs`(+`gate.test.mjs`), `.github/workflows/ci.yml` job `perf-gate`, `apps/web/test/app/ci_workflow_contract_test.dart` 확장

- [ ] `gate.mjs`: 현재 리포트 vs `perf/baseline.json` + `perf/budget.json` → 위반 목록 출력, exit 1. 단위 테스트로 +5% 경계(정확히 5.0% 는 통과, 5.01% 실패)와 절대 임계를 고정.
- [ ] CI job: 빌드(canvaskit) → 측정 → 게이트 → 리포트 아티팩트 업로드. wasm 축은 `workflow_dispatch` 입력으로만(시간 비용).
- [ ] 커밋 `ci: gate Core Web Vitals and transfer-size regressions`. PR → develop, 녹색 후 merge.
