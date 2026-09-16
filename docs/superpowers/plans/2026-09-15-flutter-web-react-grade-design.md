# Flutter Web React급 디자인·구성 고도화 계획

> 대상: `app.leva.ai.kr` Flutter Web 앱과 `packages/dp_design`
>
> 기준 브랜치: `feat/mobile-first-redesign` (`2bea7f5`)
>
> 작성일: 2026-09-15
>
> 분류: APP UI

## 1. 결론과 성공 기준

React로 재작성하지 않는다. 현재 품질 차이는 프레임워크가 아니라 운영 배포 버전, 화면별 정보
계층, 브라우저 상호작용, 초기 로드 비용, 회귀 게이트의 차이다. Flutter 3.44.1과 기존
`dp_design`으로 같은 수준의 시각 완성도와 제품 구성을 만들고, 공개·검색용 콘텐츠는 현재처럼
`leva.ai.kr`의 문서 중심 랜딩이 담당한다.

완료 기준은 다음과 같다.

1. 로그인 이후 핵심 동선이 `진단 → 학습 경로 → 오늘 → 콘텐츠/실습/멘토 → 커뮤니티`로 즉시 읽힌다.
2. 320·600·840·1240 경계와 390·768·1024·1440 실사용 폭에서 레이아웃이 의도적으로 바뀐다.
3. 모든 핵심 화면이 loading·empty·error·success·partial 상태를 사용자에게 설명하고 복구 행동을 준다.
4. 키보드, 스크린리더, 200% 텍스트, 라이트/다크, reduced-motion 계약을 자동 검증한다.
5. 운영 p75 기준 LCP ≤2.5초, INP ≤200ms, CLS ≤0.1을 모바일·데스크톱에서 각각 만족한다.
6. 디자인 토큰, 공용 컴포넌트, 시각 캡처, 성능 예산이 CI에서 회귀를 막는다.

## 2. 프레임워크 검토

| React에서 기대하는 품질 | Flutter Web에서의 구현 수단 | Leva 적용 |
|---|---|---|
| 일관된 컴포넌트 시스템 | `ThemeExtension` + typed token + 공용 widget | `DpTheme`, `DpColors`, `AppTokens`, `dp_design`을 SSoT로 유지 |
| 반응형 레이아웃 | constraint 기반 layout + window class | `DpWindowClass`와 `LayoutBuilder`로 4단계 전환 |
| 빠른 화면 조합 | 작은 presentation primitive | shell, header, list row, state scaffold, mission primitive만 조합 |
| URL·브라우저 동작 | `go_router`, `Shortcuts/Actions`, focus, selection | deep link, 뒤로가기, 명령 팔레트, 텍스트 선택을 화면 계약으로 고정 |
| 접근 가능한 의미 구조 | Flutter semantics + 실제 브라우저 접근성 트리 | ET13 의미 캡처와 키보드 순회로 이중 검증 |
| 빠른 초기 표시 | deferred import, lazy build, renderer A/B, 캐시 | 로그인 전 비필수 초기화와 무거운 기능을 지연하고 실측으로 renderer 선택 |
| SEO·문서 흐름 | Flutter 밖 문서형 surface | 앱은 `noindex`, 랜딩·검색 콘텐츠는 `leva.ai.kr` 유지 |

Flutter가 APP UI 품질을 막지는 않는다. 다만 DOM 중심 앱보다 브라우저 의미 트리와 초기 다운로드를
더 의식적으로 관리해야 한다. 따라서 픽셀 완성도만 보지 않고 의미 구조와 로드 성능을 같은 게이트로
다룬다.

## 3. 현재 상태

### 이미 있는 것

- `DESIGN.md`: indigo·slate 색, Pretendard/D2Coding, 8pt 간격, 4단계 window class, 접근성 계약.
- `packages/dp_design`: `DpAppShell`, `DpNavRail`, `DpChromeBar`, `DpMobileNavigation`,
  `DpPageHeader`, `DpStateScaffold`, `DpListRow`, mission primitive.
