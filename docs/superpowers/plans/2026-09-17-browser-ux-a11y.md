# 브라우저 UX·접근성 자동화(N03) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 실제 Chromium(Playwright)에서 mock 릴리스 빌드를 상대로 deep link · 새로고침 · back/forward · focus 복귀 · 키보드 순회 · 200% 텍스트 · reduced-motion 을 390/768/1024/1440 폭에서 자동 검증하고, overflow 와 44px 터치 타깃, axe 접근성 위반을 게이트로 건다. 결과는 JSON 리포트 + CI 아티팩트.

**Architecture:** `tools/browser_ux/`(Node ESM, Playwright 1.55.0 + axe-core 4.10.3 — ET13 와 같은 버전 고정)에 정적 SPA 서버(`serve.mjs`)와 시나리오 러너(`run.mjs`)를 둔다. 앱은 `flutter build web --release --dart-define=USE_MOCK=true --dart-define=MISSION_SPINE_ENABLED=true --dart-define=MOCK_PROFILE=onboarded --dart-define=HOME_BASE_URL=http://127.0.0.1:<port>` 로 빌드해 백엔드·외부 네트워크 없이 돈다(실측: 기본 mock 유저는 `onboardingStatus=PENDING` 이라 모든 라우트가 `/diagnostic` 로 게이트됨 → `MOCK_PROFILE` 정의 추가). Flutter 시맨틱스는 `flt-semantics-placeholder` 클릭으로 활성화하고, 200% 텍스트는 `document.documentElement.style.fontSize='32px'`(실측: 16→32px 에서 콘텐츠 높이 2배)로, reduced-motion 은 Playwright `reducedMotion:'reduce'` 로 준다. 앱 쪽 접근성 결함 두 가지(페이지 헤더가 heading 역할이 아님, 커뮤니티 목록이 항목 수를 읽지 않음)는 dart 테스트 우선으로 고친다.

**Tech Stack:** Flutter 3.44.1 web(mock), Node 24, Playwright 1.55.0, axe-core 4.10.3, GitHub Actions(`ci.yml` 새 job `browser-ux`).

**Spec:** `task.md` §5 N03 · `handoff.md` §9.3 필수 case 7종.

## Global Constraints

- 브랜치 `feat/browser-ux-a11y-20260917`(develop 에서 분기, N02·N05 머지 후). 커밋 Conventional Commits + Co-Authored-By.
- 외부 네트워크 0: 러너는 `page.route('**', …)` 로 127.0.0.1 이외 요청을 실패 처리하고 발생 시 fail.
- 게이트 기준(러너 exit 1): 어떤 라우트·폭·배율에서든 `scrollWidth > innerWidth`; compact(390) 에서 role=button 의 bounding box 가 44×44 미만; axe critical/serious ≥ 1; 필수 시나리오 실패.
- 리포트 `evidence/browser-ux/latest.json` 은 커밋하지 않는다(`.gitignore` 추가). CI 아티팩트로 보존.
- 키보드 순회 기대 순서(커뮤니티, desktop): rail(자유게시판/Q/A/피드백) → 검색 → 게시판 세그먼트 → 목록 첫 항목 → FAB(글 작성). 실제 focus 순서는 Task 4 에서 첫 실행으로 실측해 기대값을 고정한다(추측 금지).

---

### Task 1: `MOCK_PROFILE` dart-define — 온보딩 완료 mock 유저

