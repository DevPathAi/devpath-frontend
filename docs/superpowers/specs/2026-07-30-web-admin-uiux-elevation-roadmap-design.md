# web·admin UI/UX 고도화 로드맵 (마스터 플랜)

> 대상: `apps/web`(학습자 웹앱)·`apps/admin`(운영 콘솔) — 둘 다 Flutter Web.
> 목적: **기능은 갖춰졌으나 "모바일 화면을 넓힌 형태"에 머문 UI를, 마우스·키보드·다중 패널·대형 데이터에 맞는 실제 웹 애플리케이션 수준으로 끌어올린다.**
> 성격: 이 문서는 **로드맵(무엇을 왜 어떤 위젯으로)** 이다. 실제 코드·TDD 테스트는 각 Phase 착수 시 별도 화면 spec→plan으로 분해한다.
> 토큰 SSoT: `DESIGN.md`. 이 로드맵은 DESIGN.md를 **참조**하고, 신규 토큰은 §4에 "추가 제안"으로만 둔다(반영은 Phase 0).
> 작성일 2026-07-30 · 브랜치 `docs/web-admin-uiux-roadmap`.

---

## 1. 배경 · 목표 · 비목표

### 1.1 배경
- 현재 상태(실측): `apps/web`은 `AppShellView`가 폭 840px 단일 분기로 `NavigationRail`(라벨 all) ↔ `NavigationBar`만 전환한다. `apps/admin`은 `NavigationRail(extended: true)` 영구 펼침 고정이다.
- `dp_design`은 **토큰(color/spacing/typography/theme)과 상태 위젯(empty/error/loading/offline/quota/sse_stage/kill_switch/sandbox)** 은 탄탄하나, 웹 고도화의 핵심 컴포넌트(확장형 앱 셸·명령팔레트·고급 리스트 행·KPI/차트 카드·데이터테이블)는 없다.
- 외부 위젯 패키지는 사실상 미도입(`markdown_widget`·`material_symbols_icons`·`visibility_detector`만).

### 1.2 목표
1. dp_design에 **재사용 가능한 웹 고도화 컴포넌트 계층**을 신설하고, web/admin 화면이 이를 조립만 하도록 전환한다.
2. 웹다운 상호작용(hover·focus·키보드 단축키·명령팔레트·텍스트 선택·스크롤바·최대 폭 제약·상태 전환)을 기본값으로 만든다.
3. 검증된 외부 패키지를 선별 도입해 대시보드·데이터테이블·로딩 완성도를 높인다.

### 1.3 비목표 (YAGNI)
- **랜딩(Jaspr)·SEO·정적 마케팅 페이지**는 범위 밖(별도 표현형, 토큰만 공유 — DESIGN.md §0).
- **글래스모피즘·BackdropFilter·ShaderMask 등 장식 효과**: DESIGN.md §3 "APP UI 장식 그림자 금지, 그림자는 오버레이에만" 정책에 따라 **채택하지 않는다**(오버레이 elevation 예외만).
- **AppFlowy/super_editor 같은 블록·풀커스텀 에디터**: 커뮤니티는 마크다운 방향 확정(하위B) → 기존 `markdown_widget` 정렬로 충분. 도입 안 함.
- 모바일 앱(`apps/mobile`)은 이 로드맵의 **구현 대상 아님**. 웹 패턴을 그대로 이식하지 않기 위한 **경계 원칙만** §2.3·§횡단에 둔다.

---

## 2. 아키텍처

### 2.1 3층 분리
화면마다 위젯을 직접 짜지 않고 계층으로 분리한다.

- **Layer 1 — dp_design 토큰/인터랙션 베이스**: `AppTokens`(ThemeExtension)·`WidgetStateProperty` 상태 스타일 세트·최대폭 래퍼·`SelectionArea`/`Scrollbar` 정책·`FocusableActionDetector` 카드 베이스.
- **Layer 2 — dp_design 공용 컴포넌트**: `DpAppShell`·`DpCommandPalette`·`DpListRow`·`DpKpiCard`·`DpDataTable`.
- **Layer 3 — 앱 화면**: web/admin의 각 feature가 Layer 2를 소비. 화면은 **조립·데이터 바인딩만** 담당.

