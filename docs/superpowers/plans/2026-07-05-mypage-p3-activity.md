# 마이페이지 P3 — 활동 집계 API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`).
> **Phase P3 of** [2026-07-05-mypage-design.md](../specs/2026-07-05-mypage-design.md). 게이팅 없음(스토리지·④ 무관). learning·community 각 독립 svc·PR.

**Goal:** 마이페이지 활동 요약을 위해 learning에 완료 콘텐츠 수(dashboard 확장)와 community에 작성 질문/답변 수 API(`GET /community/me/activity`)를 추가한다.

**Architecture:** learning `ContentProgressRepository.countCompleted`로 `DashboardSummary`를 확장하고, community에 `ActivityController`(신규)가 `CommunityPost`/`CommunityAnswer` count를 노출한다. frontend(P4)가 합성한다.

**Tech Stack:** Spring Boot 4.0.7 · Java 21 · JPA/JdbcTemplate.

## Global Constraints

- **learning 테스트**: `@SpringBootTest @ActiveProfiles("test")` + `@Autowired ContentProgressRepository/JdbcTemplate`, `@BeforeEach` TRUNCATE, `seedUser(id)`/`upsert(...)` 패턴(ContentProgressRepositoryTest 참조). 완료 조건 = `scrollPct ≥ 0.8 && dwellSec ≥ 45`.
- **community 테스트**: `@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")` + `@Autowired MockMvc`, JWT = `.with(jwt().jwt(j -> j.subject("100")))`(SecurityMockMvcRequestPostProcessors), 미인증 401(QnaMockMvcTest 참조).
- **컨트롤러 인증**: `@AuthenticationPrincipal Jwt jwt` → `Long.parseLong(jwt.getSubject())`.
- **DB 의존**: 두 svc `@SpringBootTest`는 로컬 postgres(도커) 필요 — 로컬 부재 시 CI 검증.
- 브랜치: learning `feat/mypage-dashboard-count`, community `feat/mypage-community-activity`(각 base develop).

---

## Phase P3a — learning 완료 콘텐츠 수

### Task L1: ContentProgressRepository.countCompleted

**Files:**
- Modify: `devpath-learning-svc/src/main/java/ai/devpath/learning/content/ContentProgressRepository.java`
- Test: `devpath-learning-svc/src/test/java/ai/devpath/learning/content/ContentProgressRepositoryTest.java`

**Interfaces:**
- Produces: `int countCompleted(long userId)` — `user_content_progress` 중 `completed_at IS NOT NULL` 개수.

- [ ] **Step 1: 실패 테스트 추가**

`ContentProgressRepositoryTest.java`의 마지막 `@Test` 다음(닫는 `}` 앞, `private` 헬퍼들 위)에 추가:
```java
  @Test
  void countCompletedCountsOnlyCompletedRows() {
    long userId = uniqueId();
    seedUser(userId);
    long done = seedContent("repo-done", "BACKEND_SPRING", "PUBLISHED");
    long partial = seedContent("repo-partial", "BACKEND_SPRING", "PUBLISHED");

    progress.upsert(userId, done, 0.9, 60, SCROLL_THRESHOLD, MIN_DWELL_SEC); // 완료
    progress.upsert(userId, partial, 0.3, 10, SCROLL_THRESHOLD, MIN_DWELL_SEC); // 미완료

    assertThat(progress.countCompleted(userId)).isEqualTo(1);
  }
```

- [ ] **Step 2: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-learning-svc && ./gradlew test --tests '*ContentProgressRepositoryTest' --console=plain 2>&1 | tail -8`
Expected: 컴파일 실패(`countCompleted` 미존재). (도커 부재 시 컨텍스트 로드 실패로도 확인.)

- [ ] **Step 3: countCompleted 구현**

`ContentProgressRepository.java`의 `find(...)` 메서드 다음에 추가(import `java.util.Map`은 이미 있음):
```java
  public int countCompleted(long userId) {
    Integer n =
        jdbc.queryForObject(
            "SELECT count(*) FROM user_content_progress WHERE user_id = :userId AND completed_at IS NOT NULL",
            Map.of("userId", userId),
            Integer.class);
    return n == null ? 0 : n;
  }