**Files:**
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart` (`POST /auth/refresh` user 블록, 150-165행)
- Test: `apps/web/test/data/web_mock_fixtures_profile_test.dart` (신규)

**Interfaces:**
- Produces: `const mockProfile = String.fromEnvironment('MOCK_PROFILE', defaultValue: 'pending');` `mockProfile == 'onboarded'` 면 `onboardingStatus: 'DONE'`, 그 외 `'PENDING'`. 함수 `Map<String, dynamic> mockAuthRefreshUser({String profile = mockProfile})` 를 노출해 테스트가 두 분기를 모두 검증한다.

- [ ] Step 1 실패 테스트:
```dart
import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('기본 mock 프로필은 온보딩 PENDING 이다', () {
    expect(mockAuthRefreshUser()['onboardingStatus'], 'PENDING');
  });
  test('MOCK_PROFILE=onboarded 는 온보딩 DONE 유저를 만든다', () {
    expect(mockAuthRefreshUser(profile: 'onboarded')['onboardingStatus'], 'DONE');
    expect(mockAuthRefreshUser(profile: 'onboarded')['consentStatus'], 'DONE');
  });
}
```
- [ ] Step 2 실패 확인(함수 미정의). Step 3 구현: 픽스처 맵의 `'user': { … }` 를 `'user': mockAuthRefreshUser()` 로 치환하고 함수·상수 추가. Step 4 `flutter test test/data` + 기존 mock 회귀 테스트(`mentor_access_mock_fixture_regression_1_test.dart` 등) PASS. Step 5 커밋 `feat(web): add MOCK_PROFILE dart-define for onboarded mock sessions`.

---

### Task 2: 페이지 헤더를 heading 시맨틱으로

**Files:**
- Modify: `packages/dp_design/lib/src/shell/dp_page_header.dart`(실제 경로는 `grep -rl "class DpPageHeader" packages/dp_design/lib` 로 확인)
- Test: `packages/dp_design/test/shell/dp_page_header_test.dart`(없으면 신규)

- [ ] Step 1 실패 테스트: `tester.ensureSemantics()` 후 `DpPageHeader(title: '커뮤니티')` 를 pump 하고 `tester.getSemantics(find.text('커뮤니티')).flagsCollection.isHeader` 가 true.
- [ ] Step 3 구현: 제목 `Text` 를 `Semantics(header: true, child: …)` 로 감싼다. Step 4 dp_design 전체 테스트 PASS. 커밋 `feat(dp_design): expose page header titles as headings`.

---

### Task 3: 커뮤니티 목록 항목 수·선택 게시판 읽기

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/community_home_page.dart`(목록 sliver 와 `_BoardFilterBar`)
- Test: `apps/web/test/features/community/community_information_architecture_test.dart`

- [ ] Step 1 실패 테스트: 로드된 목록에서 `find.bySemanticsLabel(RegExp(r'자유게시판 글 \d+개'))` 가 1개; 선택된 세그먼트의 시맨틱스가 `isSelected`.
- [ ] Step 3 구현: 목록 sliver 를 `Semantics(label: '${board.label} 글 ${items.length}개', container: true)` 로 감싸고 세그먼트 버튼에 `selected: isSelected` 시맨틱스(이미 있으면 유지). 커밋 `feat(web): announce community board selection and item counts`.

---

### Task 4: 러너 `tools/browser_ux/`

**Files:**
- Create: `tools/browser_ux/package.json`(`"playwright": "1.55.0", "axe-core": "4.10.3"`, `"type": "module"`), `package-lock.json`(`npm install --package-lock-only` 로 생성 후 `npm ci` 로 재현 확인)
- Create: `tools/browser_ux/serve.mjs` — 정적 SPA 서버(모든 미존재 경로 → `index.html`), `/updates/feed.json` → `{"items":[]}`. `export async function serve(dist)` → `{ base, close }`.
- Create: `tools/browser_ux/run.mjs` — 인자 `--dist=<build/web>` `--out=<json>`; 매트릭스 `widths=[390,768,1024,1440] × textScale=[100,200] × reducedMotion=[false,true]`(시나리오별로 필요한 축만); 시나리오:
  1. `deep-link-returns`: 새 컨텍스트에서 `/community?board=QNA` 진입 → `/login` 게이트 → 'GitHub로 계속하기' 클릭 → 최종 URL 이 `/community?board=QNA` 이고 H1 텍스트가 'Q/A'.
  2. `refresh-keeps-board`: `/community?board=FEEDBACK` 에서 `page.reload()` → URL·H1 유지.
  3. `back-forward-boards`: 자유게시판 → Q/A → 피드백 순으로 rail/세그먼트 클릭 후 `goBack()`×2, `goForward()`×1 → URL 과 H1 이 매 단계 일치.
  4. `keyboard-traversal`: `/community` 에서 Tab 을 12회 누르며 `document.activeElement` 의 aria-label/textContent 를 수집 → 기대 순서(첫 실행으로 실측해 `expectations.json` 에 고정)와 일치.
  5. `dialog-focus-return`: 글 상세에서 '신고' 메뉴 → 다이얼로그 열기 → Escape → activeElement 가 여는 버튼으로 복귀.
  6. `overflow-and-targets`: 라우트 `[/dashboard,/path,/community,/community?board=QNA,/community?board=FEEDBACK,/mentor,/sandbox,/content/future-async-await]` × 4폭 × textScale 100/200 에서 `scrollWidth<=innerWidth`; 390 폭에서 모든 `role=button` box ≥ 44×44(`getByRole('button')` boundingBox).
  7. `reduced-motion-parity`: `reducedMotion:'reduce'` 와 아님에서 같은 라우트의 `innerText` 집합이 동일(정보 손실 없음).
  8. `axe`: 각 라우트 × (390 light, 1240 dark) 에서 axe `wcag2a,wcag2aa,wcag21a,wcag21aa,best-practice` — critical/serious 0.
  - 시맨틱스 활성화 헬퍼 `enableSemantics(page)`: `flt-semantics-placeholder` attached 대기 후 `dispatchEvent('click')`, 이후 `getByRole('button')` 개수 ≥ 1 확인.
  - 200%: `page.addInitScript` 로 DOMContentLoaded 시 `document.documentElement.style.fontSize='32px'`.
  - 리포트: `{ schema_version:'leva.browser-ux.v1', built_from: <git sha>, scenarios:[{id, width, text_scale, reduced_motion, status, details}], summary:{passed, failed} }`. 실패 시 exit 1.
