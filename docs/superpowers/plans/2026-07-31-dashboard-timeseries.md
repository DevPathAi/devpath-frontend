# 대시보드 시계열 차트 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 학습자 대시보드에 주간 학습량 바차트와 진행률 추이 라인차트를 추가한다(기존 타임스탬프의 SQL 집계로 시계열 계약을 확장).

**Architecture:** 백엔드(`devpath-learning-svc`)는 `user_content_progress.completed_at`·`path_weekly_tasks.completed_at`(둘 다 `TIMESTAMPTZ`)를 KST 기준 일별로 집계하는 두 리포지토리 쿼리를 추가하고, 순수 Java 헬퍼로 7일 갭필·14일 누적율을 계산해 `DashboardSummary`에 2필드를 얹는다. 프론트(`devpath-frontend`)는 dp_core에 시계열 모델을 추가하고 `apps/web`에 fl_chart 기반 카드 2개를 Bento에 넣는다. `shared` 발행 불필요(계약이 learning-svc 로컬 record).

**Tech Stack:** Java 21 · Spring Boot 4 · NamedParameterJdbcTemplate · JUnit 5 + Mockito + AssertJ · Flutter Web · freezed/json_serializable · fl_chart 1.2.0 · flutter_test · melos.

## Global Constraints

- **TDD 필수**(CLAUDE.md 규칙 2): 각 기능은 실패 테스트 선작성 → 최소 구현 → 통과 확인. 테스트 없는 구현 변경 금지.
- **추측 금지**(규칙 1): 명세에 없는 코드 즉흥 구현 금지. 부족하면 멈추고 `NEEDS_CONTEXT` 보고.
- **JSON 키 계약(백엔드 ↔ dp_core 일치)**: `date`(ISO `yyyy-MM-dd` 문자열)·`completedCount`(int)·`percent`(int, 0~100)·`weeklyActivity`·`progressHistory`.
- **윈도우 고정값**: 주간 학습량 = **7일**(오늘 포함, 오름차순, 빈 날 0). 진행률 추이 = **14일**(활성 경로 없으면 빈 배열).
- **타임존**: 일별 버킷은 **KST(Asia/Seoul)**. `(completed_at AT TIME ZONE 'Asia/Seoul')::date`.
- **차트 위치**: `apps/web` 앱 레벨 위젯(dp_design 미변경, fl_chart 의존 격리). 기존 `ProgressDonut` 선례.
- **색상 alpha 관용구**: `c.primary.withValues(alpha: ...)`(코드베이스 표준, `withOpacity` 아님).
- **레포/브랜치**: 백엔드(Task 1~4)=`devpath-learning-svc` 브랜치 `feat/dashboard-timeseries`(Task 1에서 `develop`에서 분기) → 자체 `develop` PR. 프론트(Task 5~8)=`devpath-frontend` 브랜치 `feat/dashboard-timeseries`(이미 존재, spec/plan 커밋 보유) → 자체 `develop` PR. **모든 git은 `git -C <레포 절대경로>`**(에이전트 cwd 리셋 주의).
- **검증 게이트**: 백엔드 `./gradlew test`. 프론트 `melos run format`(커밋 전 필수, `--set-exit-if-changed`) → `melos run analyze` → `melos run test`.

## File Structure

**devpath-learning-svc** (패키지 `ai.devpath.learning`):
- `.../dashboard/DailyActivity.java` (신규 record) — 주간 학습량 1일치 DTO.
- `.../dashboard/ProgressPoint.java` (신규 record) — 진행률 추이 1점 DTO.
- `.../dashboard/DashboardSummary.java` (수정) — 2필드 추가.
- `.../dashboard/DashboardTimeseries.java` (신규) — 순수 계산 헬퍼(갭필·누적율).
- `.../content/ContentProgressRepository.java` (수정) — 집계 쿼리 2개 + `ActivePathCompletions` record.
- `.../dashboard/DashboardService.java` (수정) — 시계열 조립.
- 테스트: `DashboardSummaryJsonTest`(신규)·`DashboardTimeseriesTest`(신규)·`ContentProgressRepositoryTest`(수정)·`DashboardServiceTest`(수정).

**devpath-frontend**:
- `packages/dp_core/lib/src/models/dashboard_timeseries.dart` (신규) — `DailyActivity`·`ProgressPoint` freezed 모델.
- `packages/dp_core/lib/src/models/dashboard_summary.dart` (수정) — 2필드 추가.
- `packages/dp_core/lib/dp_core.dart` (수정) — 배럴 export.
- `apps/web/lib/src/features/dashboard/presentation/widgets/weekly_activity_card.dart` (신규) — BarChart 카드.
- `apps/web/lib/src/features/dashboard/presentation/widgets/progress_trend_card.dart` (신규) — LineChart 카드.
- `apps/web/lib/src/features/dashboard/presentation/widgets/dashboard_body.dart` (수정) — Bento에 카드 2개.
- `apps/web/lib/src/data/web_mock_fixtures.dart` (수정) — `/dashboard/me` 목에 시계열 샘플.
- 테스트: `dashboard_community_test.dart`(수정)·`weekly_activity_card_test.dart`(신규)·`progress_trend_card_test.dart`(신규)·`dashboard_body_test.dart`(수정).

---

## Task 1: 백엔드 계약 — 시계열 DTO + DashboardSummary 확장

**Repo:** `devpath-learning-svc`

**Files:**
- Create: `devpath-learning-svc/src/main/java/ai/devpath/learning/dashboard/DailyActivity.java`
- Create: `devpath-learning-svc/src/main/java/ai/devpath/learning/dashboard/ProgressPoint.java`
- Modify: `devpath-learning-svc/src/main/java/ai/devpath/learning/dashboard/DashboardSummary.java`
- Modify: `devpath-learning-svc/src/main/java/ai/devpath/learning/dashboard/DashboardService.java` (컴파일 유지용 빈 리스트)
- Test: `devpath-learning-svc/src/test/java/ai/devpath/learning/dashboard/DashboardSummaryJsonTest.java` (신규)