```

- [ ] **Step 4: 통과 확인 + 커밋**

Run: `cd /d/workspace/dpa/devpath-learning-svc && ./gradlew test --tests '*ContentProgressRepositoryTest' --console=plain 2>&1 | tail -6`
Expected: PASS(도커 필요). 로컬 도커 부재면 Task L2의 `build -x test` + CI 검증.
```bash
cd /d/workspace/dpa/devpath-learning-svc
git add src/main/java/ai/devpath/learning/content/ContentProgressRepository.java src/test/java/ai/devpath/learning/content/ContentProgressRepositoryTest.java
git commit -m "feat(dashboard): ContentProgressRepository.countCompleted"
```

### Task L2: DashboardSummary.completedContentCount + build + PR

**Files:**
- Modify: `devpath-learning-svc/src/main/java/ai/devpath/learning/dashboard/DashboardSummary.java`
- Modify: `devpath-learning-svc/src/main/java/ai/devpath/learning/dashboard/DashboardService.java`

**Interfaces:**
- Consumes: `ContentProgressRepository.countCompleted`(Task L1).
- Produces: `DashboardSummary(int streakDays, int progressPercent, String nextTaskTitle, List<String> badges, int completedContentCount)`.

- [ ] **Step 1: DashboardSummary 필드 추가**

`DashboardSummary.java` 전체를 교체:
```java
package ai.devpath.learning.dashboard;

import java.util.List;

public record DashboardSummary(
    int streakDays,
    int progressPercent,
    String nextTaskTitle,
    List<String> badges,
    int completedContentCount
) {
}
```

- [ ] **Step 2: DashboardService에 ContentProgressRepository 주입 + 반영**

`DashboardService.java`:
- import 추가: `import ai.devpath.learning.content.ContentProgressRepository;`
- 필드 + 생성자 파라미터 추가: `private final ContentProgressRepository contentProgress;` (생성자 마지막 파라미터로 `ContentProgressRepository contentProgress` 추가 후 `this.contentProgress = contentProgress;`).
- `summary(long userId)` 안에서 `List<String> badges = ...` 다음 줄에:
```java
    int completedContentCount = contentProgress.countCompleted(userId);
```
- **두 `return new DashboardSummary(...)` 모두** 마지막 인자로 `completedContentCount` 추가:
  - early return(경로 없음): `return new DashboardSummary(streakDays, 0, null, badges, completedContentCount);`
  - 정상 return: `return new DashboardSummary(streakDays, progress, nextTask, badges, completedContentCount);`

- [ ] **Step 3: 빌드 + PR**

Run: `cd /d/workspace/dpa/devpath-learning-svc && ./gradlew build -x test --console=plain 2>&1 | tail -4`
Expected: `BUILD SUCCESSFUL`(컴파일+jar). `@SpringBootTest`는 CI 검증.
```bash
cd /d/workspace/dpa/devpath-learning-svc
git add src/main/java/ai/devpath/learning/dashboard/DashboardSummary.java src/main/java/ai/devpath/learning/dashboard/DashboardService.java
git commit -m "feat(dashboard): completedContentCount 추가 (마이페이지 P3)"
git push -u origin feat/mypage-dashboard-count
gh pr create --base develop --head feat/mypage-dashboard-count \
  --title "feat(dashboard): 마이페이지 P3 — 완료 콘텐츠 수" \
  --body "GET /dashboard/me에 completedContentCount 추가(ContentProgressRepository.countCompleted). 스펙 2026-07-05-mypage-design.md P3. 로컬 도커 부재 시 @SpringBootTest는 CI 검증."
