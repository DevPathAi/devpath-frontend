# UI/UX Phase 5 — 학습 여정(mentor 채팅 UX) 고도화 (설계)

> 상위 로드맵: [`2026-07-30-web-admin-uiux-elevation-roadmap-design.md`](./2026-07-30-web-admin-uiux-elevation-roadmap-design.md) §5 Phase 5 (로드맵 마지막).
> 선행: Phase 0·1·2·3·4 develop 머지 완료(PR#86·#87·#90·#91·#92).
> 대상: `apps/web`(학습자 웹앱, Flutter Web). 작성일 2026-07-31 · 브랜치 `feat/uiux-phase5-mentor-scroll`.

---

## 1. 배경 · 로드맵 전제 재검토

### 1.1 로드맵 전제와 실제의 불일치 (실측)
로드맵 §5 Phase 5는 "학습 여정(진단·콘텐츠·멘토)에 **CustomScrollView/SliverList 전환·긴 목록 지연 생성·DpListRow 재사용**"을 목표로 했으나, 세 화면을 실측한 결과 전제가 맞지 않는다:

- **diagnostic**(`diagnostic_page.dart`): 문항을 **단건**씩 표시(`Center`+`ConstrainedBox(560)`+`switch`). 목록이 아니고 SSE도 아님(REST). SliverList·DpListRow 적용처 없음.
- **content**(`content_page.dart`): **단일 마크다운 문서**(`SingleChildScrollView`+`ConstrainedBox(840)`+`DpMarkdown`). 목록이 아님. 스크롤 진행률 추적(`ContentProgressTracker`)이 `ScrollController.position`에 의존해 **SliverList 전환 시 회귀 리스크만 큼**(이득 없음).
- **mentor**(`mentor_page.dart`): 채팅 메시지를 **이미 `ListView.builder`(지연 생성)** 로 렌더하고, 스트리밍 최적화(`ValueKey`·`isStreamingTail`)·SSE 상태전환(streaming/partial/failed/killSwitch)·참고자료·Composer가 완비돼 있음.

→ **"긴 목록 SliverList·DpListRow 재사용"은 적용할 목록형 화면이 없다**(Phase 2 시계열 부재·Phase 3 본문 부재와 같은 전제 불일치). content/diagnostic은 **이미 로드맵 목표(지연 생성·매끄러운 상태)를 충족**하거나 전환 이득이 없다.

### 1.2 실질 개선 지점
mentor 채팅의 `ListView.builder`에 **`ScrollController`가 없어 자동 스크롤이 없다** — 새 메시지·스트리밍 토큰이 쌓여도 뷰가 하단으로 따라가지 않아 답변이 화면 밖에서 생성된다. 이것이 유일한 실질 개선 지점이다.

### 1.3 목표
- mentor 채팅에 **하단-근처 추종 자동 스크롤**을 추가해, 답변 스트리밍이 항상 보이도록 한다(사용자가 위로 스크롤해 읽는 중이면 방해하지 않는다).

### 1.4 비목표 (YAGNI)
- **content·diagnostic 변경 없음**: 이미 목표 충족(단일 문서·단건), SliverList 전환은 회귀 리스크만.
- **DpListRow·SliverList 신규 적용 없음**: 목록형 화면 부재.
- 백엔드/`MentorController`/`MentorState`/SSE 소스 계약 변경 없음. `apps/mobile`·`apps/admin` 대상 아님.

---

## 2. 아키텍처

- **Layer 3만 변경**(`apps/web/.../mentor/presentation/mentor_page.dart`). dp_design 신규 컴포넌트 없음(자동 스크롤은 화면 특화 상호작용).
- `MentorController`/`MentorState`/`mentor_sse_source`는 불변.

## 3. 구현

- `_MentorPageState`에 `ScrollController`(`_scroll`)를 추가하고 `ListView.builder(controller: _scroll)`에 연결. `dispose`에서 해제.
- `build`에서 `ref.listen(mentorControllerProvider, (prev, next) {...})`로 **메시지 수 증가 또는 스트리밍 토큰 갱신**(마지막 메시지 텍스트 변화)을 감지:
  - 감지 시 `WidgetsBinding.instance.addPostFrameCallback`으로 하단 이동(`_scroll.jumpTo(_scroll.position.maxScrollExtent)`).
- **하단-근처 추종(방해 금지)**: 스크롤 직전 `maxScrollExtent - pixels <= _kFollowThreshold`(예: 120px)일 때만 따라간다. 사용자가 위로 스크롤해 읽는 중이면 자동 스크롤을 억제한다.
- `hasClients` 가드로 레이아웃 전 접근을 방지. 스트리밍 최적화·SSE 상태·참고자료·Composer·killSwitch 분기는 **그대로 유지**.

## 4. 테스트 (TDD, Test-First — 절대 조건 2)

- **하단 근처에서 새 메시지 추가 → 자동으로 하단까지 스크롤**: 메시지를 채워 스크롤이 생기게 한 뒤, 하단 근처 상태에서 컨트롤러가 새 메시지를 push하면 `_scroll.position.pixels ≈ maxScrollExtent`(허용 오차 내).
- **사용자가 위로 스크롤한 상태 → 새 메시지가 와도 자동 스크롤 억제**: `_scroll`을 상단으로 이동 후 새 메시지 push → offset이 유지된다(하단으로 점프하지 않음).
- **기존 mentor 회귀 유지**: 버블 렌더·스트리밍 꼬리·partial/failed 배너·references 칩·composer 전송.
- **게이트**: `melos run analyze`(0 issues)·`melos run test`(전 패키지 pass)·`melos run format`(clean).

---

## 5. 수용 기준 (AC)

- [ ] mentor `ListView.builder`에 `ScrollController`가 연결되고 `dispose`된다.
- [ ] 하단 근처에서 새 메시지·스트리밍 토큰 시 뷰가 하단으로 따라간다.
- [ ] 사용자가 위로 스크롤 중이면 자동 스크롤이 억제된다.
- [ ] 기존 mentor 스트리밍·상태·references·composer 동작·테스트가 유지된다.
- [ ] content·diagnostic은 변경되지 않는다(전환 이득 없음·회귀 리스크 근거 기록).
- [ ] `MentorController`/`MentorState`/SSE 계약 불변.
- [ ] `melos analyze`·`test`·`format` green.

---

## 6. 구현 분해 지점 (→ writing-plans)

1. **mentor 자동 스크롤**(ScrollController + 하단-근처 추종) + 테스트 — 단일 Task(소규모).

> 이 Phase로 UI/UX 고도화 로드맵(Phase 0~5)이 완결된다.