**Interfaces:**
- Produces: `record DailyActivity(LocalDate date, int completedCount)`, `record ProgressPoint(LocalDate date, int percent)`, `DashboardSummary(int streakDays, int progressPercent, String nextTaskTitle, List<String> badges, int completedContentCount, List<DailyActivity> weeklyActivity, List<ProgressPoint> progressHistory)`.

- [ ] **Step 1: 브랜치 분기(1회)**

```bash
git -C /d/workspace/dpa/devpath-learning-svc fetch origin --quiet
git -C /d/workspace/dpa/devpath-learning-svc checkout -b feat/dashboard-timeseries origin/develop
```

- [ ] **Step 2: 실패 테스트 작성** — `DashboardSummaryJsonTest.java`

계약(필드명·ISO 날짜)이 실제로 직렬화되는지 확정한다.

```java
package ai.devpath.learning.dashboard;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.json.JsonMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

class DashboardSummaryJsonTest {
  @Test
  void serializesTimeseriesWithIsoDatesAndContractFieldNames() throws Exception {
    JsonMapper mapper = JsonMapper.builder().addModule(new JavaTimeModule()).build();
    mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    DashboardSummary s = new DashboardSummary(7, 62, "다음 과제", List.of("배지"), 12,
        List.of(new DailyActivity(LocalDate.of(2026, 7, 31), 3)),
        List.of(new ProgressPoint(LocalDate.of(2026, 7, 31), 42)));

    String json = mapper.writeValueAsString(s);

    assertThat(json).contains("\"weeklyActivity\"").contains("\"completedCount\":3");
    assertThat(json).contains("\"progressHistory\"").contains("\"percent\":42");
    assertThat(json).contains("\"date\":\"2026-07-31\"");
  }
}
```

- [ ] **Step 3: 컴파일 실패 확인**

```bash
./gradlew -p /d/workspace/dpa/devpath-learning-svc test --tests '*DashboardSummaryJsonTest'
```
Expected: 컴파일 에러(`DailyActivity`·`ProgressPoint` 심볼 없음, `DashboardSummary` 생성자 인자 불일치).

- [ ] **Step 4: DTO record 2개 생성**

`DailyActivity.java`:
```java
package ai.devpath.learning.dashboard;

import java.time.LocalDate;

/** 주간 학습량 1일치. [date] KST 기준, [completedCount] 그 날 완료 콘텐츠 수. */
public record DailyActivity(LocalDate date, int completedCount) {}
```

`ProgressPoint.java`:
```java
package ai.devpath.learning.dashboard;

import java.time.LocalDate;

/** 진행률 추이 1점. [date] KST 기준, [percent] 0~100 누적 완료율. */
public record ProgressPoint(LocalDate date, int percent) {}
```

- [ ] **Step 5: `DashboardSummary`에 2필드 추가**

`DashboardSummary.java`를 다음으로 교체:
```java
package ai.devpath.learning.dashboard;

import java.util.List;

public record DashboardSummary(
    int streakDays,
    int progressPercent,
    String nextTaskTitle,
    List<String> badges,
    int completedContentCount,
    List<DailyActivity> weeklyActivity,
    List<ProgressPoint> progressHistory
) {
}
```

- [ ] **Step 6: `DashboardService` 생성자 호출부를 컴파일 유지용 빈 리스트로 갱신**

`DashboardService.java`의 두 `return new DashboardSummary(...)`에 `List.of(), List.of()`를 말미에 추가(실제 값은 Task 4에서). 파일 상단에 `import java.util.List;`가 이미 있음.
```java
    if (path == null) {
      return new DashboardSummary(streakDays, 0, null, badges, completedContentCount,
          List.of(), List.of());
    }
```
그리고 마지막 return:
```java
    return new DashboardSummary(streakDays, progress, nextTask, badges, completedContentCount,
        List.of(), List.of());
```

- [ ] **Step 7: 테스트 통과 확인**

```bash
./gradlew -p /d/workspace/dpa/devpath-learning-svc test --tests '*DashboardSummaryJsonTest' --tests '*DashboardServiceTest'
```
Expected: PASS(신규 직렬화 테스트 통과 + 기존 `DashboardServiceTest` 2개 여전히 통과 — 아직 시계열 미조립이라 빈 리스트).

- [ ] **Step 8: 커밋**

```bash
git -C /d/workspace/dpa/devpath-learning-svc add -A
git -C /d/workspace/dpa/devpath-learning-svc commit -m "feat(dashboard): 시계열 DTO(DailyActivity·ProgressPoint) + DashboardSummary 2필드 확장"
```

---

## Task 2: 백엔드 순수 시계열 계산 헬퍼

**Repo:** `devpath-learning-svc`

**Files:**
- Create: `devpath-learning-svc/src/main/java/ai/devpath/learning/dashboard/DashboardTimeseries.java`
- Test: `devpath-learning-svc/src/test/java/ai/devpath/learning/dashboard/DashboardTimeseriesTest.java` (신규)

**Interfaces:**
- Consumes: `DailyActivity`, `ProgressPoint` (Task 1).
- Produces: `DashboardTimeseries.weeklyActivity(LocalDate today, Map<LocalDate,Integer> countsByDate) -> List<DailyActivity>`; `DashboardTimeseries.progressHistory(LocalDate today, int totalTasks, List<LocalDate> completedDates) -> List<ProgressPoint>`; 상수 `ACTIVITY_DAYS=7`, `HISTORY_DAYS=14`.