```

---

## Phase P3b — community 활동 수

### Task C1: Repository countBy + ActivityController + 테스트

**Files:**
- Modify: `devpath-community-svc/src/main/java/ai/devpath/community/post/CommunityPostRepository.java`
- Modify: `devpath-community-svc/src/main/java/ai/devpath/community/post/CommunityAnswerRepository.java`
- Create: `devpath-community-svc/src/main/java/ai/devpath/community/post/dto/ActivityView.java`
- Create: `devpath-community-svc/src/main/java/ai/devpath/community/post/ActivityController.java`
- Test: `devpath-community-svc/src/test/java/ai/devpath/community/post/ActivityMockMvcTest.java`

**Interfaces:**
- Produces: `CommunityPostRepository.countByAuthorId(Long)`, `CommunityAnswerRepository.countByAuthorIdAndAiGeneratedFalse(Long)`; `ActivityView(long questionCount, long answerCount)`; `GET /community/me/activity` → `ActivityView`.

- [ ] **Step 1: 실패 테스트 작성**

`devpath-community-svc/src/test/java/ai/devpath/community/post/ActivityMockMvcTest.java`:
```java
package ai.devpath.community.post;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ActivityMockMvcTest {

  @Autowired MockMvc mvc;

  @Test
  void activityCountsAuthoredQuestionsAndHumanAnswers() throws Exception {
    // 유저 300: 질문 1개 작성
    String qBody =
        mvc.perform(
                post("/community/questions")
                    .with(jwt().jwt(j -> j.subject("300")))
                    .contentType("application/json")
                    .content("{\"title\":\"내 질문\",\"bodyMd\":\"b\",\"tags\":[]}"))
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString();
    long qid = JsonPath.parse(qBody).read("$.id", Long.class);

    // 유저 300: 자기 질문에 답변 1개(인간)
    mvc.perform(
            post("/community/questions/" + qid + "/answers")
                .with(jwt().jwt(j -> j.subject("300")))
                .contentType("application/json")
                .content("{\"bodyMd\":\"내 답변\"}"))
        .andExpect(status().isCreated());

    mvc.perform(get("/community/me/activity").with(jwt().jwt(j -> j.subject("300"))))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.questionCount").value(1))
        .andExpect(jsonPath("$.answerCount").value(1));
  }

  @Test
  void unauthenticatedRejected() throws Exception {
    mvc.perform(get("/community/me/activity")).andExpect(status().isUnauthorized());
  }
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-community-svc && ./gradlew test --tests '*ActivityMockMvcTest' --console=plain 2>&1 | tail -8`
Expected: 컴파일 실패(`ActivityController`·`countByAuthorId` 미존재).

- [ ] **Step 3: Repository count 메서드 추가**

`CommunityPostRepository.java`의 인터페이스 본문에 추가:
```java
  long countByAuthorId(Long authorId);
```

`CommunityAnswerRepository.java`의 인터페이스 본문에 추가:
```java
  long countByAuthorIdAndAiGeneratedFalse(Long authorId);
```

- [ ] **Step 4: ActivityView + ActivityController 작성**

`dto/ActivityView.java`:
```java
package ai.devpath.community.post.dto;

public record ActivityView(long questionCount, long answerCount) {}
```

`ActivityController.java`:
```java
package ai.devpath.community.post;

import ai.devpath.community.post.dto.ActivityView;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/community/me/activity")
public class ActivityController {

  private final CommunityPostRepository posts;
  private final CommunityAnswerRepository answers;

  public ActivityController(CommunityPostRepository posts, CommunityAnswerRepository answers) {
    this.posts = posts;
    this.answers = answers;
  }

  @GetMapping
  public ActivityView get(@AuthenticationPrincipal Jwt jwt) {
    long uid = Long.parseLong(jwt.getSubject());
    return new ActivityView(
        posts.countByAuthorId(uid), answers.countByAuthorIdAndAiGeneratedFalse(uid));
  }
}
```

- [ ] **Step 5: 통과 확인 + 커밋**

Run: `cd /d/workspace/dpa/devpath-community-svc && ./gradlew test --tests '*ActivityMockMvcTest' --console=plain 2>&1 | tail -6`
Expected: PASS(도커 필요). 로컬 도커 부재면 Task C2의 `build -x test` + CI.
```bash
cd /d/workspace/dpa/devpath-community-svc
git add src/main/java/ai/devpath/community/post/CommunityPostRepository.java src/main/java/ai/devpath/community/post/CommunityAnswerRepository.java src/main/java/ai/devpath/community/post/dto/ActivityView.java src/main/java/ai/devpath/community/post/ActivityController.java src/test/java/ai/devpath/community/post/ActivityMockMvcTest.java
git commit -m "feat(activity): GET /community/me/activity — 작성 질문/답변 수 (마이페이지 P3)"
```

### Task C2: build + PR

- [ ] **Step 1: 빌드 + PR**

Run: `cd /d/workspace/dpa/devpath-community-svc && ./gradlew build -x test --console=plain 2>&1 | tail -4`
Expected: `BUILD SUCCESSFUL`.
```bash
cd /d/workspace/dpa/devpath-community-svc
git push -u origin feat/mypage-community-activity
gh pr create --base develop --head feat/mypage-community-activity \
  --title "feat(activity): 마이페이지 P3 — 작성 질문/답변 수" \
  --body "GET /community/me/activity → {questionCount, answerCount}(countByAuthorId·인간 답변만). 스펙 2026-07-05-mypage-design.md P3. 로컬 도커 부재 시 @SpringBootTest는 CI 검증."
```

---

## Self-Review 결과

- **Spec 커버리지(P3)**: learning 완료수(dashboard 확장)→L1·L2, community 질문/답변수→C1. AI답변 제외(`countByAuthorIdAndAiGeneratedFalse`) 반영. ✅
- **플레이스홀더**: 실코드·실명령. 없음. ✅
- **타입 일관**: `countCompleted(long)→int`(L1 정의, L2 소비), `DashboardSummary`(+completedContentCount) L1·L2 일관. `ActivityView(long,long)`·`countByAuthorId(Long)→long` C1 내 일관. ✅
- **주의**: DashboardSummary 필드 추가 → 기존 소비처(frontend dashboard)는 추가 필드 무시(하위호환). `@SpringBootTest`는 도커 CI. ✅
- **범위**: P3(learning+community 집계)만. P2 avatar·P4 frontend는 별도. ✅