- `af1995c`: Leva v2 공통 디자인 시스템과 모바일 우선 셸/로그인 전면 재구성.
- `7d247d8`: 진단 시작을 단계·소요시간·결과·선택 폼이 있는 온보딩 surface로 고도화.
- `2bea7f5`: `커뮤니티 → 자유게시판/Q/A/피드백`, 중복 브레드크럼 제거, 계정 메뉴 1단계 로그아웃.
- ET13: 320·600·840·1240, light/dark, visual/a11y 96개 케이스를 봉인하는 릴리스 증거 체계.
- 디자인 감사: 운영 C, 개선 브랜치 B+. 운영 초기 실측은 DOM ready 약 2.88초, load 약 3.81초.

### 측정된 성능 단서

- 현재 로컬 release 산출물 전체는 70,694,214 bytes다. 이는 초기 네트워크 전송량이 아니라
  서비스 워커와 기능별 자산을 모두 합한 크기다.
- 큰 자산은 `main.dart.js` 5,987,955 bytes, CanvasKit WASM 7,229,467 bytes,
  TypeScript worker 5,749,518 bytes, D2Coding 4,185,844 bytes 등이다.
- `apps/web/Dockerfile`은 기본 `flutter build web --release`만 사용한다. `--wasm` 선택은 아직
  비교 실측되지 않았다.
- `web/index.html`에는 광고와 Monaco 부트스트랩 경계가 있다. 로그인 첫 화면에서 실제로 필요한
  요청인지 네트워크 워터폴로 분리 측정해야 한다.

## 4. 정보 구조

### 전역 구조

```text
비로그인
  로그인
    ├─ 제품 가치 + 핵심 흐름 미리보기
    ├─ GitHub 로그인
    └─ 게스트 진단

로그인
  학습
    ├─ 오늘
    │   ├─ 다음 행동
    │   └─ 콘텐츠 / 실습 / AI 멘토
    ├─ 학습 경로
    └─ AI 멘토
  커뮤니티
    ├─ 전체
    ├─ 자유게시판
    ├─ Q/A
    └─ 피드백
  계정 메뉴
    ├─ 마이페이지
    ├─ 설정
    └─ 로그아웃
```

### 화면별 첫째·둘째·셋째 위계

| 화면 | 첫째 | 둘째 | 셋째 |
|---|---|---|---|
| 로그인 | Leva가 주는 결과 | 진단→경로→오늘 흐름 | GitHub 로그인/게스트 진단 행동 |
| 진단 시작 | `15문항 · 약 5분`과 기대 결과 | 트랙 선택 | `진단 시작하기` |
| 진단 문항 | 현재 문항·남은 수·진행률 | 질문과 선택지 | 저장 실패 복구 |
| 오늘 | 지금 해야 할 단일 행동 | 완료 조건·진행 | 이후 맥락/주차 |
| 학습 경로 | 현재 주차와 다음 추천 | 전체 주차 진행 | 보조 통계 |
| 커뮤니티 | 보드 필터와 글쓰기 | 글 목록 | 검색·메타 정보 |
| 계정 메뉴 | 로그아웃 포함 즉시 행동 | 마이페이지 | 설정 |

Large 화면에서 남는 공간은 장식 카드가 아니라 현재 맥락과 다음 추천을 담는 보조 열로 사용한다.
한 화면에서 강한 1차 행동은 하나만 둔다.

## 5. 상호작용 상태 계약