- [ ] **Step 1: 실패 테스트 작성** — `DashboardTimeseriesTest.java`

```java
package ai.devpath.learning.dashboard;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class DashboardTimeseriesTest {
  private static final LocalDate TODAY = LocalDate.of(2026, 7, 31);

  @Test
  void weeklyActivityReturns7AscendingDaysFillingGapsWithZero() {
    Map<LocalDate, Integer> counts = Map.of(
        LocalDate.of(2026, 7, 31), 3,
        LocalDate.of(2026, 7, 29), 1);

    List<DailyActivity> out = DashboardTimeseries.weeklyActivity(TODAY, counts);

    assertThat(out).hasSize(7);
    assertThat(out.get(0).date()).isEqualTo(LocalDate.of(2026, 7, 25)); // today-6
    assertThat(out.get(6).date()).isEqualTo(TODAY);
    assertThat(out.get(6).completedCount()).isEqualTo(3);
    assertThat(out.get(4).completedCount()).isEqualTo(1); // 7/29
    assertThat(out.get(5).completedCount()).isEqualTo(0); // 7/30 갭
  }

  @Test
  void progressHistoryComputesCumulativePercentOver14Days() {
    // 전체 4개 과제 중 2개는 7/15(윈도우 시작 7/18 이전), 1개는 7/28 완료
    List<LocalDate> done = List.of(
        LocalDate.of(2026, 7, 15),
        LocalDate.of(2026, 7, 15),
        LocalDate.of(2026, 7, 28));

    List<ProgressPoint> out = DashboardTimeseries.progressHistory(TODAY, 4, done);

    assertThat(out).hasSize(14);
    assertThat(out.get(0).date()).isEqualTo(LocalDate.of(2026, 7, 18)); // today-13
    assertThat(out.get(0).percent()).isEqualTo(50);  // 2/4 by 7/18
    assertThat(out.get(13).percent()).isEqualTo(75); // 3/4 by 7/31
  }

  @Test
  void progressHistoryEmptyWhenNoActivePathTasks() {
    assertThat(DashboardTimeseries.progressHistory(TODAY, 0, List.of())).isEmpty();
  }
}
```

- [ ] **Step 2: 실패 확인**

```bash
./gradlew -p /d/workspace/dpa/devpath-learning-svc test --tests '*DashboardTimeseriesTest'
```
Expected: 컴파일 에러(`DashboardTimeseries` 없음).

- [ ] **Step 3: 헬퍼 구현** — `DashboardTimeseries.java`

```java
package ai.devpath.learning.dashboard;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** 대시보드 시계열 계산(순수 로직, DB·시계 비의존 → 결정적 단위 테스트 대상). */
final class DashboardTimeseries {
  static final int ACTIVITY_DAYS = 7;
  static final int HISTORY_DAYS = 14;

  private DashboardTimeseries() {}

  /** 최근 ACTIVITY_DAYS일(today 포함, 오름차순). 없는 날은 0. */
  static List<DailyActivity> weeklyActivity(LocalDate today, Map<LocalDate, Integer> countsByDate) {
    List<DailyActivity> out = new ArrayList<>(ACTIVITY_DAYS);
    for (int i = ACTIVITY_DAYS - 1; i >= 0; i--) {
      LocalDate d = today.minusDays(i);
      out.add(new DailyActivity(d, countsByDate.getOrDefault(d, 0)));
    }
    return out;
  }

  /** 최근 HISTORY_DAYS일 누적 완료율(%). totalTasks<=0이면 빈 배열. */
  static List<ProgressPoint> progressHistory(
      LocalDate today, int totalTasks, List<LocalDate> completedDates) {
    if (totalTasks <= 0) {
      return List.of();
    }
    List<ProgressPoint> out = new ArrayList<>(HISTORY_DAYS);
    for (int i = HISTORY_DAYS - 1; i >= 0; i--) {
      LocalDate d = today.minusDays(i);
      long done = completedDates.stream().filter(cd -> !cd.isAfter(d)).count();
      int percent = (int) Math.round(done * 100.0 / totalTasks);
      out.add(new ProgressPoint(d, percent));
    }
    return out;
  }
}
```

- [ ] **Step 4: 통과 확인**

```bash
./gradlew -p /d/workspace/dpa/devpath-learning-svc test --tests '*DashboardTimeseriesTest'
```
Expected: PASS(3개).

- [ ] **Step 5: 커밋**

```bash
git -C /d/workspace/dpa/devpath-learning-svc add -A
git -C /d/workspace/dpa/devpath-learning-svc commit -m "feat(dashboard): 시계열 순수 계산 헬퍼(7일 갭필·14일 누적율)"
```

---

## Task 3: 백엔드 집계 쿼리(리포지토리)

**Repo:** `devpath-learning-svc`

**Files:**
- Modify: `devpath-learning-svc/src/main/java/ai/devpath/learning/content/ContentProgressRepository.java`
- Test: `devpath-learning-svc/src/test/java/ai/devpath/learning/content/ContentProgressRepositoryTest.java` (기존 파일에 테스트 2개 추가 — private seed 헬퍼 재사용)

**Interfaces:**
- Produces: `ContentProgressRepository.dailyCompletedCounts(long userId, Instant since) -> Map<LocalDate,Integer>`(KST 날짜→완료 수); `ContentProgressRepository.activePathCompletions(long userId) -> ActivePathCompletions(int totalTasks, List<LocalDate> completedDates)`.

- [ ] **Step 1: 실패 테스트 2개 추가** — `ContentProgressRepositoryTest.java`의 `}` 직전(마지막 private 헬퍼 앞)에 삽입