> 원칙: Layer 2 컴포넌트는 go_router·Riverpod에 **비의존**(순수 표현부)으로 두고, 라우팅/상태는 앱 측 얇은 래퍼가 주입한다. 기존 `AppShell`(라우터 결합) ↔ `AppShellView`(표현부) 분리 패턴을 계승·확장한다.

### 2.2 반응형 브레이크포인트 (DESIGN.md §5에 정렬 — 재정의 금지)
자료의 720/1200이 아니라 **기존 SSoT window size class**를 따른다.

| 클래스 | 폭 | web 셸 | admin 셸 |
|---|---|---|---|
| Compact | <600 | 하단 `NavigationBar` | 하단 탭 또는 Drawer(운영은 웹 우선이라 후순위) |
| Medium | 600–839 | `NavigationRail`(아이콘·접힘) | Rail 접힘 |
| Expanded | 840–1239 | `NavigationRail`(라벨/확장) | Rail 확장 |
| Large | ≥1240 | Rail 확장 + 넓은 본문(최대폭 제약) | Rail 확장 + 본문 |

- 기존 web 셸의 **840 단일 분기 → 위 4-클래스로 세분화**(Medium에 "레일 접힘" 신설)가 Phase 1의 핵심 변경.
- 본문은 Large에서 모니터 전체 폭으로 퍼지지 않도록 `AppTokens.contentMaxWidth` 제약(Align+ConstrainedBox).

### 2.3 웹/모바일 경계
- `DpAppShell`은 위 브레이크포인트로 rail(웹)/bottom-nav(compact)를 전환한다.
- **모바일 전용 상호작용**(showModalBottomSheet·FAB 스피드다이얼·Dialog.fullscreen·DraggableScrollableSheet)은 `apps/mobile` 몫으로 **분리**하고, 웹의 hover/키보드/명령팔레트/OverlayPortal 미리보기를 **모바일에 이식하지 않는다**.

---

## 3. 도입 패키지 목록

> **버전은 실제 도입 Phase에서 확정한다.** 이 문서는 용도·대안·라이선스·검증 절차만 고정한다.
> **검증 절차(각 도입 시 필수)**: ① Context7로 최신 버전·API 확인 → ② **Flutter Web(CanvasKit) 지원 여부**·현재 SDK(Flutter 3.44 계열) 호환 확인 → ③ 라이선스 확인 → ④ `melos bootstrap`·`melos run analyze` 통과 → ⑤ 도입 결과(확정 버전)를 해당 Phase 리포트에 기록.

| 패키지 | 용도 | Phase | 대안(도입 실패 시) | 라이선스 확인 |
|---|---|---|---|---|
| `fl_chart` | 대시보드 차트(Line/Bar/Donut), KPI 미니 추세선 | 2 | `CustomPaint` 자체 스파크라인 | 필요 |
| `flutter_staggered_grid_view` | Bento/Quilted 대시보드 그리드 | 2 | `SliverGrid`(균일 카드) | 필요 |
| `skeletonizer` | 리스트/카드 스켈레톤 로딩 | 2·3 | 기존 `dp_loading`(원형) | 필요 |
| `data_table_2` | admin 고정 헤더/열 테이블 | 4 | 기본 `DataTable` + 자체 sticky | 필요 |
| `two_dimensional_scrollables` | 대형 데이터 `TableView`(양방향·지연 셀) | 4 | `data_table_2` 페이지네이션으로 대체 | 확인 필요 |

- **미도입 확정**: AppFlowy·super_editor·html_editor_enhanced·flutter_quill(마크다운 방향), BackdropFilter 계열(장식 정책).
- `SearchAnchor`·`MenuAnchor`·`NavigationRail`·`CustomScrollView`·`PinnedHeaderSliver`·`ReorderableListView`·`FocusableActionDetector`·`Shortcuts`/`Actions`·`SelectionArea`·`Scrollbar`는 **전부 Flutter SDK 기본** → 외부 의존 없음.