| 기능 | Loading | Empty | Error | Success | Partial |
|---|---|---|---|---|---|
| 로그인 | 버튼과 콜백 상태를 유지한 진행 표시 | 해당 없음 | 재시도 + 진단 우회 경로 | 원래 목적지 복귀 | OAuth 완료, 프로필 준비 중을 분리 표시 |
| 진단 | 단계명과 진행 표시 | 트랙 미선택 이유 + 선택 유도 | 현재 문항/선택 보존 + 같은 행동 재시도 | 결과·신뢰도·다음 행동 | 결과 저장 완료/경로 생성 중을 분리 |
| 오늘 | 미션 구조를 보존한 skeleton | 진단 또는 경로 생성 CTA | 마지막 유효 데이터 + 재시도 | 다음 행동 하나를 전면 배치 | 일부 서비스 실패는 가능한 행동만 활성 |
| 학습 경로 | 주차 spine skeleton | 진단 시작 CTA와 생성 결과 설명 | 기존 경로 보존 + 다시 확인 | 현재 주차·전체 진행·다음 추천 | 갱신 중에는 stale 시각·시간 표시 |
| 커뮤니티 | 목록 행 skeleton | 보드별 따뜻한 설명 + 첫 글/질문 CTA | 필터 유지 + 다시 불러오기 | 필터·목록·글쓰기 | 검색/필터 결과 일부만 갱신 중임을 표시 |
| 콘텐츠 | 본문 골격 유지 | 사용 가능한 콘텐츠로 이동 | 읽던 위치 보존 + 재시도 | 읽기와 완료 행동 | 오프라인/진행 저장 대기를 고지 |
| Sandbox | editor 유지 + 실행 진행 | 예제 선택 CTA | 코드는 유지하고 실행만 복구 | 로그·리뷰·다음 행동 | sandbox unavailable이면 읽기/편집 유지 |
| AI 멘토 | 대화와 입력을 유지한 응답 진행 | 시작 질문 제안 | 작성 문구 보존 + 다시 보내기 | 맥락 포함 응답 | 중단 응답 보존 + 이어 받기 |
| 로그아웃 | 메뉴 항목 비활성 + 짧은 진행 | 해당 없음 | 세션 유지 + 다시 시도 | `/login` 이동, 민감 로컬 상태 제거 | 서버 종료 성공/로컬 정리 실패를 남기지 않음 |

상태 UI는 `DpStateScaffold`와 전용 상태 primitive를 재사용한다. 화면별 임의 spinner, 빈 카드,
`오류가 발생했습니다` 단독 문구를 금지한다.

## 6. 사용자 여정과 감정 곡선

| 단계 | 사용자가 하는 일 | 목표 감정 | 화면이 제공할 것 |
|---|---|---|---|
| 1 | 로그인 또는 게스트 진단 선택 | 무엇을 얻는지 이해 | 결과 중심 카피와 두 개 이하의 분명한 시작 경로 |
| 2 | 트랙 선택 후 15문항 진행 | 비용이 예측 가능 | 소요시간, 남은 문항, 선택 보존 |
| 3 | 결과 확인·저장 | 진단을 신뢰 | 레벨, 신뢰도, 산출될 경로를 한 화면에 연결 |
| 4 | 오늘 미션 수행 | 다음 행동에 집중 | 하나의 primary action과 완료 조건 |
| 5 | 막힐 때 멘토·커뮤니티 사용 | 혼자가 아님 | 현재 학습 맥락 유지, 질문/글쓰기의 빠른 진입 |
| 6 | 반복 방문 | 진전이 누적됨 | 주차 진행과 완료 기록, 다음 추천의 연속성 |

- 첫 5초: 브랜드, 현재 위치, 다음 행동을 설명 없이 파악한다.
- 첫 5분: 진단 비용과 보상이 맞고, 실패해도 선택이 보존된다는 신뢰를 준다.
- 장기 사용: 오늘의 작은 행동이 학습 경로와 누적 성취로 연결되는 모습을 일관되게 보여 준다.

## 7. 시각 언어와 AI 슬롭 방지

분류는 APP UI다. 차분한 surface, 강한 제목, 적은 색, 최소 chrome을 유지한다.