- Create: `tools/browser_ux/expectations.json`(키보드 순서 등 실측 고정값)
- Test: `tools/browser_ux/run.test.mjs`(`node --test`): `serve.mjs` 가 SPA fallback 과 feed stub 을 돌려주는지, 리포트 스키마 검증 함수 단위 테스트.

- [ ] Step 1 `run.test.mjs` 작성 → 실패. Step 3 구현. Step 4 로컬 실행:
```bash
cd <worktree>/apps/web && flutter build web --release --no-pub --dart-define=USE_MOCK=true --dart-define=MISSION_SPINE_ENABLED=true --dart-define=MOCK_PROFILE=onboarded --dart-define=HOME_BASE_URL=http://127.0.0.1:1
cd <worktree>/tools/browser_ux && npm ci --ignore-scripts && npx playwright install chromium && node run.mjs --dist=../../apps/web/build/web --out=../../evidence/browser-ux/latest.json
```
  첫 실행 결과로 `expectations.json` 을 고정하고, 발견된 실패(overflow/타깃/axe)는 별도 Task 로 앱을 고친다(러너 기준을 낮추지 않는다).
- [ ] 커밋 `feat(tools): add browser UX and accessibility runner`.

---

### Task 5: CI job `browser-ux`

**Files:** `.github/workflows/ci.yml`, `.gitignore`(`evidence/browser-ux/`), `apps/web/test/app/ci_workflow_contract_test.dart`(있으면 확장; 없으면 신규로 `ci.yml` 에 `browser-ux` job 과 고정 버전 문자열이 있는지 소스 계약 테스트)

- [ ] job: `analyze-test` 와 같은 checkout/flutter-action/bootstrap 단계 → `flutter build web --release --no-pub --dart-define=…`(위와 동일) → `actions/setup-node@<pinned sha>` node 24 → `npm ci --prefix tools/browser_ux --ignore-scripts` → `npx --prefix tools/browser_ux playwright install --with-deps chromium` → `node tools/browser_ux/run.mjs …` → `actions/upload-artifact@<pinned sha>` 로 `evidence/browser-ux/latest.json` 과 실패 스크린샷 업로드. 워크플로의 기존 action SHA 핀을 그대로 재사용한다(새 action 은 `gh api repos/<owner>/<repo>/git/ref/tags/<tag>` 로 SHA 를 확인해 핀).
- [ ] 커밋 `ci: run browser UX and accessibility gate on pull requests`. PR → develop, CI(새 job 포함) 녹색 후 merge.

---

### Task 6: 문서

- [ ] `docs/design/browser-ux-contract.md`: 시나리오 표, 게이트 기준, 로컬 실행법, 기대값 갱신 규칙(실측 후 PR 리뷰에서 승인). 커밋 `docs: describe the browser UX and accessibility contract`.