---

## 4. DESIGN.md 추가 토큰 제안 (반영: Phase 0)

기존 `DpColors`(ThemeExtension)·`DpSpacing`/`DpRadius`/`DpDurations` 패턴을 계승한다.

### 4.1 `AppTokens` (신규 ThemeExtension)
| 토큰 | 예시값 | 용도 |
|---|---|---|
| `contentMaxWidth` | 1440 | Large 본문 최대 폭 |
| `readableMaxWidth` | 880 | 문서·상세 읽기 폭 |
| `railWidth` | 256 | 확장 rail 폭 |
| `railCollapsedWidth` | 72 | Medium 접힘 rail 폭 |
| `panelRadius` | (DpRadius.card=10 재사용) | 패널 반경 |

### 4.2 상태별 스타일 (WidgetStateProperty)
- normal/hover/focus/pressed/selected/disabled 6상태를 **DESIGN.md §1 색 토큰 기반**으로 해석하는 공용 resolver 세트.
- 색만으로 의미 전달 금지(§6) — selected는 배경+굵기, focus는 2px 테두리 병행.

### 4.3 모션 토큰 확장 (`DpDurations`)
- 기존 `stageReveal`(200)·`skeletonCrossfade`(150)에 추가: `hover`(120)·`select`(180)·`panelExpand`(220). (자료 §10 시작값, 과도한 지연 회피.)

### 4.4 아이콘 보강 (`DpIcons`)
- 명령팔레트/검색용 `search`, 더보기 `moreVert`, 즐겨찾기 `star` 등 누락분 추가(Material Symbols Rounded 유지, 이모지 최소 정책 §4).

---

## 5. Phase 정의

각 Phase: **목표 / 대상 파일 / 신설 위젯(Layer) / 수용 기준(AC) / 이후 spec 분해 지점**.

### Phase 0 — 기반 토큰 & 인터랙션 (dp_design, Layer 1) ★착수 1
- **목표**: 이후 모든 컴포넌트가 소비할 토큰·상태 스타일·래퍼를 먼저 확립.
- **대상 파일**: `packages/dp_design/lib/src/theme/`(app_tokens.dart 신규, dp_spacing/dp_theme 확장), `dp_design.dart` export, `DESIGN.md` 갱신.
- **신설(Layer 1)**: `AppTokens`, `WidgetState` resolver 세트, `DpMaxWidth`(Align+ConstrainedBox), `DpSelectable`(SelectionArea 래퍼), 공용 `Scrollbar` 정책, `DpInteractiveCard`(FocusableActionDetector+Material+InkWell 베이스).
- **AC**: `DpTheme.light()/dark()`에 `AppTokens` 등록·`context` 확장으로 조회 가능 / 6상태 스타일 위젯 테스트 통과 / DESIGN.md 토큰과 수치 일치 / `melos run analyze`·`test` green.
- **분해**: 단일 spec으로 충분(소규모).

### Phase 1 — 공통 앱 셸 & 내비 (dp_design `DpAppShell`, web+admin) ★착수 2
- **목표**: 4-클래스 반응형 셸 + 명령팔레트 슬롯을 dp_design에 두고 web/admin이 소비.
- **대상 파일**: `packages/dp_design`(dp_app_shell.dart·dp_command_palette.dart 신규), `apps/web/.../shell/presentation/app_shell.dart`(→ DpAppShell 소비로 이관), `apps/admin/.../shell/presentation/admin_shell.dart`(동일).
- **신설(Layer 2)**: `DpAppShell`(§2.2 4-클래스, rail 확장/축소 토글, 2차 메뉴 ExpansionTile, 목적지 `Badge`, 하단 계정 슬롯, `FocusTraversalGroup`), `DpCommandPalette`(`SearchAnchor`+`Shortcuts`/`Actions`, Ctrl/Cmd+K — 목적지 이동·명령 실행 슬롯; 결과 소스는 앱이 주입).
- **AC**: web 셸이 Compact/Medium/Expanded/Large에서 각각 의도된 형태(위젯 테스트로 폭별 검증) / 기존 `kShellDestinations` 계약 유지 / Ctrl+K로 팔레트 오픈·Esc 닫힘·방향키 이동 / admin `extended` 유지가 Large에서 동일 / hover·focus 상태 시각 구분 / analyze·test green.
- **분해**: DpAppShell / DpCommandPalette / web 이관 / admin 이관 = plan 내 Task로.