- 색은 `DpColors`만 사용하고 `primary`는 채움, `primaryText*`는 텍스트로 역할을 고정한다.
- 카드가 상호작용 단위가 아니면 borderless section, divider, list row를 우선한다.
- 대시보드 카드 모자이크, 아이콘 원형 3열, 장식 gradient/blob, 동일한 큰 radius 반복을 금지한다.
- 제목은 기능과 행동을 말한다. `환영합니다`, `강력한 경험` 같은 범용 카피를 쓰지 않는다.
- 그림자는 menu/dialog/sheet에만 사용한다. 그림자를 모두 빼도 위계가 유지돼야 한다.
- section마다 한 가지 일만 두고, 설명 문구를 30% 지워도 의미가 유지되면 더 줄인다.

검수 질문은 모두 YES가 되어야 한다.

1. 첫 화면에서 Leva와 사용자의 다음 행동이 분명한가?
2. 화면마다 하나의 강한 시각 앵커가 있는가?
3. 제목만 훑어도 화면을 이해할 수 있는가?
4. 각 section이 한 가지 일만 하는가?
5. 남아 있는 카드가 실제 상호작용 단위인가?
6. 모션이 위계 또는 상태 이해를 개선하는가?
7. 장식 그림자를 모두 제거해도 완성도가 유지되는가?

## 8. 디자인 시스템 적용 규칙

| 문제 | 재사용할 구성요소 | 금지 |
|---|---|---|
| 앱 전체 골격 | `DpAppShell` | 화면별 `Scaffold.appBar` |
| 위치·검색·오류 신고 | `DpChromeBar` | 화면마다 별도 검색 입력 |
| 화면 제목·설명·행동 | `DpPageHeader` | 제목 2~3중 노출 |
| compact 목적지 | `DpMobileNavigation` | 기본 `NavigationBar` 직접 사용 |
| 목록·메타 | `DpListRow`, `DpTag` | 목적 없는 카드 wrapping |
| 로딩·빈·오류 | `DpStateScaffold` | 화면별 임의 상태 UI |
| 미션 맥락 | `DpMissionHeader`, `DpProgressSpine`, `DpNextActionBand` | feature가 의미/색을 재정의 |
| 읽기/선택 | `DpMaxWidth`, `DpSelectable`, `DpScrollbar` | 무제한 본문 폭 |

새 시각 primitive는 두 화면 이상에서 같은 의미로 반복되거나, 접근성·상태 계약을 중앙에서
강제해야 할 때만 `dp_design`에 추가한다. 그 외에는 feature 내부 조합으로 둔다.

## 9. 반응형·접근성

### 뷰포트 계약

| 폭 | 셸 | 콘텐츠 구성 | 검증 포인트 |
|---|---|---|---|
| <600 Compact | 64px chrome + 플로팅 하단 내비 | 한 가지 주행동, 보조 정보 접기 | 320/390, safe area, 44px target, 가로 overflow 0 |
| 600–839 Medium | 하단 내비 또는 접힌 rail | 1열 중심 + 짧은 보조 영역 | 600/768, rail 토글, 메뉴 anchoring |
| 840–1239 Expanded | 확장/접힘 rail | 주영역 + 필요할 때만 보조 열 | 840/1024, readable/max width 전환 |
| ≥1240 Large | rail + 넓은 workspace | 주영역 2/3 + 맥락 1/3 | 1240/1440, 오른쪽 빈 공간의 역할 |

Sandbox의 1024 경계는 기존 계약대로 별도 유지한다. 진단은 내부 가용 폭 600에서 1열/2열로
전환한다. 경계값 `-1 / exact / +1` 테스트를 둔다.

### 접근성 계약