```java
  @org.junit.jupiter.api.Test
  void dailyCompletedCountsBucketsTodayByKst() {
    long userId = uniqueId();
    seedUser(userId);
    long a = seedContent("ts-a", "BACKEND_SPRING", "PUBLISHED");
    long b = seedContent("ts-b", "BACKEND_SPRING", "PUBLISHED");
    progress.upsert(userId, a, 0.9, 60, SCROLL_THRESHOLD, MIN_DWELL_SEC);
    progress.upsert(userId, b, 0.9, 60, SCROLL_THRESHOLD, MIN_DWELL_SEC);

    Instant since = Instant.now().minus(java.time.Duration.ofDays(7));
    var counts = progress.dailyCompletedCounts(userId, since);

    java.time.LocalDate todayKst = java.time.LocalDate.now(java.time.ZoneId.of("Asia/Seoul"));
    assertThat(counts.get(todayKst)).isEqualTo(2);
  }

  @org.junit.jupiter.api.Test
  void activePathCompletionsReturnsTotalAndCompletedDates() {
    long userId = uniqueId();
    seedUser(userId);
    long content = seedContent("ts-path", "BACKEND_SPRING", "PUBLISHED");
    long path = seedPath(userId, "ACTIVE");
    seedTask(path, content, 1);
    seedTask(path, content, 2);
    progress.completeActivePathTasks(userId, content); // content_id 일치 과제 전부 완료

    var result = progress.activePathCompletions(userId);

    assertThat(result.totalTasks()).isEqualTo(2);
    assertThat(result.completedDates()).hasSize(2);
    assertThat(result.completedDates())
        .containsOnly(java.time.LocalDate.now(java.time.ZoneId.of("Asia/Seoul")));
  }
```

- [ ] **Step 2: 실패 확인**

```bash
./gradlew -p /d/workspace/dpa/devpath-learning-svc test --tests '*ContentProgressRepositoryTest'
```
Expected: 컴파일 에러(`dailyCompletedCounts`·`activePathCompletions`·`ActivePathCompletions` 없음).

- [ ] **Step 3: 리포지토리 메서드 구현** — `ContentProgressRepository.java`에 추가

파일 상단 import에 `java.time.LocalDate` 추가(`java.sql.ResultSet`·`java.sql.Timestamp`·`java.time.Instant`·`java.util.HashMap`·`java.util.List`·`java.util.Map`은 이미 존재). 클래스 안(예: `countCompleted` 아래)에 삽입:

```java
  /** 최근 완료 콘텐츠를 KST 일별로 집계(since 이후). 없는 날은 결과에 미포함. */
  public Map<LocalDate, Integer> dailyCompletedCounts(long userId, Instant since) {
    var sql = """
        SELECT (completed_at AT TIME ZONE 'Asia/Seoul')::date AS d, count(*) AS n
        FROM user_content_progress
        WHERE user_id = :userId AND completed_at IS NOT NULL AND completed_at >= :since
        GROUP BY d
        """;
    Map<LocalDate, Integer> out = new HashMap<>();
    jdbc.query(sql,
        Map.of("userId", userId, "since", Timestamp.from(since)),
        rs -> out.put(rs.getObject("d", LocalDate.class), rs.getInt("n")));
    return out;
  }

  /** 활성 경로 전체 과제 수 + 완료 과제의 KST 완료일 목록. */
  public ActivePathCompletions activePathCompletions(long userId) {
    var totalSql = """
        SELECT count(*) FROM path_weekly_tasks t
        JOIN path_milestones m ON m.id = t.milestone_id
        JOIN learning_paths p ON p.id = m.path_id
        WHERE p.user_id = :userId AND p.status = 'ACTIVE'
        """;
    Integer total = jdbc.queryForObject(totalSql, Map.of("userId", userId), Integer.class);
    var datesSql = """
        SELECT (t.completed_at AT TIME ZONE 'Asia/Seoul')::date AS d
        FROM path_weekly_tasks t
        JOIN path_milestones m ON m.id = t.milestone_id
        JOIN learning_paths p ON p.id = m.path_id
        WHERE p.user_id = :userId AND p.status = 'ACTIVE' AND t.completed_at IS NOT NULL
        """;
    List<LocalDate> dates = jdbc.query(datesSql, Map.of("userId", userId),
        (rs, rowNum) -> rs.getObject("d", LocalDate.class));
    return new ActivePathCompletions(total == null ? 0 : total, dates);
  }

  public record ActivePathCompletions(int totalTasks, List<LocalDate> completedDates) {}
```

- [ ] **Step 4: 통과 확인**(로컬 postgres 필요 — CI 또는 로컬 docker postgres)

```bash
./gradlew -p /d/workspace/dpa/devpath-learning-svc test --tests '*ContentProgressRepositoryTest'
```
Expected: PASS(기존 + 신규 2개). 로컬 DB 미기동이면 실패 로그로 확인 후 CI에 위임(플랜 상 이 Task의 SQL은 CI postgres에서 최종 검증).

- [ ] **Step 5: 커밋**

```bash
git -C /d/workspace/dpa/devpath-learning-svc add -A
git -C /d/workspace/dpa/devpath-learning-svc commit -m "feat(dashboard): 시계열 집계 쿼리(일별 완료 수·활성경로 완료일)"
```

---

## Task 4: 백엔드 조립 — DashboardService 시계열 채우기

**Repo:** `devpath-learning-svc`

**Files:**
- Modify: `devpath-learning-svc/src/main/java/ai/devpath/learning/dashboard/DashboardService.java`
- Test: `devpath-learning-svc/src/test/java/ai/devpath/learning/dashboard/DashboardServiceTest.java` (기존 2개 스텁 추가 + 신규 1개)