### Phase 2 — 학습자 대시보드 / 홈 (web, Layer 2+3)
- **목표**: 로그인 직후 첫 화면의 체감 완성도.
- **대상 파일**: `apps/web/.../dashboard/presentation/*`, dp_design(dp_kpi_card.dart 신규).
- **신설/도입**: `DpKpiCard`(TweenAnimation 숫자·목표 진행바·미니 추세선), `fl_chart`, `flutter_staggered_grid_view`(Bento), `skeletonizer` 로딩, `AnimatedSwitcher` 상태전환.
- **AC**: 로딩→성공→빈/오류 상태가 `AnimatedSwitcher`로 전환 / 차트 hover 툴팁 / Bento가 폭별로 재배치 / 스켈레톤이 실제 카드 구조 반영 / 패키지 도입 검증(§3) 기록 / green.
- **분해**: DpKpiCard / 차트 위젯 / Bento 레이아웃 / 로딩·상태전환.

### Phase 3 — 커뮤니티 피드 / 게시판 (web, 하위B와 정렬)
- **목표**: 진행 중 하위B(자유/피드백 웹, Task2~9)의 UI를 이 컴포넌트로 구현.
- **대상 파일**: `apps/web/.../community/presentation/*`, dp_design(dp_list_row.dart 신규).
- **신설**: `DpListRow`(상태 표시선·제목+상태칩·메타·hover 액션), 통합 피드+`FilterChip`/`SegmentedButton`, `OverlayPortal` 미리보기, `PinnedHeaderSliver` 고정 필터, 마크다운 에디터(기존 `markdown_widget` 정렬).
- **AC**: 필터칩 상태가 URL/상태와 동기 / hover 시 행 액션 노출 / 제목 hover 미리보기(웹 전용) / 스크롤 후 필터 고정 / 하위B spec의 데이터 계약과 일치 / green.
- **의존**: 하위B PR-A(백엔드 피드 요약)·Task2~9 플랜과 **정렬 필수**(중복 구현 금지).
- **분해**: 하위B 기존 plan에 UI 고도화 항목을 병합하거나, 별도 UI spec으로.

### Phase 4 — admin 운영 콘솔 (admin, Layer 2+3)
- **목표**: 대량 데이터·관리자 작업 효율.
- **대상 파일**: `apps/admin/.../{users,reports,ads}/presentation/*`, dp_design(dp_data_table.dart 신규).
- **신설/도입**: `DpDataTable`(`data_table_2` 래핑; 초대형은 `two_dimensional_scrollables` TableView), 명령팔레트(Phase 1 재사용), 벌크 액션바(`AnimatedSwitcher`로 등장), `MenuAnchor` 행 메뉴, `FocusTraversalGroup` 폼.
- **AC**: 헤더/첫 열 고정 스크롤 / 다중 선택 → 벌크 액션바 / 행 `MenuAnchor` 작업 / 가로 스크롤 `Scrollbar(thumbVisibility:true)` / green.
- **분해**: DpDataTable / 벌크 액션 / 행 메뉴 / 화면별 적용.

### Phase 5 — 학습 여정 (web: 진단·콘텐츠·멘토)
- **목표**: 기존 상태 위젯(`dp_sse_stage` 등) 위에 리스트/스크롤 고도화.
- **대상 파일**: `apps/web/.../{diagnostic,content,mentor}/presentation/*`.
- **신설**: `CustomScrollView`/`SliverList` 전환, SSE 상태전환 다듬기(기존 위젯 활용), 리스트 행은 `DpListRow` 재사용.
- **AC**: 긴 목록 지연 생성(builder) / SSE 로딩→토큰스트림→완료/에러 전환 매끄러움 / 기존 회귀 테스트 유지 / green.
- **분해**: 화면별 소규모 spec.