- 본문/링크 대비 ≥4.5:1, 큰 글자·UI 경계 ≥3:1, 색과 텍스트 레이블 병행.
- 모든 pointer 행동은 키보드 Enter/Space와 가시 focus ring을 가진다.
- account menu는 열림→항목 순회→Esc 복귀, logout 실행 후 `/login` focus 시작점을 검증한다.
- 동적 목록은 실제 콘텐츠 수의 `semanticChildCount`를 제공한다.
- loading은 `aria-busy`, 오류는 live region, SSE는 `aria-live=polite` 의미로 노출한다.
- 200% 텍스트에서 잘림·겹침·수평 스크롤이 없어야 한다.
- reduced-motion에서는 shimmer, count-up, 위치 이동을 제거하고 정보는 즉시 표시한다.
- 읽어야 하는 긴 본문과 코드/로그는 선택 가능해야 한다.

## 10. 성능 계획

성능은 React와의 인상 차이를 가장 크게 만드는 브라우저 품질이다. 먼저 release/profile 빌드에서
실측하고, 변경 전후를 같은 장비·네트워크 조건에서 비교한다.

1. `/login`, `/diagnostic`, `/dashboard`, `/community`, `/sandbox`의 cold/warm 네트워크 워터폴,
   LCP·INP·CLS, main thread long task, 첫 interaction 가능 시점을 기록한다.
2. 기본 JS/CanvasKit 빌드와 `flutter build web --wasm` 빌드를 Chrome·Edge·Firefox·Safari에서
   A/B한다. 특정 renderer를 선호로 정하지 않고 p75와 호환성으로 선택한다.
3. 로그인 전 필요 없는 초기화, 광고, 업데이트 feed, Monaco/언어 worker를 route/consent 이후로 늦춘다.
4. path/community처럼 긴 목록은 lazy builder를 사용하고 불필요한 intrinsic layout과 전체 subtree
   rebuild를 DevTools timeline으로 찾는다.
5. Pretendard/D2Coding weight와 glyph 사용을 조사해 서브셋 또는 더 작은 파일을 적용한다. 한글 누락과
   layout shift가 없는 경우에만 채택한다.
6. immutable hash 자산은 장기 캐시, `index.html`·release marker는 재검증 캐시로 분리한다.
7. 초기 경로의 압축 전송량과 요청 수를 기준선으로 저장하고 5% 초과 회귀를 CI에서 막는다.

프레임 목표는 일반 transition과 scroll의 build+raster 합계 16ms 이하다. 성능 개선은 픽셀 또는
접근성 회귀와 교환하지 않는다.

## 11. 테스트·릴리스 게이트

모든 구현은 실패하는 테스트를 먼저 만든다.

### RED 테스트 순서

1. 화면 위계와 IA: destination/crumb/community label/logout menu의 정확한 순서와 단일 제목.
2. 상태: 표의 loading/empty/error/success/partial마다 보이는 문구, 보존되는 데이터, primary action.
3. 반응형: 599/600, 839/840, 1023/1024, 1239/1240과 320/390/768/1440 overflow.
4. 접근성: 의미 순서, selected 상태, live region, focus 복귀, 44px target, 200% text.
5. 브라우저: URL/deep link/back, tab 순회, menu/overlay, text selection, light/dark/reduced-motion.
6. 성능: release asset manifest, 초기 route 요청, renderer A/B 결과와 예산 회귀.

### 자동 게이트

```powershell
dart run melos run format
dart run melos run analyze
dart run melos run test
cd apps/web
flutter build web --release
```

- ET13 기존 96개 visual/a11y 케이스를 유지하고 로그인·진단·커뮤니티·계정 메뉴 fixture를 추가한다.
- canonical 경계(320/600/840/1240)와 실사용 smoke(390/768/1024/1440)를 둘 다 캡처한다.
- light/dark, ko-KR, DPR 1/2, text 100/200%, reduced-motion을 분리한다.
- 후보와 승인 baseline의 픽셀 diff는 사람 승인 없이 자동 갱신하지 않는다.
- staging에서 GitHub OAuth, logout, Today→Path→Content→Sandbox→Mentor→Community를 순회한 뒤
  운영 canary로 승격한다.

