# ①디자인 3-B 설계 — 차트 팔레트 재설계 + 다중 계열

> 작성 2026-08-07 · 선행 3-A 완료(PR #108, merge `72d12f8`)
> 3-A 스펙 §9(3-B 예고)를 대체한다 — **§9의 전제 중 두 가지가 실측으로 뒤집혔다(§2.3·§2.4).**
> 대상 레포: `devpath-frontend` + `devpath-learning-svc`

## 1. 목표

1. **차트 팔레트를 브랜드에서 분리한다.** 현재 `chart1~3`은 한 색상 계열에 몰려 있어 다중 계열 차트가 성립하지 않는다.
2. **진행률 추세를 과제 유형별 3계열로 분해한다** — 「읽기는 80%인데 실습은 40%」 같은 약점을 드러낸다.
3. **마일스톤(주차)별 진행률 차트를 신설한다.**
4. 도넛의 **미완료 색 토큰 오용**(경계선 토큰을 데이터 면에 사용)을 바로잡는다.

## 2. 실측 — 다시 조사하지 마라

### 2.1 현재 팔레트로는 3계열 구분이 불가능하다

`packages/dp_design/lib/src/theme/dp_colors.dart` 실값으로 계산했다.

| 쌍 | 라이트 hue차 / 대비 | 다크 hue차 / 대비 |
|---|---|---|
| chart1–chart2 | 10.2° / 1.56:1 | **0.5° / 1.03:1** |
| chart1–chart3 | **4.3°** / 1.81:1 | 8.3° / 1.49:1 |
| chart2–chart3 | 14.5° / 2.81:1 | 8.8° / 1.53:1 |
| chart1–chart4 | 149.4° / 1.09:1 | 134.8° / 1.15:1 |

`chart1~3`이 전부 앰버/브라운 한 계열이다. **다크의 `chart1`·`chart2`는 색상 0.5°·명도 1.03:1로 사실상 같은 색**이다. 구분되는 것은 `chart4`(틸) 하나뿐이다.

### 2.2 `chart1`은 `primary`와 값이 완전히 같다

라이트 `#B45309`, 다크 `#F59E0B` — 3-A 스펙 §9.1이 확인한 그대로다. 「Bar·Line을 `chart1`로 이관」은 픽셀 변화가 0이다.

### 2.3 ★배경 대비와 계열 간 명도 분리는 동시에 만족할 수 없다★

후보 팔레트(파랑·틸·자홍)를 실측한 결과 배경 대비는 5.20~6.45:1로 전부 통과했으나 **계열 간 명도 대비가 1.01~1.28:1**로 실패했다.

원인이 구조적이다: 각 색이 배경 대비 3:1을 지키려면 배경에서 멀어져야 하는데, 배경이 거의 흰색(`#FAF9F7`)/거의 검정(`#0F0E0C`)이라 **세 색이 모두 반대쪽 명도대로 몰린다.** 두 기준은 같은 방향으로 당길 수 없다.

→ **합격 기준을 §3.2로 정한다**(사용자 결정): 계열 간 명도 대비는 필수 기준에서 뺀다.

### 2.4 ★주간 활동과 진행률 추세는 데이터 소스가 다르다★ — 3-A 스펙 §9.3의 오류

3-A 스펙 §9.3은 "`path_weekly_tasks`에 `task_type`이 있어 유형별 일별 집계가 SQL만으로 나온다"고 적었으나, **그것은 진행률 추세에만 해당한다.**

| 차트 | 소스 | `task_type` |
|---|---|---|
| 주간 활동(Bar) | `user_content_progress` (`ContentProgressRepository.dailyCompletedCounts`) | **없다** |
| 진행률 추세(Line) | `path_weekly_tasks` JOIN (`activePathCompletions`) | 있다(같은 테이블) |

주간 활동을 유형별로 나누려면 데이터 소스를 바꿔야 하고, 그러면 차트의 의미가 「이번 주 학습량(콘텐츠)」에서 「이번 주 과제 완료」로 달라진다.
→ **주간 활동은 콘텐츠 기반 단일 계열로 유지한다**(사용자 결정).

### 2.5 `/paths/current`가 이미 주는 것

`WeeklyTaskView(orderNum, taskType, title, required, contentId, contentSlug, completed)` — **`taskType`과 `completed`가 이미 노출된다.**
`MilestoneView(weekNum, title, goalDescription, targetSkills, estimatedHours, whyThisOrder, …tasks)`.

**단 `completedAt`은 없다.** 따라서:

- **주차별 진행률**(현재 시점 스냅샷) → `/paths/current`만으로 프론트에서 계산. **백엔드 무변경**
- **유형별 14일 추세**(시계열) → 완료 **날짜**가 필요 → **백엔드 확장 필수**

### 2.6 스키마는 이미 충분하다

`path_weekly_tasks`에 `task_type VARCHAR(20) **NOT NULL** CHECK (READ/PRACTICE/QUIZ)`와 `completed_at TIMESTAMPTZ`(nullable)가 있다. **마이그레이션도 `devpath-shared` 발행도 불필요하다.**

정의 파일은 **`devpath-shared`** 소재다(`devpath-shared/src/main/resources/db/migration/V202606181006__learning_path_schema.sql:62,65`) — learning-svc 안에는 없다. `task_type`이 NOT NULL이라 유형별 집계에서 **null 키를 방어할 필요가 없다**(실측 확인).

## 3. 팔레트 재설계

### 3.1 원칙 — 브랜드에서 분리 (사용자 결정)

`chart1~3`을 앰버와 독립된 카테고리 색으로 재정의한다. **역할이 갈린다: 브랜드 액센트 = `primary`, 데이터 색 = `chart*`.**
`chart4`는 계열이 아니라 **구분용 보조색**으로 남긴다(현재 주석의 용도 유지 — 약점 태그 등).

### 3.2 합격 기준 (사용자 결정)

검증 스크립트가 다음을 전부 통과해야 한다. **하나라도 실패하면 색을 바꾼다.**

| # | 기준 | 값 | 이유 |
|---|---|---|---|
| 1 | 배경 대비 | `bg`·`surface` 각각 **≥ 3:1** | 면·선으로 쓰므로 비텍스트 대비 기준 |
| 2 | 색각 이상 시뮬 후 계열 간 dE76 | **≥ 20** | 적록 색각 이상에서도 갈린다(Okabe-Ito가 쓰는 방식) |
| 3 | 계열 간 hue차 | **≥ 40°** | 색상으로 갈린다 |
| 4 | `primary`와의 dE76 | **≥ 25** | 액센트와 데이터의 역할 분리 |
| 5 | 계열 간 명도 대비 | **기록만**(필수 아님) | §2.3 — 기준 1과 동시 충족 불가 |
| 6 | **의미 토큰·보조색과의 dE76** | `success`·`warning`·`danger`·`chart4`·`chart5` 각각 **≥ 25** | 아래 |

라이트·다크 **각각** 통과해야 한다.

### 3.2.1 ★기준 6이 필요한 이유 — 실측으로 발견★

후보 탐색 중 **통과 조합 1위가 기존 토큰과 값이 완전히 같은** 경우가 나왔다:

- 다크 초록 후보 `#4ADE80` = 다크 `success` **정확히 동일**
- 틸 후보 `#0F766E`·`#2DD4BF` = 현재 `chart4`의 라이트·다크 값 **정확히 동일**

이것은 3-A가 문제 삼은 `chart1 == primary` 중복과 **같은 부류의 결함**이다 — 「성공 상태」와 「실습 계열」이 같은 색이면 사용자가 의미를 분간할 수 없다. 기준 1~5만으로는 이 충돌이 걸러지지 않는다(전부 통과했다). 기준 6이 그것을 막는다.

`chart4`는 계열이 아니지만 같은 화면에 함께 나올 수 있으므로 포함한다.

**`chart5`(`#8B857D`, 라이트·다크 동일)도 포함한다** — 이 스펙 초안이 토큰의 **존재 자체를 빠뜨렸다**(구현 계획 검토 중 `dp_colors.dart:139,175`에서 발견). 지금은 어느 화면에도 배선돼 있지 않아 실해가 없고, 아래 후보값과 dE76 **50.5~101.7**로 여유 있게 통과한다(실측). 그래도 기준에 넣어 두는 이유는 배선되는 순간 §3.2.1이 말하는 바로 그 충돌 후보가 되기 때문이다.

### 3.3 후보와 알려진 문제

1차 후보(라이트 `#1D4ED8`/`#0F766E`/`#9D2C7E`, 다크 `#7BA9F5`/`#2DD4BF`/`#E879C7`)는 기준 1·3·4를 통과했고, 기준 2에서 **다크 `chart1`–`chart2`(파랑–틸)가 dE 19.5로 경계 미달**이었다. 파랑과 틸은 적록 색각 이상에서 가까워진다 — **그 쌍을 벌리는 것이 이번 색 선정의 핵심 제약이다.**

### 3.4 산출물

- `dp_colors.dart`의 라이트·다크 `chart1~3` 재정의(`chart4`는 유지)
- 검증 스크립트 `docs/superpowers/specs/2026-08-07-chart-palette-check.py` 신설 — 기존 대비 스크립트(`2026-08-03-token-contrast-check.py`)와 같은 방식으로 Task 게이트에서 실행한다. **`python`은 이 환경에서 스텁이므로 `py`로 실행한다.**
- 기존 대비 스크립트의 딕셔너리도 새 값으로 갱신한다 — **빠뜨리면 검증이 옛 값을 계속 통과시킨다**(3-A Task 3에서 실제로 걸렸던 함정).

## 4. 차트 4종

| 차트 | 위젯 | 현재 | 3-B |
|---|---|---|---|
| 주간 활동 | `weekly_activity_card.dart:99` | 7일 콘텐츠 완료 수, `c.primary` 단색 | **단일 계열 유지**, 색만 `c.chart1` |
| 진행률 추세 | `progress_trend_card.dart:63,68` | 14일 누적%, `c.primary` + alpha 0.12 채움 | **유형별 3선**(READ·PRACTICE·QUIZ) + 범례. **채움(`belowBarData`)은 제거한다** — 반투명 면 3장이 겹치면 색이 섞여 계열 판별이 오히려 나빠진다 |
| 전체 진행률 | `progress_donut.dart:33,39` | 완료 `c.primary` / 미완료 **`c.border`** | 의미 유지. 완료 `c.chart1`, 미완료 **`c.surfaceMuted`**(이미 있는 면 토큰 — 새 토큰을 만들지 않는다) |
| **주차별 진행률(신규)** | — | — | X축 = 마일스톤 `weekNum`, Y축 = 해당 주차 완료율(%). 단일 계열. `/paths/current`만으로 계산 |

### 4.1 계열 라벨

`READ`→`읽기`, `PRACTICE`→`실습`, `QUIZ`→`퀴즈`. **enum 원문은 데이터·전송에서 불변**이고 표시만 한국어다(3-A Task 14-2와 같은 규칙 — 라벨 맵의 키가 계약이다).

### 4.2 빈 상태

- 활성 경로가 없으면 진행률 추세·주차별 차트는 **빈 상태 안내**를 렌더한다(현재 `progressHistory`는 `totalTasks<=0`이면 빈 배열을 준다).
- 유형이 한 종류만 있는 경로에서는 계열이 1개가 된다 — 범례도 1개만 렌더돼야 한다.

## 5. 범례

`packages/dp_design/lib/src/data/dp_chart_legend.dart` 신설(Layer 2).

- 입력: `List<({Color color, String label})>` — **레코드 리스트 하나뿐이다. Widget 슬롯을 받지 않는다.** 3-A `DpRailBrand`에서 배운 대로, 앱이 스타일을 실을 통로를 애초에 만들지 않는다.
- 좁은 폭에서 `Wrap`으로 줄바꿈한다(3-A `DpPageHeader.filters`와 같은 방식).
- **진행률 추세에만 쓴다.** 주차별 차트는 단일 계열이라 범례를 두지 않는다 — 계열이 하나인 범례는 정보가 0이다.

## 6. 백엔드 확장 (`devpath-learning-svc`)

**범위는 진행률 추세 하나뿐이다.** 주차별 차트는 백엔드를 건드리지 않는다(§2.5).

- `ContentProgressRepository.activePathCompletions` — 완료일 목록을 **유형과 함께** 반환하도록 확장. 현재 `record ActivePathCompletions(int totalTasks, List<LocalDate> completedDates)`. 유형별 총 과제 수도 필요하다(분모가 유형마다 다르다).
- `DashboardTimeseries.progressHistory` — 유형별로 계산. 현재는 `(today, totalTasks, completedDates)` → `List<ProgressPoint>`.
- `ProgressPoint` — 유형별 퍼센트를 담는 형태로 확장.
- **`date`는 `String` ISO를 유지한다**(jsr310 미해결 회피 — 지난 시계열 작업과 동일한 이유).
- `DashboardTimeseries`는 **순수 로직·DB/시계 비의존**이라 결정적 단위 테스트가 이미 있다(`DashboardTimeseriesTest`). 확장도 같은 성격을 지킨다.

`dp_core`의 `DashboardSummary.progressHistory`·`ProgressPoint`를 대응 확장한다. **`devpath-shared` 발행은 불필요하다**(이 DTO는 learning-svc 로컬).

### 6.1 계약 호환성

`ProgressPoint`의 형태가 바뀌면 기존 웹이 깨진다. **백엔드를 먼저 머지하고 프론트가 따라가는 순서**로 하거나, 신규 필드를 optional로 더해 한 번에 간다 — 구현 계획에서 정한다.

## 7. 검증

### 7.1 자동

- `melos run analyze` 0 · `melos run format` clean · `melos run test` 전 패키지 green
  (3-A 종료 기준선: web **346** · dp_design **159**(melos는 `--exclude-tags golden`이라 157) · admin 72 · mobile 100 · dp_core 97)
- `./gradlew test` (learning-svc)
- **팔레트 검증 스크립트 통과**(§3.2 기준 전부) + 기존 대비 스크립트 미달 0건
- 차트 위젯 테스트: 계열 수·색 배정·범례 라벨·**빈 데이터·단일 유형** 커버

### 7.2 테스트가 조건을 피해 가지 않게

3-A에서 **같은 실패 유형을 세 번** 잡았다(2단계 「60자 crumbs」, Task 12 「android stretch 잔상」, Task 15 「path_title 자체 조립」). 이번 스펙은 다음을 요구한다:

- 계열이 3개인지 확인하는 테스트는 **fake 데이터에 유형 3종이 실제로 들어 있는지 산술로 검산**한다. 「유형별로 나눴다」를 *선언*하는 것과 조건이 *성립*하는 것은 다르다.
- 색 단언은 리터럴 hex가 아니라 **토큰 참조**(`DpColors.light.chart1`)로 쓴다 — 팔레트를 바꿔도 테스트가 함께 움직여야 한다. 단 **팔레트 값 자체를 고정하는 테스트는 리터럴로** 둔다(둘의 역할이 다르다 — 3-A admin 제목 단일 출처에서 배운 구조).
- 차트 위젯 테스트는 **렌더된 fl_chart 데이터 객체**를 읽어 단언한다(`find.text`로 우회하지 않는다).

### 7.3 육안 확인 — 독립 Task

3-A에서 실빌드 캡처가 실제로 결함을 잡았다. 다시 넣는다.

- 4폭 × 라이트·다크 × 대시보드·학습 경로
- **`wait --networkidle`만으로는 이르다** — 목 모드는 네트워크가 없어 즉시 만족되고 Flutter async 로딩은 그 뒤다. `$B js "new Promise(r => setTimeout(() => r(1), 4000))"`로 명시 대기(3-A 육안 확인 보고서 §1).
- 다크는 별도 빌드 + **포트 변경**으로 서비스워커 캐시 우회.
- **색 판정은 축소 스크린샷 인상이 아니라 토큰 값으로 한다**(3-A에서 다크 레일 분리감을 그렇게 오판했다).

## 8. 위험

| 위험 | 완화 |
|---|---|
| 색 후보가 §3.2 기준 5개를 동시에 만족하지 못한다 | 기준 2(색각 시뮬)를 최우선으로 두고 hue를 벌린다. 파랑–틸 쌍이 가장 위험(§3.3) |
| 팔레트 변경이 차트 외 소비처를 깬다 | `chart*` 사용처를 전수 조사한 뒤 바꾼다. `chart4`는 값을 유지해 보조 용도를 보호한다 |
| `ProgressPoint` 형태 변경이 웹을 깬다 | §6.1 — 머지 순서 또는 optional 필드. 계약 테스트를 먼저 세운다 |
| 3선이 겹쳐 오히려 읽기 어려워진다 | 채움(alpha) 제거·선 두께·범례로 완화. 육안 확인 Task에서 판정 |
| 유형이 1종뿐인 경로에서 범례·계열이 어색하다 | §4.2 — 빈 상태·단일 유형을 테스트로 고정 |

## 9. 산출물

- `dp_design`: `chart1~3` 재정의, `DpChartLegend` 신설, 도넛 미완료 면 토큰
- `dp_core`: `ProgressPoint`(유형별) 확장
- `apps/web`: 진행률 추세 다중 계열 + 범례, 주차별 진행률 카드 신설, 주간 활동·도넛 색 교체
- `learning-svc`: `activePathCompletions`·`progressHistory`·`ProgressPoint` 유형별 확장
- 문서: 팔레트 검증 스크립트, 대비 스크립트 갱신, `DESIGN.md` 차트 색 규칙
