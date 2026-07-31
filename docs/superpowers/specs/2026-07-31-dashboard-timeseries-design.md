# 대시보드 시계열 차트 — 설계 (Design)

> 날짜: 2026-07-31 · 범위: 학습자 대시보드에 **주간 학습량 바차트**와 **진행률 추이 라인차트** 추가 · 성격: UI/UX 로드맵 **Phase 2 이월**(백엔드 계약 확장) · 파급 레포: `devpath-learning-svc` + `devpath-frontend`(`shared` 발행 불필요)

## 1. 배경 / 목표

UI/UX 고도화 로드맵 Phase 2(학습자 대시보드)는 KPI·도넛·Bento를 완결했으나, **백엔드 데이터 계약에 시계열이 없어** 추세선·라인/바 차트를 이월했다. 이번 작업은 그 시계열 계약을 추가해 대시보드에 **학습 추세**를 시각화한다.

- **완료 정의**: 학습자가 대시보드에서 (1) 최근 7일 일별 학습량과 (2) 최근 14일 진행률 추이를 두 개의 차트 카드로 본다. 신규 사용자는 빈 상태 안내를 본다.

## 2. 현재 상태 (검증된 사실, 2026-07-31 코드 실측)

- `GET /dashboard/me` → `ai.devpath.learning.dashboard.DashboardSummary`(learning-svc **로컬 record**, 공유 계약 아님). 필드 5종: `streakDays`·`progressPercent`·`nextTaskTitle`·`badges`·`completedContentCount`. **시계열 없음.**
- 원천 데이터에 타임스탬프 존재 → **시계열은 기존 데이터의 SQL 집계 프로젝션**(신규 이벤트 수집 불필요):
  - `user_content_progress.completed_at` — 콘텐츠 완료 시각(`ContentProgressRepository`).
  - `path_weekly_tasks.completed_at` — 과제 완료 시각(활성 경로 `learning_paths.status='ACTIVE'`).
- `DashboardService`는 `paths.currentOptional(userId)`로 **단일 활성 경로**의 과제 완료 비율로 `progressPercent`를 계산.
- dp_core `DashboardSummary`(freezed) → web·mobile 소비. web은 `DashboardController.load()`가 `/dashboard/me`를 `DashboardSummary.fromJson`으로 **그대로 파싱**(신규 필드 자동 흐름).
- `fl_chart ^1.2.0`은 `apps/web`에만 존재(dp_design엔 없음). 기존 `ProgressDonut`도 `apps/web/.../dashboard/presentation/widgets/`의 앱 레벨 위젯.
- **핸드오프 정정**: "DpKpiCard에 trend 슬롯 이미 존재"는 **오류**. 실제 `DpKpiCard`는 `progress`(0~1 진행바)만 보유, `trend`/스파크라인 슬롯 없음. → 이번 범위는 KPI 카드 미변경(Option 2).

## 3. 범위 / 비범위

**범위**: 신규 차트 카드 2개(바 + 라인) + 백엔드 필드 2개 + dp_core 모델 2개.

**비범위**(후속 이월):
- `DpKpiCard` trend 스파크라인 슬롯(디자인시스템 변경) — Option 3 미채택.
- 일별 학습 **시간(분)** 지표 — 데이터로 재구성 불가(§7 Fork 1).
- 기간 선택 UI(7/14/30일 토글) — 고정 윈도우로 시작.

## 4. 데이터 계약 (신규 필드 2개, additive·하위호환)

`DashboardSummary`에 2필드 추가(기존 5종 불변):

| 필드 | 타입 | 의미 | 윈도우 |
|---|---|---|---|
| `weeklyActivity` | `List<DailyActivity>` | 일별 완료 콘텐츠 수 | 최근 7일(오늘 포함, 빈 날 `count=0` 채움, 오름차순) |
| `progressHistory` | `List<ProgressPoint>` | 일별 누적 진행률(%) | 최근 14일(활성 경로 없으면 빈 배열) |

포인트 타입(JSON 키는 백엔드 record ↔ dp_core 모델 일치):

- `DailyActivity { date: LocalDate, completedCount: int }` → `{"date":"2026-07-31","completedCount":3}`
- `ProgressPoint { date: LocalDate, percent: int }` → `{"date":"2026-07-31","percent":42}`

`LocalDate`는 Jackson 기본 ISO 문자열(`"2026-07-31"`)로 직렬화 → Dart는 `String`으로 수신, 축 라벨용으로 `DateTime.parse`.

## 5. 백엔드 설계 (devpath-learning-svc, Java / Spring Boot 4)

- **`ContentProgressRepository`** (또는 신규 `DashboardTimeseriesRepository`)에 집계 메서드 2개:
  - `weeklyActivityRows(userId, since)`:
    `SELECT completed_at AT TIME ZONE 'Asia/Seoul'` 기준 `date`별 `count(*)` — `WHERE user_id=:u AND completed_at IS NOT NULL AND completed_at >= :since GROUP BY date`. **원시 grouped 행만** 반환(빈 날 채움은 서비스에서).
  - `activePathTaskCompletions(userId)`: 활성 경로 과제의 `completed_at` 목록 + **전체 과제 수** 반환(`path_weekly_tasks` JOIN `path_milestones`/`learning_paths WHERE status='ACTIVE'`).
- **`DashboardService`**에서 달력 채움·누적 계산을 **순수 Java 로직**으로 수행:
  - `weeklyActivity`: 오늘(KST) 기준 역순 7일 슬롯 생성 → grouped 행을 map으로 조회, 없는 날 `0`.
  - `progressHistory`: 최근 14일 각 날짜 D에 대해 `completed_at ≤ D인 과제 수 / 전체 × 100`(반올림) → 누적 상승 곡선. 전체=0(활성 경로 없음)이면 빈 배열.
  - 순수 로직이므로 **가짜 repo로 단위 테스트**(DB 불필요) — TDD 씨앗.