### 횡단 관심사 (전 Phase 공통 체크리스트)
- **접근성**(DESIGN.md §6): `Semantics`/`MergeSemantics`, 키보드 포커스·Tab 순서, 대비 ≥4.5:1, 색+레이블 병행, `MediaQuery.disableAnimationsOf` 존중.
- **성능**: `ListView/SliverList.builder` 지연 생성, `const`·build 분리, `RepaintBoundary`는 DevTools 확인 후만, `IntrinsicWidth/Height` 테이블 반복 금지.
- **모바일 원칙**(경계): 웹 hover/키보드/명령팔레트/OverlayPortal을 `apps/mobile`에 이식 금지. 모바일은 NavigationBar·BottomSheet·FAB 별도 셸.
- **패키지 도입**: §3 검증 절차를 매 도입마다 수행·기록.

---

## 6. 안티패턴 체크리스트 (매 Phase 리뷰 시 확인 — 자료 §16·§13 축약)

| 좋지 않은 방식 | 개선 |
|---|---|
| 고정 width/height 남발 | Expanded/Flexible/ConstrainedBox/LayoutBuilder |
| 웹 본문 전체 너비로 확장 | `DpMaxWidth`(Align+ConstrainedBox) |
| 큰 목록을 SingleChildScrollView+Column | ListView/SliverList.builder |
| 페이지 전체를 Stack+Positioned | Row/Column/Flex 기본 |
| 화면마다 색·반경 직접 지정 | DESIGN.md 토큰·`AppTokens` |
| 클릭 Container+GestureDetector만 | `DpInteractiveCard`(FAD+Material+InkWell)+Semantics |
| 텍스트 선택 불가 | 본문 `DpSelectable` |
| 가로 테이블 스크롤바 없음 | `Scrollbar(thumbVisibility:true)` |
| hover만 있고 focus 없음 | FocusableActionDetector |
| 색만으로 상태 의미 | 색+텍스트/아이콘 병행 |
| 장식 그림자·BackdropFilter | 보더 우선(그림자는 오버레이만) |

---

## 7. 실행 순서 요약 · 다음 액션

| 순서 | Phase | 산출 | 착수 신호 |
|---|---|---|---|
| 1 | 0 기반 토큰 | dp_design Layer 1 | 이 로드맵 승인 직후 |
| 2 | 1 앱 셸·명령팔레트 | dp_design Layer 2 + web/admin 이관 | Phase 0 완료 |
| 3 | 2 대시보드 | web + fl_chart/staggered/skeleton | Phase 1 완료 |
| 4 | 3 커뮤니티 | web(하위B 정렬) | 하위B 백엔드·플랜과 조율 |
| 5 | 4 admin 콘솔 | admin + data_table_2 | Phase 1 완료 후 병행 가능 |
| 6 | 5 학습 여정 | web | 후순위 |

**다음 액션**: 이 로드맵 승인 후 → `superpowers:writing-plans`로 **Phase 0 + Phase 1 구현 플랜**을 작성(TDD·bite-sized). 각 Phase는 자체 spec→plan→구현 사이클을 가진다.

---

## 부록 A. 근거 (실측)
- web 셸: `apps/web/lib/src/features/shell/presentation/app_shell.dart`(840 단일 분기, NavigationRail/Bar).
- admin 셸: `apps/admin/lib/src/features/shell/presentation/admin_shell.dart`(extended rail 고정).
- 토큰: `packages/dp_design/lib/src/theme/{dp_colors,dp_spacing,dp_typography,dp_theme}.dart`, `DESIGN.md` §1·§3·§5·§6.
- 아이콘: `packages/dp_design/lib/src/icons/dp_icons.dart`.
- 하위B: `docs/superpowers/{specs,plans}/2026-07-29-community-free-feedback-web*`.
