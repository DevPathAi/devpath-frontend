# UI/UX Phase 2 — 학습자 대시보드 / 홈 고도화 (설계)

> 상위 로드맵: [`2026-07-30-web-admin-uiux-elevation-roadmap-design.md`](./2026-07-30-web-admin-uiux-elevation-roadmap-design.md) §5 Phase 2.
> 선행: Phase 0(dp_design 토큰/인터랙션, PR#86)·Phase 1(DpAppShell·DpCommandPalette, PR#87) develop 머지 완료.
> 대상: `apps/web`(학습자 웹앱, Flutter Web). 작성일 2026-07-31 · 브랜치 `feat/uiux-phase2-dashboard`.
> 토큰 SSoT: `DESIGN.md` / Phase 0 `AppTokens`.

---

## 1. 배경 · 목표 · 비목표

### 1.1 배경 (실측)
- 현재 `apps/web/.../dashboard/presentation/dashboard_page.dart`는 `ListView` + `Container` 카드 나열이다. 고정 폭·토큰 직접 지정(`c.surface`/`c.border`/`DpRadius.card`)·`LinearProgressIndicator`·`Chip`으로, 로드맵이 지적한 **"모바일 화면을 넓힌 형태"**의 전형이다.
- 데이터 계약: `/dashboard/me` → `DashboardSummary`(`packages/dp_core/lib/src/models/dashboard_summary.dart`). 필드는 **스칼라 5종**:
  `streakDays:int` · `progressPercent:int` · `nextTaskTitle:String?` · `badges:List<String>` · `completedContentCount:int`.
  **시계열·히스토리·목표치 데이터는 없다.**
- 상태: `DashboardState` sealed(`DashLoading`/`DashLoaded`/`DashFailed`), `DashboardController extends Notifier`(`load()`가 `/dashboard/me` GET). 이 계약은 **유지**한다.

### 1.2 목표
1. 대시보드를 **Bento 그리드 + KPI 카드 + 진행률 도넛 + 스켈레톤 로딩 + 상태 전환 애니메이션**으로 재구성해 로그인 직후 첫 화면의 체감 완성도를 높인다.
2. dp_design에 재사용 KPI 카드(`DpKpiCard`)를 신설하고(Layer 2), 대시보드 화면은 이를 **조립·데이터 바인딩만** 담당(Layer 3)한다.
3. 검증된 외부 패키지(`fl_chart`·`flutter_staggered_grid_view`·`skeletonizer`)를 로드맵 §3 절차로 선별 도입한다.

### 1.3 비목표 (YAGNI)
- **백엔드 계약 변경 없음.** 이번 Phase는 프론트 전용. `/dashboard/me`·`DashboardSummary`·컨트롤러 시그니처 불변.
- **KPI 미니 추세선·라인/바 시계열 차트 제외.** 시계열 데이터가 없어 의미 없는 목(mock) 추세선을 그리지 않는다. 로드맵 §5의 해당 항목은 **계약 확장 시 후속 Phase**로 이월.
- 목표 진행바(KPI 카드의 `progress` 슬롯)는 인터페이스만 확보하고 이번 화면에선 미사용(진행률은 별도 도넛으로 표현).
- `apps/mobile`·`apps/admin`은 대상 아님. dp_core 모델·컨트롤러 변경이 없으므로 파급도 없다(회귀 확인은 `melos analyze` 전 패키지).
- 장식 그림자·BackdropFilter 등 장식 효과는 DESIGN.md §3에 따라 채택하지 않는다.

---

## 2. 아키텍처 (3층)

### 2.1 Layer 2 — dp_design 신규 컴포넌트
**`DpKpiCard`** (`packages/dp_design/lib/src/content/dp_kpi_card.dart` 또는 기존 배치 관행에 맞춤, `dp_design.dart` export)
- 표현부 순수 위젯. go_router·Riverpod **비의존**.
- 파라미터:
  - `required String label` — 지표명(예: "연속 학습").
  - `required int value` — 표시 수치.
  - `IconData? icon` — 선행 아이콘(`DpIcons` 사용, 예: 🔥는 이모지 대신 아이콘 또는 라벨 접두).
  - `String? suffix` — 값 접미(예: "일").
  - `double? progress` — 0~1 목표 진행바(**옵셔널 슬롯**, 이번 Phase 미사용·향후 확장 대비).
  - `Duration? countUpDuration` — 카운트업 애니메이션 시간(기본 `DpDurations` 기반).
- 동작: `TweenAnimationBuilder<int>`로 0→`value` 카운트업. 색·반경·간격은 `DESIGN.md`/`AppTokens` 토큰만 사용. `Semantics(label: "$label $value$suffix")`로 스크린리더 대응(§6 색+텍스트 병행).
- **비목표**: 추세선(sparkline)은 이 Phase에서 구현하지 않는다(데이터 없음).

### 2.2 Layer 3 — apps/web 대시보드 화면
- `DashboardState`(sealed)·`DashboardController`·`DashboardSummary`는 **불변**. `_Body`(현재 `ListView`)를 **Bento 조립**으로 교체.
- 조립 대상: `DpKpiCard`(Layer 2) + 진행률 도넛(fl_chart) + 히어로 CTA 카드 + 배지 스트립 + 기존 `AdSlotWidget`.

---

## 3. 화면 구성 (레이아웃 A — 히어로 CTA + KPI 열)

Expanded/Large(≥840) 기준 배치:

```
┌──────────── AdSlotWidget(slot: DASHBOARD_TOP) ────────────┐
├───────────────────────────┬───────────────┬──────────────┤
│                           │  스트릭(🔥)    │              │
│   다음 과제 (히어로 CTA)   │  streakDays    │   진행률     │
│   nextTaskTitle           ├───────────────┤   도넛       │
│   [이어서 학습] → /path    │  완료 콘텐츠   │ progressPct  │
│                           │  completedCnt  │  (fl_chart)  │
├───────────────────────────┴───────────────┴──────────────┤
│  🏅 배지 스트립 (badges[] · Wrap/Chip)                     │
└───────────────────────────────────────────────────────────┘
```

- **히어로 CTA**: `nextTaskTitle ?? '경로를 생성해 보세요'` + `FilledButton('이어서 학습')` → `context.go('/path')`(기존 동작 유지).
- **진행률 도넛**: `fl_chart` `PieChart`(도넛), 값=`progressPercent`, 중앙 라벨 `"$progressPercent%"`, 섹션 hover 시 값 툴팁. 잔여(100−pct)는 `c.border`류 톤.
- **스트릭 / 완료**: `DpKpiCard`(카운트업). 스트릭은 `suffix:'일'`.
- **배지 스트립**: `badges.isNotEmpty`일 때만. 기존 Chip 표현 유지하되 토큰 정합.
- **광고**: 최상단 `AdSlotWidget(slot:'DASHBOARD_TOP')` 유지(fail-silent).

---

## 4. 반응형 (DESIGN.md §5 window size class)

`flutter_staggered_grid_view`로 폭별 재배치. 본문은 `AppTokens.contentMaxWidth`(Phase 0)로 최대폭 제약(`Align`+`ConstrainedBox`).

| 클래스 | 폭 | 배치 |
|---|---|---|
| Compact | <600 | 1열 세로 스택(CTA→진행률→스트릭→완료→배지) |
| Medium | 600–839 | 2열(좌 CTA / 우 KPI·도넛), 배지 풀폭 |
| Expanded / Large | ≥840 | §3 A 배치(히어로 CTA + KPI 열 + 도넛), 최대폭 제약 |

---

## 5. 로딩 · 상태 전환

- **로딩(`DashLoading`)**: `skeletonizer`로 **A 레이아웃 구조 그대로** 스켈레톤(카드 골격 반영 — 로드맵 AC "스켈레톤이 실제 카드 구조 반영").
- **상태 전환**: `DashLoading`→`DashLoaded`→(빈/`DashFailed`)를 `AnimatedSwitcher`로 부드럽게 전환.
- **빈 상태**: `nextTaskTitle == null`(경로 미생성) 시 히어로 CTA가 "경로를 생성해 보세요" 안내(기존 동작 유지).
- **오류(`DashFailed`)**: 기존 `DpError(onRetry: load)` 유지.

---

## 6. 패키지 도입 (로드맵 §3 검증 절차 필수)

| 패키지 | 용도 | 대안(실패 시) |
|---|---|---|
| `fl_chart` | 진행률 도넛(PieChart), hover 툴팁 | `CustomPaint` 자체 도넛 |
| `flutter_staggered_grid_view` | Bento 폭별 재배치 그리드 | `SliverGrid` 균일 카드 |
| `skeletonizer` | 카드 구조 스켈레톤 로딩 | 기존 `DpLoading`(원형) |

각 도입마다: ① Context7로 최신 버전·API 확인 → ② **Flutter Web(CanvasKit)·현 SDK(Flutter 3.44 계열) 호환** 확인 → ③ 라이선스 확인 → ④ `melos bootstrap`·`melos run analyze` 통과 → ⑤ **확정 버전을 Phase 리포트에 기록**. 도입 위치: 도넛/스켈레톤은 `apps/web`, `DpKpiCard`는 순수(외부 차트 비의존).

---

## 7. 테스트 (TDD, Test-First — 절대 조건 2)

실패 테스트 먼저 작성 → 최소 구현 → `melos run test` 통과 육안 확인.

- **`DpKpiCard`(dp_design)**: 카운트업 최종값·라벨·아이콘·`suffix` 렌더, `Semantics` 라벨. (`theme: DpTheme.light()` 주입.)
- **대시보드(apps/web)**:
  - 폭별 배치: Compact/Medium/Expanded를 `tester.view.physicalSize`로 검증(각 폭에서 의도한 위젯 트리/열 수).
  - 상태 3종: `DashLoading`(스켈레톤)·`DashLoaded`(도넛+KPI+CTA)·`DashFailed`(DpError) 렌더 및 `AnimatedSwitcher` 전환.
  - 도넛: `progressPercent` 반영(중앙 라벨 텍스트).
  - CTA 라우팅: "이어서 학습" → `/path`(기존 회귀).
  - 광고 슬롯 존재.
- **게이트**: `melos run analyze`(전 패키지 0 issues) · `melos run test`(전 패키지 pass) · `melos run format`(clean).

---

## 8. 수용 기준 (AC — 로드맵 §5 Phase 2)

- [ ] 로딩→성공→빈/오류 상태가 `AnimatedSwitcher`로 전환된다.
- [ ] 진행률 도넛 hover 시 값 툴팁이 뜬다.
- [ ] Bento가 Compact/Medium/Expanded 폭별로 재배치된다.
- [ ] 스켈레톤이 실제 카드 구조를 반영한다.
- [ ] 패키지 3종 도입이 §3 절차로 검증·기록된다(확정 버전).
- [ ] `DpKpiCard`가 dp_design Layer 2로 신설되고 go_router·Riverpod 비의존이다.
- [ ] `DashboardSummary`·`/dashboard/me` 계약 불변(백엔드 무변경).
- [ ] `melos analyze`·`test`·`format` green.

---

## 9. 구현 분해 지점 (→ writing-plans)

1. **패키지 도입 + 검증** (fl_chart·staggered·skeletonizer, §3 기록).
2. **`DpKpiCard`** (dp_design Layer 2, TDD).
3. **진행률 도넛 위젯** (fl_chart PieChart, apps/web, TDD).
4. **Bento 레이아웃 + 반응형** (staggered, 폭별 재배치, 최대폭 제약).
5. **로딩·상태 전환** (skeletonizer + AnimatedSwitcher).
6. **`_Body` 교체·통합** (기존 컨트롤러/상태 유지, CTA·광고·배지 정합) + 회귀 테스트.

각 단계는 실패 테스트 → 구현 → green → 커밋(Conventional Commits).