**Interfaces:**
- Consumes: `DashboardTimeseries.weeklyActivity/progressHistory`(Task 2), `ContentProgressRepository.dailyCompletedCounts/activePathCompletions`(Task 3).
- Produces: `GET /dashboard/me` 응답의 `weeklyActivity`(항상 7개)·`progressHistory`(활성 경로 시 14개, 아니면 빈 배열).

- [ ] **Step 1: 기존 테스트 스텁 추가 + 신규 실패 테스트 작성** — `DashboardServiceTest.java`

기존 두 테스트(`returnsZeroStreakWhenNoStreakRow`·`returnsActualStreakDaysWhenRowExists`)의 `ContentProgressRepository` 목 설정 뒤에 각각 아래 2줄을 추가한다(신규 메서드가 null 반환하지 않도록):
```java
    when(contentProgress.dailyCompletedCounts(eq(42L), org.mockito.ArgumentMatchers.any()))
        .thenReturn(java.util.Map.of());
    when(contentProgress.activePathCompletions(42L))
        .thenReturn(new ContentProgressRepository.ActivePathCompletions(0, List.of()));
```
(둘째 테스트는 `43L`로.)

그리고 신규 테스트 추가:
```java
  @Test
  void populatesWeeklyActivityAndEmptyProgressHistoryWhenNoActivePath() {
    LearningPathQueryService paths = mock(LearningPathQueryService.class);
    when(paths.currentOptional(44L)).thenReturn(Optional.empty());
    UserStreakRepository streaks = mock(UserStreakRepository.class);
    when(streaks.findById(44L)).thenReturn(Optional.empty());
    CommunityBadgeClient badges = mock(CommunityBadgeClient.class);
    when(badges.badgeNamesOf(44L)).thenReturn(List.of());
    ContentProgressRepository contentProgress = mock(ContentProgressRepository.class);
    when(contentProgress.countCompleted(44L)).thenReturn(0);
    when(contentProgress.dailyCompletedCounts(eq(44L), org.mockito.ArgumentMatchers.any()))
        .thenReturn(java.util.Map.of());
    when(contentProgress.activePathCompletions(44L))
        .thenReturn(new ContentProgressRepository.ActivePathCompletions(0, List.of()));

    DashboardService service = new DashboardService(paths, streaks, badges, contentProgress);
    DashboardSummary summary = service.summary(44L);

    assertThat(summary.weeklyActivity()).hasSize(7);
    assertThat(summary.progressHistory()).isEmpty();
  }
```

- [ ] **Step 2: 실패 확인**

```bash
./gradlew -p /d/workspace/dpa/devpath-learning-svc test --tests '*DashboardServiceTest'
```
Expected: FAIL(신규 테스트 — `weeklyActivity()`가 아직 빈 리스트라 size 0).

- [ ] **Step 3: `DashboardService.summary()` 조립**

import 추가: `import java.time.Instant;`, `import java.time.LocalDate;`, `import java.time.ZoneId;`. `summary()` 본문을 아래로 교체(path 분기 전에 시계열 계산):
```java
  @Transactional(readOnly = true)
  public DashboardSummary summary(long userId) {
    int streakDays = streaks.findById(userId).map(s -> s.getCurrentDays()).orElse(0);
    List<String> badges = badgeClient.badgeNamesOf(userId);
    int completedContentCount = contentProgress.countCompleted(userId);

    ZoneId seoul = ZoneId.of("Asia/Seoul");
    LocalDate today = LocalDate.now(seoul);
    Instant since = today.minusDays(DashboardTimeseries.ACTIVITY_DAYS - 1)
        .atStartOfDay(seoul).toInstant();
    List<DailyActivity> weeklyActivity = DashboardTimeseries.weeklyActivity(
        today, contentProgress.dailyCompletedCounts(userId, since));
    ContentProgressRepository.ActivePathCompletions pc =
        contentProgress.activePathCompletions(userId);
    List<ProgressPoint> progressHistory = DashboardTimeseries.progressHistory(
        today, pc.totalTasks(), pc.completedDates());

    LearningPathView path = paths.currentOptional(userId).orElse(null);
    if (path == null) {
      return new DashboardSummary(streakDays, 0, null, badges, completedContentCount,
          weeklyActivity, progressHistory);
    }

    List<WeeklyTaskView> tasks = path.milestones().stream()
        .flatMap(m -> m.tasks().stream())
        .toList();
    long completed = tasks.stream().filter(WeeklyTaskView::completed).count();
    int progress = tasks.isEmpty() ? 0 : (int) Math.round(completed * 100.0 / tasks.size());
    String nextTask = tasks.stream()
        .filter(t -> !t.completed())
        .findFirst()
        .map(WeeklyTaskView::title)
        .orElse(null);

    return new DashboardSummary(streakDays, progress, nextTask, badges, completedContentCount,
        weeklyActivity, progressHistory);
  }
```

- [ ] **Step 4: 통과 확인**

```bash
./gradlew -p /d/workspace/dpa/devpath-learning-svc test --tests '*DashboardServiceTest' --tests '*DashboardTimeseriesTest' --tests '*DashboardSummaryJsonTest'
```
Expected: PASS(전부).

- [ ] **Step 5: 커밋**

```bash
git -C /d/workspace/dpa/devpath-learning-svc add -A
git -C /d/workspace/dpa/devpath-learning-svc commit -m "feat(dashboard): DashboardService에 주간 학습량·진행률 추이 조립"
```

- [ ] **Step 6: 백엔드 전체 테스트 + PR**

```bash
./gradlew -p /d/workspace/dpa/devpath-learning-svc test
git -C /d/workspace/dpa/devpath-learning-svc push -u origin feat/dashboard-timeseries
```
그 후 `devpath-learning-svc` `feat/dashboard-timeseries` → `develop` PR 생성(제목 `feat(dashboard): 대시보드 시계열 계약 확장`). CI green + 사용자 승인 후 머지. **develop 직접 push 금지.**