## 12. 단계별 실행

### Phase 0 — 현재 브랜치 마감 (P1)

- 완료: 진단 시작, 커뮤니티 명칭/순서, 중복 breadcrumb, 1단계 logout, 전체
  format/analyze/test/build, light/dark 브라우저 캡처 40장.
- 남음: PR CI 확인.
- 후속 출시 준비: staging 실제 계정 GitHub OAuth/logout 왕복 검증(Phase 4).
- 산출: `feat/mobile-first-redesign → develop` PR. 운영 직접 배포는 하지 않는다.

### Phase 1 — 핵심 동선의 정보 밀도 (P1)

- Today는 KPI 카드 나열보다 `다음 행동 → 완료 조건 → 진행` 순서로 압축한다.
- Path large는 현재 주차/다음 추천 보조 열을 추가하고, compact는 현재 주차를 먼저 보여 준다.
- Community는 검색·필터·글쓰기를 한 header 영역에 두고 board별 빈 상태를 만든다.
- Login→Diagnostic→Path handoff의 카피와 focus 위치를 하나의 여정으로 검증한다.

### Phase 2 — 상태·브라우저 상호작용 (P1)

- 상태 표의 누락 분기를 RED 테스트로 고정하고 `DpStateScaffold`로 통일한다.
- menu, dialog, command palette, editor overlay의 키보드/focus/뒤로가기 계약을 완성한다.
- deep link와 새로고침에서 잘못된 destination 선택 또는 빈 shell이 생기지 않게 한다.

### Phase 3 — 초기 로드·런타임 성능 (P1)

- 운영과 branch release의 cold/warm 기준선을 같은 프로파일로 수집한다.
- renderer A/B, 비필수 초기화 지연, route별 무거운 자산 지연, font 최적화를 각각 독립 변경으로 측정한다.
- Core Web Vitals와 초기 asset 예산을 CI/운영 관측에 연결한다.

### Phase 4 — 시각 회귀 확대와 출시 (P2)

- 신규 핵심 fixture와 390/768/1024/1440 smoke를 ET13에 추가한다.
- staging에서 라이트/다크, desktop/compact, OAuth/logout 전체 동선을 검증한다.
- 승인 baseline, canary, rollback digest가 묶인 기존 GitOps 릴리스 경로로만 운영 배포한다.

## 13. 구현 작업

- [ ] **T1 (P1, human: ~1일 / Codex: ~2h)** — Today/Path — 카드 나열을 다음 행동 중심 정보 구조로 재편
  - 근거: Information Architecture. large Path의 오른쪽 공간과 compact dashboard 스크롤 길이.
  - 파일: `apps/web/lib/src/features/dashboard/`, `apps/web/lib/src/features/path/`
  - 검증: 320/390/840/1240 위젯 테스트 + Today/Path ET13 visual/a11y.
- [ ] **T2 (P1, human: ~1일 / Codex: ~2h)** — 공용 상태 — 핵심 화면의 다섯 상태를 사용자 행동까지 고정
  - 근거: Interaction State Coverage. 화면별 임의 상태와 복구 불일치 위험.
  - 파일: `packages/dp_design/lib/src/states/`, `apps/web/lib/src/features/`
  - 검증: feature별 state matrix 테스트와 live-region 의미 테스트.
- [ ] **T3 (P1, human: ~2일 / Codex: ~4h)** — Web performance — release 기준선과 renderer/초기화 A/B 구축
  - 근거: 운영 load 3.81초와 70.7MB 전체 asset tree.
  - 파일: `apps/web/Dockerfile`, `apps/web/web/index.html`, `.github/workflows/`, 성능 측정 스크립트
  - 검증: cold/warm 보고서, p75 LCP/INP/CLS, 초기 전송량 5% 회귀 게이트.