- `DashboardSummary` record에 2필드 추가, 생성자 호출부(2곳: path null 분기 포함) 갱신.
- **타임존**: 일별 버킷은 **KST(Asia/Seoul)**. `completed_at` 저장 tz는 구현 시 실측 확인 후 변환 로직 결정(§7 Fork 4).

## 6. 프론트 설계 (devpath-frontend)

- **dp_core**: `packages/dp_core/lib/src/models/dashboard_timeseries.dart` 신설 — `DailyActivity`·`ProgressPoint` freezed 모델(+ `fromJson`). `dashboard_summary.dart`에 `@Default(<DailyActivity>[]) List<DailyActivity> weeklyActivity`·`@Default(<ProgressPoint>[]) List<ProgressPoint> progressHistory` 추가 후 freezed 재생성. 신규 모델은 배럴(`dp_core.dart`)에 export.
  - **⚠️ mobile 파급**: dp_core 변경은 web+mobile 전 소비 앱에 파급 → `melos run analyze`(전 패키지) 통과 확인. additive+기본값이라 컴파일 안전.
- **web**: `apps/web/lib/src/features/dashboard/presentation/widgets/`에 차트 카드 2개 신설(`ProgressDonut` 패턴 따름):
  - `_WeeklyActivityCard`(또는 `weekly_activity_card.dart`): `fl_chart` `BarChart`, x축 요일(월~일), 값=완료 수.
  - `_ProgressTrendCard`: `fl_chart` `LineChart`, x축 날짜(14일), y축 0~100%.
  - `dashboard_body.dart` Bento에 두 카드 `StaggeredGridTile.fit` 추가(폭별 span은 기존 도넛 배치 규칙 준용).
- **⚠️ Fork 3(차트 위치)**: `fl_chart`는 `apps/web`에만, `ProgressDonut`도 앱 레벨 → 두 차트도 **`apps/web` 위젯**. **dp_design 미오염**(fl_chart 의존 이관 안 함).
- **빈 상태**: `weeklyActivity`가 전부 0이거나 `progressHistory`가 빈 배열이면 해당 카드는 차트 대신 "아직 학습 기록이 없어요" 안내.

## 7. 결정 기록 (Forks)

- **Fork 1 — "학습량"의 정의 = 일별 완료 콘텐츠 수**. 핸드오프 예시 `minutes`는 **데이터로 재구성 불가**(`user_content_progress.dwell_sec`는 (user,content)별 누적값, 일별 로그 없음). 정직하게 `completed_at::date` 완료 건수로 정의(기존 `completedContentCount` KPI와 일관).
- **Fork 2 — "진행률 추이"의 정의 = 활성 경로 과제의 누적 완료율 곡선**. 날짜 D별 `(completed_at ≤ D 과제 수)/전체 × 100`. 활성 경로 없으면 빈 배열(현재 `progressPercent=0`과 일관).
- **Fork 3 — 차트는 `apps/web` 앱 레벨 위젯**(dp_design 미변경, fl_chart 의존 격리). 기존 `ProgressDonut` 선례.
- **Fork 4 — 일별 버킷 타임존 = KST(Asia/Seoul)**. 제품이 한국. `completed_at` 저장 tz 실측 후 변환.

## 8. 검증 / 테스트 전략 (TDD, CLAUDE.md 규칙 2)

- **백엔드**:
  - `DashboardService` 단위 테스트(가짜 repo → gap-fill 7일·누적 % 14일 계산 검증, 활성 경로 없음/빈 데이터 경계).
  - repository SQL 통합 테스트(CI postgres). **로컬 postgres 미기동 시** 서비스 단위 테스트가 로컬 TDD 타깃, SQL은 CI 의존.
- **프론트**:
  - dp_core: `DashboardSummary`·신규 포인트 모델 JSON 라운드트립 테스트(신규 필드 파싱).
  - web: 차트 카드 위젯 테스트(fl_chart 렌더, 빈 상태 안내, 요일/날짜 축). 실패 테스트 선작성.
- **게이트**: `melos run format`(커밋 전 필수, `--set-exit-if-changed`) → `melos run analyze` → `melos run test`. 백엔드 `./gradlew test`.

## 9. 작업 분해 / 레포 / 브랜치

- **레포 2곳**: `devpath-learning-svc`(백엔드 계약+집계) · `devpath-frontend`(dp_core 모델 + web 차트). `shared` 발행 불필요(계약이 learning-svc 로컬 record).
- **브랜치**: frontend `feat/dashboard-timeseries`(spec/plan/구현 동일 브랜치, Phase 2~5 선례) → `develop` PR. learning-svc는 자체 `feat/*` 브랜치 → 자체 `develop` PR.
- **순서(권장)**: 백엔드 계약·집계·테스트 선행(계약 확정) → dp_core 모델 → web 차트 카드. 다만 dp_core/web은 목 데이터로 백엔드와 병행 가능.

## 10. 참조

- 로드맵 spec(이월 근거 §5): `devpath-frontend/docs/superpowers/specs/2026-07-30-web-admin-uiux-elevation-roadmap-design.md`
- 핸드오프: `documents/docs/superpowers/handoff-2026-07-31-uiux-roadmap-complete-next-contract-expansion.md`(§A)
- 관련 코드: `devpath-learning-svc/src/main/java/ai/devpath/learning/dashboard/{DashboardController,DashboardService,DashboardSummary}.java`, `.../content/ContentProgressRepository.java` · `devpath-frontend/packages/dp_core/lib/src/models/dashboard_summary.dart` · `.../apps/web/lib/src/features/dashboard/presentation/widgets/dashboard_body.dart`