---

## Task 5: dp_core 시계열 모델 + DashboardSummary 확장

**Repo:** `devpath-frontend` (브랜치 `feat/dashboard-timeseries` — 이미 체크아웃, spec/plan 보유)

**Files:**
- Create: `devpath-frontend/packages/dp_core/lib/src/models/dashboard_timeseries.dart`
- Modify: `devpath-frontend/packages/dp_core/lib/src/models/dashboard_summary.dart`
- Modify: `devpath-frontend/packages/dp_core/lib/dp_core.dart`
- Test: `devpath-frontend/packages/dp_core/test/models/dashboard_community_test.dart` (기존 파일에 테스트 추가)

**Interfaces:**
- Consumes: 백엔드 JSON 계약(`date`·`completedCount`·`percent`·`weeklyActivity`·`progressHistory`).
- Produces: dp_core `DailyActivity({required String date, int completedCount})`, `ProgressPoint({required String date, int percent})`, `DashboardSummary.weeklyActivity`·`progressHistory`.

- [ ] **Step 1: 실패 테스트 작성** — `dashboard_community_test.dart`의 `DashboardSummary 역직렬화` 테스트 바로 아래에 추가

```dart
  test('DashboardSummary 시계열 필드 역직렬화', () {
    final d = DashboardSummary.fromJson({
      'streakDays': 7,
      'progressPercent': 62,
      'nextTaskTitle': '비동기 기초',
      'badges': ['첫 경로'],
      'weeklyActivity': [
        {'date': '2026-07-30', 'completedCount': 1},
        {'date': '2026-07-31', 'completedCount': 3},
      ],
      'progressHistory': [
        {'date': '2026-07-31', 'percent': 42},
      ],
    });
    expect(d.weeklyActivity, hasLength(2));
    expect(d.weeklyActivity.last.date, '2026-07-31');
    expect(d.weeklyActivity.last.completedCount, 3);
    expect(d.progressHistory.single.percent, 42);
  });

  test('DashboardSummary 시계열 필드 부재 시 빈 리스트 기본값', () {
    final d = DashboardSummary.fromJson({
      'streakDays': 0,
      'progressPercent': 0,
      'badges': <String>[],
    });
    expect(d.weeklyActivity, isEmpty);
    expect(d.progressHistory, isEmpty);
  });
```

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/models/dashboard_community_test.dart
```
Expected: 컴파일 에러(`weeklyActivity` getter 없음).

- [ ] **Step 3: 시계열 모델 파일 생성** — `dashboard_timeseries.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_timeseries.freezed.dart';
part 'dashboard_timeseries.g.dart';

/// 주간 학습량 1일치(백엔드 `DailyActivity`). [date]=ISO 날짜(yyyy-MM-dd) 문자열.
@freezed
abstract class DailyActivity with _$DailyActivity {
  const factory DailyActivity({
    required String date,
    @Default(0) int completedCount,
  }) = _DailyActivity;

  factory DailyActivity.fromJson(Map<String, dynamic> json) =>
      _$DailyActivityFromJson(json);
}

/// 진행률 추이 1점(백엔드 `ProgressPoint`). [percent]=0~100.
@freezed
abstract class ProgressPoint with _$ProgressPoint {
  const factory ProgressPoint({
    required String date,
    @Default(0) int percent,
  }) = _ProgressPoint;

  factory ProgressPoint.fromJson(Map<String, dynamic> json) =>
      _$ProgressPointFromJson(json);
}
```

- [ ] **Step 4: `dashboard_summary.dart`에 2필드 추가**

파일을 아래로 교체(import + 2필드):
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'dashboard_timeseries.dart';

part 'dashboard_summary.freezed.dart';
part 'dashboard_summary.g.dart';

/// 대시보드 요약(DASH-001): 스트릭·진행률·다음 과제·배지 + 시계열.
@freezed
abstract class DashboardSummary with _$DashboardSummary {
  const factory DashboardSummary({
    required int streakDays,
    required int progressPercent,
    String? nextTaskTitle,
    @Default(<String>[]) List<String> badges,
    @Default(0) int completedContentCount,
    @Default(<DailyActivity>[]) List<DailyActivity> weeklyActivity,
    @Default(<ProgressPoint>[]) List<ProgressPoint> progressHistory,
  }) = _DashboardSummary;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      _$DashboardSummaryFromJson(json);
}
```

- [ ] **Step 5: 배럴 export 추가** — `dp_core.dart`

`export 'src/models/dashboard_summary.dart';` 바로 아래에 추가:
```dart
export 'src/models/dashboard_timeseries.dart';
```

- [ ] **Step 6: 코드 생성(freezed/json)**

```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart run build_runner build --delete-conflicting-outputs
```
Expected: `dashboard_timeseries.freezed.dart`·`.g.dart` 생성, `dashboard_summary.*` 갱신.

- [ ] **Step 7: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/models/dashboard_community_test.dart
```
Expected: PASS.

- [ ] **Step 8: 전 패키지 정적 분석(mobile 파급 확인)**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run analyze
```
Expected: web·admin·mobile·dp_core·dp_design 전부 통과(additive+기본값이라 mobile 컴파일 안전).

