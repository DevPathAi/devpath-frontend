# UI/UX Phase 3 — 커뮤니티 피드 고도화 (설계)

> 상위 로드맵: [`2026-07-30-web-admin-uiux-elevation-roadmap-design.md`](./2026-07-30-web-admin-uiux-elevation-roadmap-design.md) §5 Phase 3.
> 선행: Phase 0(토큰/인터랙션)·Phase 1(앱 셸)·Phase 2(대시보드) develop 머지 완료(PR#86·#87·#90).
> 대상: `apps/web`(학습자 웹앱, Flutter Web). 작성일 2026-07-31 · 브랜치 `feat/uiux-phase3-community-feed`.
> **정렬 필수**: 하위 B(자유/피드백 웹, PR#89)가 구현한 커뮤니티 피드를 **고도화**한다. 중복 구현 금지.

---

## 1. 배경 · 목표 · 비목표

### 1.1 배경 (실측)
- `apps/web/.../community/presentation/community_home_page.dart`가 이미 통합 피드를 구현: `_BoardFilterBar`(ChoiceChip 4개)·`_PostCard`(Card+ListTile)·`_BoardBadge`(Container)·`ListView.separated`·광고 슬롯(`COMMUNITY_FEED`, 5번째 뒤)·FAB 스피드다이얼(질문/자유글/피드백).
- 데이터 계약: `GET /community/posts` → `List<CommunityPostSummary>`(**bare 배열, 페이지네이션 없음**). `CommunityPostSummary` 필드: `id:int` · `title:String` · `boardType:String`(QNA/FREE/FEEDBACK) · `authorId:int?` · `solved:bool`(QNA만 의미) · `upvoteCount:int` · `replyCount:int`(QNA=답변/그 외=댓글). **본문 미리보기·작성자명·작성일은 없다.**
- 상태: `CommunityState`(`posts`·`phase`·`board`·`error`)·`CommunityController`(`load()`·`selectBoard(board)`)·`CommunityBoard` enum(all/qna/free/feedback, `value`·`label`). 이 계약은 **유지**한다.
- `dp_design`엔 `DpInteractiveCard`(hover/focus 베이스)는 있으나 리스트 행 컴포넌트(`DpListRow`)는 없다.

### 1.2 목표
1. `dp_design`에 재사용 `DpListRow`(Layer 2)를 신설하고, 커뮤니티 피드 행을 이로 전환해 **웹다운 hover/focus·상태 계층**을 부여한다.
2. 필터바를 `SegmentedButton`으로 전환하고 `PinnedHeaderSliver`로 스크롤 고정, 리스트를 `CustomScrollView`/`SliverList.builder`로 지연 생성(로드맵 안티패턴 해소).
3. 보드 필터를 URL 쿼리(`?board=`)와 동기해 딥링크·뒤로가기를 지원한다.

### 1.3 비목표 (YAGNI)
- **백엔드/모델 계약 변경 없음.** `/community/posts`·`CommunityPostSummary`·`CommunityController`·`CommunityState` 시그니처 불변.
- **OverlayPortal 제목 hover 미리보기·hover 액션버튼 제외**: `CommunityPostSummary`에 본문·요약이 없어 미리보기하려면 행마다 상세 fetch(N+1)가 필요 — bare 배열 피드에 성능 부담. 계약 확장 시 후속.
- 마크다운 에디터는 하위 B가 이미 정렬(`markdown_widget`) → 범위 밖.
- Q&A 상세/일반 상세/작성 화면(`qna_detail`·`post_detail`·`*_create`)은 이번 범위 아님(피드 화면만). 라우팅 계약만 유지.
- `apps/mobile`·`apps/admin` 대상 아님. `DpListRow`는 순수 위젯이나 웹 hover 전제는 모바일에 이식하지 않는다.

---

## 2. 아키텍처 (3층)

### 2.1 Layer 2 — dp_design 신규 `DpListRow`
`packages/dp_design/lib/src/data/dp_list_row.dart`, `dp_design.dart` export.
- 순수 표현 위젯. go_router·Riverpod **비의존**. 데이터·라우팅은 소비 화면이 주입.
- `DpInteractiveCard`(FocusableActionDetector→Material→InkWell) 베이스를 재사용해 hover/focus 강조를 얻는다.
- API:
  ```dart
  DpListRow({
    Key? key,
    required String title,
    Color? accentColor,             // 좌측 상태 표시선(null=미표시)
    List<Widget> badges = const [], // 상단 뱃지/상태칩 행
    Widget? trailing,               // 우측 메타(세로 스택 등)
    VoidCallback? onTap,
  })
  ```
- **레이아웃(C안)**: `Row[ accentBar(width 3, accentColor, 세로 stretch) · SizedBox · Expanded(Column[ Wrap(badges) → Text(title) ]) · trailing ]`. 색·간격·반경은 토큰만(`DpColors`·`DpSpacing`·`AppTokens.panelRadius`). 접근성: `Semantics`로 제목 노출.

### 2.2 Layer 3 — apps/web 커뮤니티 피드
- `community_home_page.dart`가 `DpListRow`를 조립. `_PostCard`·`_BoardBadge` 제거(또는 DpListRow 조립 헬퍼로 대체). `CommunityController`/`CommunityState`/`CommunityBoard`는 불변.

---

## 3. 커뮤니티 피드 적용

- **행(DpListRow 조립)**:
  - `accentColor`: `switch(boardType){ 'QNA'→c.primary, 'FREE'→c.border, 'FEEDBACK'→c.warning }`.
  - `badges`: 보드 라벨 칩(`Q&A`/`자유`/`피드백`) + `boardType=='QNA' && solved` 시 `✓ 해결됨`(success 톤) 칩.
  - `title`: `post.title`.
  - `trailing`: 메타 세로 스택 — `'${isQna?'답변':'댓글'} ${replyCount}'` · `'추천 ${upvoteCount}'`.
  - `onTap`: 기존 라우팅 유지 — QNA→`/community/${id}`, FREE/FEEDBACK→`/community/post/${id}`.
- **필터바**: `SegmentedButton<CommunityBoard>`(전체/Q&A/자유/피드백, 단일 선택). `PinnedHeaderSliver`로 스크롤 고정.
- **리스트**: `CustomScrollView` + `SliverList.builder`(지연 생성). 광고 슬롯(`COMMUNITY_FEED`, 5번째 뒤) 유지 — 기존 인덱스 계산 로직 보존.
- **URL 동기**: 라우트 `/community`에 `?board=` 쿼리. 진입 시 `GoRouterState.of(context).uri.queryParameters['board']`로 초기 `CommunityBoard` 결정(`CommunityBoard.values.firstWhere(value==쿼리, orElse: all)`) → `selectBoard`. `SegmentedButton` 변경 시 `context.go('/community?board=${board.value ?? ''}')`. 라우트 정의는 쿼리라 경로 추가 불필요.
- 상태(로딩/빈/오류)는 기존 `DpLoading`/`DpEmpty`/`DpError` 유지. FAB 스피드다이얼 유지.

---

## 4. 테스트 (TDD, Test-First — 절대 조건 2)

- **`DpListRow`(dp_design)**: accent bar(accentColor 반영)·badges·title·trailing 렌더, `onTap` 콜백 호출, hover/focus 베이스(`FocusableActionDetector`) 존재, `Semantics` 제목. (`theme: DpTheme.light()`.)
- **커뮤니티 피드(apps/web)**:
  - 행이 `DpListRow`로 렌더(제목·메타·보드 라벨).
  - 보드별 라우팅: QNA 탭→`/community/:id`, FREE/FEEDBACK→`/community/post/:id`(기존 회귀).
  - `SegmentedButton` 선택 → `selectBoard` 호출·필터 반영.
  - URL 쿼리 동기: `/community?board=FREE` 진입 시 초기 필터가 FREE.
  - 광고 슬롯 존재(`COMMUNITY_FEED`).
  - 기존 `community_home_page_test`·`community_controller_test` 회귀 유지.
- **게이트**: `melos run analyze`(0 issues)·`melos run test`(전 패키지 pass)·`melos run format`(clean).

---

## 5. 수용 기준 (AC — 로드맵 §5 Phase 3)

- [ ] `DpListRow`가 dp_design Layer 2로 신설되고 go_router·Riverpod 비의존이다.
- [ ] 피드 행이 `DpListRow`로 렌더되고 hover/focus 시각 강조가 된다.
- [ ] 필터가 `SegmentedButton`이고 스크롤 후 `PinnedHeaderSliver`로 고정된다.
- [ ] 필터 상태가 URL 쿼리(`?board=`)와 동기된다(딥링크·뒤로가기).
- [ ] 리스트가 `SliverList.builder`로 지연 생성된다.
- [ ] 하위 B 데이터 계약(`CommunityPostSummary`)·라우팅과 일치(중복 구현 없음).
- [ ] `CommunityController`/`CommunityState`/`/community/posts` 계약 불변.
- [ ] `melos analyze`·`test`·`format` green.

---

## 6. 구현 분해 지점 (→ writing-plans)

1. **`DpListRow`** (dp_design Layer 2, TDD).
2. **필터바 SegmentedButton + URL 쿼리 동기** (community_home 화면).
3. **`CustomScrollView`/`SliverList` + `PinnedHeaderSliver` 고정 + `_PostCard`→`DpListRow` 전환** + 회귀.

각 단계는 실패 테스트 → 구현 → green → 커밋(Conventional Commits).
