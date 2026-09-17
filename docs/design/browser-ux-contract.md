# 브라우저 UX·접근성 계약 (apps/web)

> N03(2026-09-17). 실제 Chromium(Playwright 1.55.0, axe-core 4.10.3)에서 mock 릴리스 빌드를 상대로 브라우저 UX 와 접근성을 자동 검증한다. 러너: `tools/browser_ux/run.mjs`, CI job: `browser-ux`(`.github/workflows/ci.yml`).

## 실행 조건

- 빌드: `flutter build web --release --no-pub --no-web-resources-cdn --dart-define=USE_MOCK=true --dart-define=MISSION_SPINE_ENABLED=true --dart-define=MOCK_PROFILE=onboarded --dart-define=HOME_BASE_URL=http://127.0.0.1:1`
  - `MOCK_PROFILE=onboarded`: 기본 mock 유저는 온보딩 `PENDING` 이라 모든 라우트가 `/diagnostic` 로 게이트된다. 온보딩 완료 유저로 `/dashboard` 이후 화면에 도달한다.
  - `--no-web-resources-cdn`: CanvasKit 을 로컬 자산으로 묶는다. 없으면 gstatic CDN 동적 import 가 외부 차단에 막혀 렌더가 멈춘다(ET13 와 같은 규칙).
- 서빙: `tools/browser_ux/serve.mjs` — 루프백 정적 서버, 미존재 경로는 `index.html`(딥링크·새로고침), `/updates/feed.json` 은 빈 stub.
- 네트워크: 루프백 이외 요청은 **차단하고 기록**한다(광고 스크립트·홈 피드·CanvasKit 폴백 폰트는 앱의 정상 동작이므로 실패 조건이 아니다). CI 는 `docker run --network none` 으로 한 번 더 격리한다.
- 시맨틱스: Flutter Web 접근성 트리는 `flt-semantics-placeholder` 를 클릭해 켠다. 200% 텍스트는 `document.documentElement.style.fontSize = '32px'`(실측: 콘텐츠 높이 2배). reduced-motion 은 Playwright `reducedMotion: 'reduce'`.

## 시나리오와 게이트

| id | 폭 × 배율 × 모션 | 검증 | 실패 조건 |
|---|---|---|---|
| `deep-link-returns` | 390, 1440 | `/community?board=QNA` 진입이 세션 부트스트랩을 지나 그대로 남고 H1 이 `Q/A` | 다른 경로 착지 · H1 불일치 |
| `refresh-keeps-board` | 768 | `/community?board=FEEDBACK` 새로고침 후 URL·H1 유지 | 불일치 |
| `back-forward-boards` | 1024 | 자유게시판→Q/A→피드백 뒤 back×2·forward×1 이 URL 과 H1 을 함께 되돌림 | 단계별 불일치 |
| `keyboard-traversal` | 1440 | `/community` 에서 Tab 순회 순서가 `expectations.json` 의 실측 고정값과 일치 | 순서 불일치 · 기대값 미기록 |
| `dialog-focus-return` | 1024 | 글 작성 버튼 Enter → 모달 시트(Dismiss barrier) 등장 → Escape 로 닫힘 → focus 가 여는 버튼으로 복귀 | 시트 없음 · 미닫힘 · focus 미복귀 |
| `overflow-and-targets` | 390/768/1024/1440 × 100/200% | 8개 라우트에서 `scrollWidth ≤ innerWidth`; 390·100% 에서 모든 `role=button` 이 44×44 이상 | overflow · 작은 타깃 |
| `reduced-motion-parity` | 768 | `/dashboard` `/community` `/path` 의 시맨틱 라벨 집합이 reduced-motion 에서도 동일 | 라벨 손실 |
| `axe` | 390 light · 1240 dark | 8개 라우트 axe(wcag2a/2aa/21a/21aa/best-practice) | critical/serious ≥ 1 |

리포트 스키마 `leva.browser-ux.v1`(`tools/browser_ux/report.mjs`): `{ schema_version, built_from, scenarios[{id,width,text_scale,reduced_motion,status,details}], summary{passed,failed} }`. 러너는 실패가 하나라도 있으면 exit 1. 리포트 파일(`evidence/browser-ux/latest.json`)은 커밋하지 않고 CI 아티팩트로 보존한다.

## 로컬 실행

```bash
cd apps/web && flutter build web --release --no-pub --no-web-resources-cdn \
  --dart-define=USE_MOCK=true --dart-define=MISSION_SPINE_ENABLED=true \
  --dart-define=MOCK_PROFILE=onboarded --dart-define=HOME_BASE_URL=http://127.0.0.1:1
cd ../../tools/browser_ux && npm ci --ignore-scripts && npx playwright install chromium
node --test run.test.mjs
node run.mjs --dist=../../apps/web/build/web --out=../../evidence/browser-ux/latest.json
```

## 기대값 갱신 규칙

`expectations.json`(키보드 순회 순서 등)은 러너 첫 실행의 실측값으로만 채우고, 바뀔 때는 PR 에서 변경 전후 순서를 나란히 적어 리뷰 승인 후 갱신한다. 러너 기준(overflow·44px·axe critical/serious)은 낮추지 않는다. 기준을 어기는 앱 결함은 앱을 고친다.

## 실측 발견 사항 (2026-09-17, 첫 실행 → 수정 후 17/17 통과)

| 발견 | 실측 | 조치 |
|---|---|---|
| 외부 차단 시 렌더 정지 | `--no-web-resources-cdn` 없이는 CanvasKit 이 gstatic 에서 동적 import | 빌드 플래그 채택(ET13 와 동일) |
| axe `meta-viewport`(critical) 8개 라우트 전부 | Flutter full-page 임베딩이 `user-scalable=no` 를 주입 | 부트스트랩을 전 라우트 커스텀 호스트 임베딩으로 전환 |
| axe `aria-prohibited-attr`(serious) | role 없는 `flt-semantics` 에 aria-label(`DpLoading`) | `SemanticsRole.status`/`alert`(liveRegion 플래그와 병용 불가) |
| 390px 작은 타깃: 세그먼트 85×32, `실습` 78×36 | 데스크톱 기본 `VisualDensity.compact` + SegmentedButton 이 minimumSize 미전달 | 테마 표준 밀도, 세그먼트 padding·padded 탭 타깃 |
| 목록 행마다 Tab 정지 2회 | `FocusableActionDetector` + `InkWell` 각각 포커스 노드 | InkWell `canRequestFocus:false`, `ActivateIntent` 로 Enter/Space |
| 시트가 role=dialog 를 내지 않음 | Flutter 모달 시트는 modal barrier 를 'Dismiss' 버튼으로 노출 | 러너 판정을 Dismiss 버튼 기준으로(앱 변경 없음) |
| 순회에 셸 레일이 없음 | 라우트 `FocusScope` 경계 — 페이지 스코프 안만 순회, 레일은 Shift+Tab/스코프 이탈 뒤 도달 | 셸에 `WidgetOrderTraversalPolicy` 고정(스코프 안 순서는 위젯 순), 기대값은 실측 순서(검색 → 게시판 3 → 글 작성 → 행 3)로 고정. 레일 우선 순회는 후속 과제 |
| 스크롤 컨테이너가 Tab 정지로 잡히며 전체 텍스트를 라벨로 노출 | Flutter Web 엔진 동작 | 미해결·기록만. 기대값은 첫 8 정지까지 |
| 광고 스크립트·홈 피드·Roboto 폴백 폰트 외부 요청 | 앱의 정상 동작 | 차단하고 리포트 `details.external` 에 기록(실패 아님) |