- [ ] **Step 9: 포맷 + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format
git -C /d/workspace/dpa/devpath-frontend add -A
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(dp_core): 대시보드 시계열 모델(DailyActivity·ProgressPoint) + DashboardSummary 확장"
```

---

## Task 6: web 주간 학습량 카드(BarChart)

**Repo:** `devpath-frontend`

**Files:**
- Create: `devpath-frontend/apps/web/lib/src/features/dashboard/presentation/widgets/weekly_activity_card.dart`
- Test: `devpath-frontend/apps/web/test/features/dashboard/weekly_activity_card_test.dart` (신규)

**Interfaces:**
- Consumes: dp_core `DailyActivity`(Task 5).
- Produces: `WeeklyActivityCard({required List<DailyActivity> activity})`. 데이터 있으면 `BarChart`, 전부 0이면 "아직 학습 기록이 없어요". 루트 `Key('weekly-activity-card')`.

- [ ] **Step 1: 실패 테스트 작성** — `weekly_activity_card_test.dart`

```dart
import 'package:devpath_web/src/features/dashboard/presentation/widgets/weekly_activity_card.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('WeeklyActivityCard: 데이터 있으면 BarChart 렌더', (tester) async {
    await tester.pumpWidget(_host(const WeeklyActivityCard(activity: [
      DailyActivity(date: '2026-07-25', completedCount: 1),
      DailyActivity(date: '2026-07-31', completedCount: 3),
    ])));
    await tester.pump();

    expect(find.text('주간 학습량'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('WeeklyActivityCard: 전부 0이면 빈 상태 안내', (tester) async {
    await tester.pumpWidget(_host(const WeeklyActivityCard(activity: [
      DailyActivity(date: '2026-07-30', completedCount: 0),
      DailyActivity(date: '2026-07-31', completedCount: 0),
    ])));
    await tester.pump();

    expect(find.text('아직 학습 기록이 없어요'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });
}
```

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/dashboard/weekly_activity_card_test.dart
```
Expected: 컴파일 에러(`WeeklyActivityCard` 없음).

- [ ] **Step 3: 카드 구현** — `weekly_activity_card.dart`

```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 주간 학습량 바차트(최근 7일 일별 완료 콘텐츠 수). fl_chart BarChart.
class WeeklyActivityCard extends StatelessWidget {
  const WeeklyActivityCard({super.key, required this.activity});

  final List<DailyActivity> activity;

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final hasData = activity.any((a) => a.completedCount > 0);
    return Container(
      key: const Key('weekly-activity-card'),
      padding: const EdgeInsets.all(DpSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('주간 학습량', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DpSpacing.lg),
              child: Text(
                '아직 학습 기록이 없어요',
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            )
          else
            SizedBox(height: 140, child: _chart(context)),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context) {
    final c = context.dpColors;
    final maxCount =
        activity.map((a) => a.completedCount).fold(0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxCount + 1).toDouble(),
        barTouchData: BarTouchData(enabled: true),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final label = (i >= 0 && i < activity.length)
                    ? _weekdayLabels[DateTime.parse(activity[i].date).weekday - 1]
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < activity.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: activity[i].completedCount.toDouble(),
                  color: c.primary,
                  width: 14,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/dashboard/weekly_activity_card_test.dart
```
Expected: PASS(2개).

- [ ] **Step 5: 포맷 + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format
git -C /d/workspace/dpa/devpath-frontend add -A
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(web): 주간 학습량 BarChart 카드"
```

---

## Task 7: web 진행률 추이 카드(LineChart)

**Repo:** `devpath-frontend`

**Files:**
- Create: `devpath-frontend/apps/web/lib/src/features/dashboard/presentation/widgets/progress_trend_card.dart`
- Test: `devpath-frontend/apps/web/test/features/dashboard/progress_trend_card_test.dart` (신규)

**Interfaces:**
- Consumes: dp_core `ProgressPoint`(Task 5).
- Produces: `ProgressTrendCard({required List<ProgressPoint> history})`. 비어있지 않으면 `LineChart`, 빈 배열이면 "아직 학습 기록이 없어요". 루트 `Key('progress-trend-card')`.

- [ ] **Step 1: 실패 테스트 작성** — `progress_trend_card_test.dart`

```dart
import 'package:devpath_web/src/features/dashboard/presentation/widgets/progress_trend_card.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('ProgressTrendCard: 데이터 있으면 LineChart 렌더', (tester) async {
    await tester.pumpWidget(_host(const ProgressTrendCard(history: [
      ProgressPoint(date: '2026-07-30', percent: 40),
      ProgressPoint(date: '2026-07-31', percent: 55),
    ])));
    await tester.pump();

    expect(find.text('진행률 추이'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('ProgressTrendCard: 빈 배열이면 빈 상태 안내', (tester) async {
    await tester.pumpWidget(
      _host(const ProgressTrendCard(history: [])),
    );
    await tester.pump();

    expect(find.text('아직 학습 기록이 없어요'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });
}
```

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/dashboard/progress_trend_card_test.dart
```
Expected: 컴파일 에러(`ProgressTrendCard` 없음).

- [ ] **Step 3: 카드 구현** — `progress_trend_card.dart`

```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 진행률 추이 라인차트(최근 14일 누적 완료율 %). fl_chart LineChart.
class ProgressTrendCard extends StatelessWidget {
  const ProgressTrendCard({super.key, required this.history});

  final List<ProgressPoint> history;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final hasData = history.isNotEmpty;
    return Container(
      key: const Key('progress-trend-card'),
      padding: const EdgeInsets.all(DpSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('진행률 추이', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DpSpacing.lg),
              child: Text(
                '아직 학습 기록이 없어요',
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            )
          else
            SizedBox(height: 140, child: _chart(context)),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context) {
    final c = context.dpColors;
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineTouchData: const LineTouchData(enabled: true),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < history.length; i++)
                FlSpot(i.toDouble(), history[i].percent.toDouble()),
            ],
            isCurved: true,
            color: c.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: c.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/dashboard/progress_trend_card_test.dart
```
Expected: PASS(2개).

- [ ] **Step 5: 포맷 + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format
git -C /d/workspace/dpa/devpath-frontend add -A
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(web): 진행률 추이 LineChart 카드"
```

---

## Task 8: Bento 통합 + 목 픽스처 + 대시보드 회귀 테스트

**Repo:** `devpath-frontend`

**Files:**
- Modify: `devpath-frontend/apps/web/lib/src/features/dashboard/presentation/widgets/dashboard_body.dart`
- Modify: `devpath-frontend/apps/web/lib/src/data/web_mock_fixtures.dart`
- Test: `devpath-frontend/apps/web/test/features/dashboard/dashboard_body_test.dart` (기존 파일에 테스트 추가)

**Interfaces:**
- Consumes: `WeeklyActivityCard`(Task 6), `ProgressTrendCard`(Task 7), `DashboardSummary.weeklyActivity`·`progressHistory`(Task 5).
- Produces: Bento에 두 카드 배치(Expanded 폭 각 2 span). 목 모드에서 실데이터 렌더.

- [ ] **Step 1: 실패 테스트 작성** — `dashboard_body_test.dart`

상단 `const _summary`를 시계열 포함으로 확장하고(기존 필드 유지), 신규 테스트 추가. `_summary` 정의를 아래로 교체:
```dart
const _summary = DashboardSummary(
  streakDays: 7,
  progressPercent: 62,
  nextTaskTitle: '비동기 프로그래밍 기초',
  badges: ['첫걸음', '3일 연속'],
  completedContentCount: 12,
  weeklyActivity: [
    DailyActivity(date: '2026-07-30', completedCount: 1),
    DailyActivity(date: '2026-07-31', completedCount: 3),
  ],
  progressHistory: [
    ProgressPoint(date: '2026-07-30', percent: 40),
    ProgressPoint(date: '2026-07-31', percent: 62),
  ],
);
```
그리고 신규 테스트 추가(파일 `main()` 안):
```dart
  testWidgets('DashboardBody: 시계열 카드 2개 렌더(Expanded 폭)', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(_summary));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekly-activity-card')), findsOneWidget);
    expect(find.byKey(const Key('progress-trend-card')), findsOneWidget);
  });
```

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/dashboard/dashboard_body_test.dart
```
Expected: FAIL(카드 key 미발견).

- [ ] **Step 3: `dashboard_body.dart`에 카드 2개 추가**

import 추가(파일 상단, `progress_donut.dart` import 옆):
```dart
import 'weekly_activity_card.dart';
import 'progress_trend_card.dart';
```
`_DonutCard` 타일 뒤(배지 타일 앞)에 두 타일 추가. `tiles` 리스트의 `_DonutCard` 타일 다음에 삽입:
```dart
      StaggeredGridTile.fit(
        crossAxisCellCount: donutSpan,
        child: WeeklyActivityCard(activity: summary.weeklyActivity),
      ),
      StaggeredGridTile.fit(
        crossAxisCellCount: donutSpan,
        child: ProgressTrendCard(history: summary.progressHistory),
      ),
```
(`donutSpan`은 기존 폭별 span 변수 재사용 — Expanded=2, medium=2, compact=1.)

- [ ] **Step 4: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/dashboard/dashboard_body_test.dart
```
Expected: PASS(기존 2개 + 신규 1개).

- [ ] **Step 5: 목 픽스처에 시계열 샘플 추가** — `web_mock_fixtures.dart`

`'GET /dashboard/me'` 항목의 맵에 두 키 추가(목 모드에서 차트가 실제로 그려지도록):
```dart
  'GET /dashboard/me': (
    200,
    {
      'streakDays': 7,
      'progressPercent': 62,
      'nextTaskTitle': '비동기 기초',
      'badges': ['첫 경로', '7일 연속'],
      'weeklyActivity': [
        {'date': '2026-07-25', 'completedCount': 0},
        {'date': '2026-07-26', 'completedCount': 2},
        {'date': '2026-07-27', 'completedCount': 1},
        {'date': '2026-07-28', 'completedCount': 3},
        {'date': '2026-07-29', 'completedCount': 0},
        {'date': '2026-07-30', 'completedCount': 2},
        {'date': '2026-07-31', 'completedCount': 4},
      ],
      'progressHistory': [
        {'date': '2026-07-28', 'percent': 40},
        {'date': '2026-07-29', 'percent': 48},
        {'date': '2026-07-30', 'percent': 55},
        {'date': '2026-07-31', 'percent': 62},
      ],
    },
  ),
```

- [ ] **Step 6: 프론트 전체 게이트**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format && dart pub global run melos run analyze && dart pub global run melos run test
```
Expected: format 무변경·analyze 통과·test 전부 PASS.

- [ ] **Step 7: 커밋 + 푸시 + PR**

```bash
git -C /d/workspace/dpa/devpath-frontend add -A
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(web): 대시보드 Bento에 시계열 카드 2개 통합 + 목 픽스처"
git -C /d/workspace/dpa/devpath-frontend push -u origin feat/dashboard-timeseries
```
그 후 `devpath-frontend` `feat/dashboard-timeseries` → `develop` PR(제목 `feat(web): 대시보드 시계열 차트`). CI(`analyze-test`) green + 사용자 승인 후 머지. **develop 직접 push 금지.**

---

## 통합 검증(양 레포 머지 후)

- 백엔드·프론트 PR 각각 CI green + 사용자 승인 → 머지(백엔드 먼저 권장, 계약 확정).
- 실서버 스모크(선택, AWS 재가동 시): `cd apps/web && flutter run -d chrome --dart-define-from-file=.env.local`로 `/dashboard/me` 실호출 → 두 차트 렌더 확인. 로컬 목 모드는 Task 8 픽스처로 즉시 확인 가능.