- [ ] **T4 (P1, human: ~1일 / Codex: ~2h)** — Browser UX — 키보드·focus·URL·선택·overlay 계약 완성
  - 근거: Responsive & Accessibility. Canvas 기반 UI의 브라우저 의미 구조를 별도 보증해야 함.
  - 파일: `packages/dp_design/lib/src/interaction/`, `apps/web/lib/src/features/shell/`, feature tests
  - 검증: tab 순회, Esc 복귀, deep link/back, 200% text, NVDA/TalkBack/VoiceOver 증거.
- [ ] **T5 (P2, human: ~1일 / Codex: ~2h)** — ET13 — 핵심 동선 visual/a11y matrix 확장
  - 근거: Design System Alignment. 브랜치 B+를 반복 가능한 릴리스 기준으로 고정해야 함.
  - 파일: `evidence/et13/`, `.github/workflows/et13-evidence.yml`, evidence tests
  - 검증: 전체 case reconciliation, 승인 baseline, light/dark와 실사용 폭 캡처.

## 14. 범위 밖

- React 재작성: 현재 공용 디자인 시스템·상태·릴리스 증거를 잃고 같은 문제를 다시 풀게 된다.
- 공개 랜딩을 Flutter로 통합: 문서 흐름·SEO는 DOM 중심 `leva.ai.kr`이 더 적합하다.
- backend API/DB 변경: 화면 상태 계약에 필요한 API gap은 별도 backend 이슈로 분리한다.
- admin/mobile 전체 재설계: 공용 token 회귀는 검증하지만 이 계획의 화면 우선순위는 web 앱이다.
- 장식 중심 리브랜딩: 제품 행동과 정보 계층을 먼저 고정한다.

## 15. 설계 검토 점수

검토 중 고정한 결정은 다섯 가지다.

1. Flutter Web SPA와 `dp_design`을 유지하고 React 재작성은 하지 않는다.
2. 문서·검색 중심 랜딩은 Flutter 앱과 분리한다.
3. 공통 4단계 window class와 Sandbox의 1024 기능 경계를 함께 유지한다.
4. CanvasKit/Skwasm 선택은 취향이 아니라 동일 조건 A/B 결과로 정한다.
5. 위젯 테스트, ET13 visual/a11y, 실제 브라우저 성능을 모두 출시 게이트로 둔다.

`TODOS.md`에는 새 항목을 추가하지 않는다. 발견된 작업을 후속 부채로 미루지 않고 이 계획의
Phase 1~4와 T1~T5에 모두 포함했다.

| 검토 차원 | 검토 전 | 계획 반영 후 | 남은 실행 리스크 |
|---|---:|---:|---|
| 정보 구조 | 8/10 | 9/10 | Today/Path 실제 구현·캡처 |
| 상호작용 상태 | 7/10 | 9/10 | feature별 상태 테스트 |
| 사용자 여정 | 7/10 | 9/10 | staging 전체 동선 |
| AI 슬롭 방지 | 8/10 | 9/10 | 실제 화면 시각 검수 |
| 디자인 시스템 | 9/10 | 10/10 | 새 primitive 심사 준수 |
| 반응형·접근성 | 8/10 | 9/10 | 실제 보조기기 증거 |
| 미결정 사항 | 5개 | 0개 | 구현 결과에 따른 수치 조정만 허용 |

초기 계획 완성도는 6/10, 이 문서 반영 후 9/10이다. 미결정 사항은 없다. 성능 renderer와
font 방식은 취향 결정이 아니라 Phase 3의 A/B 결과로 선택한다.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|---|---|---|---:|---|---|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | 이번 계획은 제품 방향을 바꾸지 않음 |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | 미실행 |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 0 | REQUIRED | Phase 3 renderer·성능 게이트 구현 전 필요 |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN | 6/10 → 9/10, 설계 결정 5개 고정 |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | 미실행 |

**VERDICT:** DESIGN CLEARED. 구현 전 Eng Review가 필요하다.

NO UNRESOLVED DECISIONS
