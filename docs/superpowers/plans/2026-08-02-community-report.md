# 커뮤니티 신고 기능 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사용자가 글·답변·댓글을 신고하고, 관리자가 신고 목록을 보고 기각/처리완료로 판정할 수 있게 한다.

**Architecture:** 신고 데이터는 `community-svc`가 소유한다(대상 콘텐츠와 같은 DB라 관리자 목록을 단일 쿼리로 조립할 수 있다). 관리자 경로는 게이트웨이가 `/admin/**`를 platform-svc로 선점하므로 **`/community/admin/reports`**를 쓴다. 테이블은 `devpath-shared` 중앙 마이그레이션에 추가하며, 발행 전에는 community-svc 테스트가 돌지 않는다.

**Tech Stack:** Java 21 · Spring Boot 4.0.7 · Gradle Kotlin DSL · JPA · Flyway(shared) · JUnit 5 + AssertJ + MockMvc · Flutter Web · freezed · flutter_riverpod 3 · go_router · melos

**참조 spec:** `devpath-frontend/docs/superpowers/specs/2026-08-02-community-report-design.md` (커밋 `fefcece`)

## Global Constraints

- **레포 4곳**: `devpath-shared`(스키마) · `devpath-community-svc`(백엔드) · `devpath-frontend`(web+admin) · `documents`(명세). 각 레포 브랜치는 **`feat/community-report`**(documents는 `docs/community-report-api`), 각자 `develop`에서 분기해 `develop`으로 PR.
- **머지 순서**: shared → community-svc → frontend → documents. shared는 머지 후 **수동 발행**까지 해야 다음이 진행된다.
- **모든 git 명령은 `git -C <레포 절대경로>`**, gradle은 `cd <레포 절대경로> && ./gradlew ...`, flutter는 `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter ...` 형태로 **한 호출 안에서** 실행한다. 도구 호출 사이 cwd가 리셋된다.
- **TDD 필수**: 실패 테스트 선작성 → 최소 구현 → 통과 확인.
- **추측 금지**: 라이브러리 API·기존 클래스명을 상상해서 쓰지 않는다. 막히면 멈추고 `NEEDS_CONTEXT` 보고.
- **enum 값 고정**: `targetType` = `POST|ANSWER|COMMENT`, `category` = `SPAM|ABUSE|AD|DUPLICATE|INAPPROPRIATE|ETC`, `status` = `OPEN|RESOLVED|REJECTED`, `action` = `RESOLVE|REJECT`.
- **경로 고정**: 접수 `POST /community/reports` · 목록 `GET /community/admin/reports` · 판정 `POST /community/admin/reports/{id}/resolve`. **`/admin/reports`로 바꾸지 말 것** — 게이트웨이가 platform-svc로 보내 404가 된다.
- **`reason` 최대 500자**, 초과 시 400.
- **권한 테스트는 실제 서명 JWT**로 작성한다. `.with(jwt())` 후처리기는 authority를 직접 주입해 `SecurityConfig`의 `role`→`ROLE_*` 변환기를 우회하므로 권한을 검증하지 못한다.
- **건수 단언은 델타로**: 이 레포 테스트는 트랜잭션 롤백 없이 실 데이터를 적재한다. `int before = ...` 스냅샷 후 `before + N`을 단언한다.
- **테스트 DB 초기화**: 전체 스위트 실행 전 `docker exec dpa-test-pg dropdb -U devpath --if-exists devpath_citest && docker exec dpa-test-pg createdb -U devpath -O devpath devpath_citest` (기존 `ActivityMockMvcTest`·`VoteGateMockMvcTest`가 데이터 누적으로 flake).
- **게이트**: 백엔드 `./gradlew test`. 프론트 `melos run format` → `analyze` → `test`.

## File Structure

**devpath-shared**
- `src/main/resources/db/migration/V202608021001__community_reports.sql` (신규)

**devpath-community-svc** — 패키지 `ai.devpath.community.report` 신설
- `report/CommunityReport.java` (신규) — 엔티티
- `report/CommunityReportRepository.java` (신규)
- `report/ReportTargetType.java`·`ReportCategory.java`·`ReportStatus.java` (신규) — enum
- `report/ConflictException.java` (신규) — 409
- `report/ReportService.java` (신규) — 접수·조회·판정
- `report/ReportController.java` (신규) — `POST /community/reports`
- `report/AdminReportController.java` (신규) — 관리자 2종
- `report/dto/ReportRequest.java`·`ReportCreatedView.java`·`AdminReportView.java`·`AdminReportResponse.java`·`ResolveRequest.java` (신규)
- 테스트: `report/ReportServiceTest.java`·`ReportControllerTest.java`·`AdminReportServiceTest.java`·`AdminReportControllerTest.java`

**devpath-frontend**
- `packages/dp_core/lib/src/models/community_report.dart` (신규) + barrel export
- `apps/web/lib/src/features/community/data/community_source.dart` (수정) — `communityReportProvider`
- `apps/web/lib/src/features/community/presentation/widgets/report_dialog.dart` (신규)
- `apps/web/lib/src/features/community/presentation/widgets/report_menu_button.dart` (신규) — `⋮` 메뉴
- `apps/web/lib/src/features/community/presentation/qna_detail_page.dart`·`post_detail_page.dart` (수정)
- `apps/web/lib/src/data/web_mock_fixtures.dart` (수정)
- `apps/admin/lib/src/features/reports/{data/report.dart,application/reports_controller.dart,state/reports_state.dart,presentation/reports_page.dart}` (수정)
- `apps/admin/lib/src/data/admin_mock_fixtures.dart` (수정 — 실제 파일명은 Task 6 Step 1에서 확인)
- 테스트: `apps/web/test/features/community/report_test.dart`·`apps/admin/test/features/reports/reports_page_test.dart`

**documents**
- `04_API_명세서.md` (수정) — §8.1.2 신고

---

## Task 1: shared 마이그레이션 — `community_reports` 테이블

**Repo:** `devpath-shared`

**Files:**
- Create: `src/main/resources/db/migration/V202608021001__community_reports.sql`

**Interfaces:**
- Produces: 테이블 `community_reports`. Task 2~3의 엔티티가 이 스키마에 `ddl-auto: validate`로 대응한다.

- [ ] **Step 1: 브랜치 생성**

```bash
git -C D:/workspace/dpa/devpath-shared fetch origin
git -C D:/workspace/dpa/devpath-shared checkout develop
git -C D:/workspace/dpa/devpath-shared pull origin develop
git -C D:/workspace/dpa/devpath-shared checkout -b feat/community-report
git -C D:/workspace/dpa/devpath-shared status --short
```
Expected: clean, 브랜치 `feat/community-report`

- [ ] **Step 2: 마이그레이션 파일 작성**

Create `src/main/resources/db/migration/V202608021001__community_reports.sql`:

```sql
-- 커뮤니티 신고. 대상은 글·답변·댓글 3종이라 (target_type, target_id) 다형 참조를 쓴다.
-- 다형 참조라 FK 를 걸 수 없다 — 대상 삭제 시 신고는 남고, 조회 시 대상이 없으면
-- 애플리케이션이 "삭제된 콘텐츠"로 표시한다.
CREATE TABLE community_reports (
  id          BIGSERIAL PRIMARY KEY,
  reporter_id BIGINT      NOT NULL,
  target_type VARCHAR(16) NOT NULL,
  target_id   BIGINT      NOT NULL,
  category    VARCHAR(16) NOT NULL,
  reason      TEXT,
  status      VARCHAR(16) NOT NULL DEFAULT 'OPEN',
  reviewed_by BIGINT,
  reviewed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_community_reports_target CHECK (target_type IN ('POST','ANSWER','COMMENT')),
  CONSTRAINT chk_community_reports_category CHECK (category IN ('SPAM','ABUSE','AD','DUPLICATE','INAPPROPRIATE','ETC')),
  CONSTRAINT chk_community_reports_status CHECK (status IN ('OPEN','RESOLVED','REJECTED')),
  -- 1인 1회. 이 제약이 있어야 "몇 명이 신고했는가"가 심각도 신호가 된다.
  CONSTRAINT uq_community_reports_once UNIQUE (reporter_id, target_type, target_id)
);

-- 관리자 목록 기본 질의: status 필터 + 최신순.
CREATE INDEX idx_community_reports_status_created
  ON community_reports (status, created_at DESC);
```

`updated_at`·트리거는 두지 않는다 — 이 테이블은 판정 시점만 기록하면 되고 그건 `reviewed_at`이 담는다.

- [ ] **Step 3: 로컬 DB에 적용해 문법·제약 검증**

```bash
docker exec dpa-test-pg psql -U devpath -d devpath_citest -f - < D:/workspace/dpa/devpath-shared/src/main/resources/db/migration/V202608021001__community_reports.sql
docker exec dpa-test-pg psql -U devpath -d devpath_citest -c "\d community_reports"
```
Expected: 테이블 생성 성공, `\d` 출력에 `uq_community_reports_once`·`idx_community_reports_status_created` 표시

UNIQUE 제약이 실제로 막는지 확인한다:

```bash
docker exec dpa-test-pg psql -U devpath -d devpath_citest -c "INSERT INTO community_reports (reporter_id,target_type,target_id,category) VALUES (1,'POST',1,'SPAM');"
docker exec dpa-test-pg psql -U devpath -d devpath_citest -c "INSERT INTO community_reports (reporter_id,target_type,target_id,category) VALUES (1,'POST',1,'ABUSE');"
```
Expected: 첫 번째 `INSERT 0 1`, 두 번째 **`duplicate key value violates unique constraint "uq_community_reports_once"`**

CHECK 제약도 확인:
```bash
docker exec dpa-test-pg psql -U devpath -d devpath_citest -c "INSERT INTO community_reports (reporter_id,target_type,target_id,category) VALUES (2,'PHOTO',1,'SPAM');"
```
Expected: **`violates check constraint "chk_community_reports_target"`**

검증 후 테스트 데이터를 지운다:
```bash
docker exec dpa-test-pg psql -U devpath -d devpath_citest -c "DELETE FROM community_reports;"
```

- [ ] **Step 4: 커밋 · PR**

```bash
git -C D:/workspace/dpa/devpath-shared add src/main/resources/db/migration/V202608021001__community_reports.sql
git -C D:/workspace/dpa/devpath-shared commit -m "feat(report): community_reports 테이블 추가

커뮤니티 신고(글·답변·댓글). 대상이 3종이라 (target_type, target_id) 다형 참조를 쓰며
FK 는 걸 수 없다. UNIQUE (reporter_id, target_type, target_id) 로 1인 1회를 강제해
신고 수가 심각도 신호가 되게 한다.

로컬 검증: 테이블 생성 후 UNIQUE 위반·CHECK 위반이 실제로 거부되는 것을 확인."
git -C D:/workspace/dpa/devpath-shared push -u origin feat/community-report
```

PR 생성(base `develop`). CI 확인 후 **머지까지 진행한다** — 다음 Task가 막혀 있다.

- [ ] **Step 5: ★수동 발행**

머지 후 반드시 실행한다. main push 에만 자동 발행되므로 develop 머지만으로는 아무 일도 일어나지 않는다:

```bash
gh workflow run publish.yml --ref develop -R DevPathAi/devpath-shared
gh run list -R DevPathAi/devpath-shared --workflow publish.yml --limit 3
```

발행 완료를 기다린 뒤 community-svc 에서 의존을 새로 받아 테이블이 생기는지 확인한다:

```bash
docker exec dpa-test-pg dropdb -U devpath --if-exists devpath_citest
docker exec dpa-test-pg createdb -U devpath -O devpath devpath_citest
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*PostIndexBootstrapTest*" --refresh-dependencies
docker exec dpa-test-pg psql -U devpath -d devpath_citest -c "\d community_reports"
```
Expected: 테스트 통과 + `\d community_reports`가 테이블을 출력(= flyway가 새 마이그레이션을 적용했다)

**출력이 "Did not find any relation"이면 발행이 반영되지 않은 것이다.** 멈추고 `NEEDS_CONTEXT`로 보고하라 — 이후 Task가 전부 실패한다.

---

## Task 2: 신고 접수 API

**Repo:** `devpath-community-svc`

**Files:**
- Create: `src/main/java/ai/devpath/community/report/ReportTargetType.java`
- Create: `src/main/java/ai/devpath/community/report/ReportCategory.java`
- Create: `src/main/java/ai/devpath/community/report/ReportStatus.java`
- Create: `src/main/java/ai/devpath/community/report/ConflictException.java`
- Create: `src/main/java/ai/devpath/community/report/CommunityReport.java`
- Create: `src/main/java/ai/devpath/community/report/CommunityReportRepository.java`
- Create: `src/main/java/ai/devpath/community/report/ReportService.java`
- Create: `src/main/java/ai/devpath/community/report/dto/ReportRequest.java`
- Create: `src/main/java/ai/devpath/community/report/dto/ReportCreatedView.java`
- Create: `src/main/java/ai/devpath/community/report/ReportController.java`
- Test: `src/test/java/ai/devpath/community/report/ReportServiceTest.java`
- Test: `src/test/java/ai/devpath/community/report/ReportControllerTest.java`

**Interfaces:**
- Consumes: `CommunityPostRepository`·`CommunityAnswerRepository`·`CommunityCommentRepository`(기존, `ai.devpath.community.post`)
- Produces:
  - `CommunityReport ReportService.create(long reporterId, String targetType, Long targetId, String category, String reason)`
  - `CommunityReportRepository.existsByReporterIdAndTargetTypeAndTargetId(Long, String, Long)` → `boolean`
  - `CommunityReportRepository.countByTargetTypeAndTargetId(String, Long)` → `long`
  - `record ReportCreatedView(long id, String status)`
  Task 3이 같은 리포지토리·엔티티를 쓴다.

- [ ] **Step 1: 브랜치 생성**

```bash
git -C D:/workspace/dpa/devpath-community-svc fetch origin
git -C D:/workspace/dpa/devpath-community-svc checkout develop
git -C D:/workspace/dpa/devpath-community-svc pull origin develop
git -C D:/workspace/dpa/devpath-community-svc checkout -b feat/community-report
```

- [ ] **Step 2: enum·예외·엔티티·리포지토리 작성**

이들은 테스트가 컴파일되려면 먼저 있어야 한다(테스트 작성 전 최소 골격).

`ReportTargetType.java`:
```java
package ai.devpath.community.report;

/** 신고 대상 종류. DB CHECK 제약(chk_community_reports_target)과 값이 일치해야 한다. */
public enum ReportTargetType {
  POST, ANSWER, COMMENT
}
```

`ReportCategory.java`:
```java
package ai.devpath.community.report;

/** 신고 사유. DB CHECK 제약(chk_community_reports_category)과 값이 일치해야 한다. */
public enum ReportCategory {
  SPAM, ABUSE, AD, DUPLICATE, INAPPROPRIATE, ETC
}
```

`ReportStatus.java`:
```java
package ai.devpath.community.report;

/**
 * 신고 처리 상태. REJECTED(기각)를 RESOLVED(처리완료)와 분리해 둔다 — 이번 범위는 판정
 * 기록뿐이므로, 두 갈래 판단이 구분돼 남아야 나중에 조치·제재를 붙일 때 이력이 쓸모를 가진다.
 */
public enum ReportStatus {
  OPEN, RESOLVED, REJECTED
}
```

`ConflictException.java` — 기존 예외 관용구(`NotFoundException` 등)를 그대로 따른다:
```java
package ai.devpath.community.report;

import ai.devpath.shared.error.ApiException;
import ai.devpath.shared.error.ErrorCode;

/** 중복 신고 등 상태 충돌 → 스펙 §3.4 CONFLICT(409). 공용 ApiExceptionHandler가 envelope로 렌더. */
public class ConflictException extends ApiException {
  public ConflictException(String msg) {
    super(ErrorCode.CONFLICT, msg);
  }
}
```

`CommunityReport.java` — `CommunityPost` 엔티티 스타일(필드 + getter/setter, `created_at`은 DB 기본값):
```java
package ai.devpath.community.report;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "community_reports")
public class CommunityReport {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @Column(name = "reporter_id", nullable = false) private Long reporterId;
  @Column(name = "target_type", nullable = false) private String targetType;
  @Column(name = "target_id", nullable = false) private Long targetId;
  @Column(nullable = false) private String category;
  private String reason;
  @Column(nullable = false) private String status = "OPEN";
  @Column(name = "reviewed_by") private Long reviewedBy;
  @Column(name = "reviewed_at") private Instant reviewedAt;
  @Column(name = "created_at", insertable = false, updatable = false) private Instant createdAt;

  public Long getId() { return id; }
  public Long getReporterId() { return reporterId; }
  public void setReporterId(Long reporterId) { this.reporterId = reporterId; }
  public String getTargetType() { return targetType; }
  public void setTargetType(String targetType) { this.targetType = targetType; }
  public Long getTargetId() { return targetId; }
  public void setTargetId(Long targetId) { this.targetId = targetId; }
  public String getCategory() { return category; }
  public void setCategory(String category) { this.category = category; }
  public String getReason() { return reason; }
  public void setReason(String reason) { this.reason = reason; }
  public String getStatus() { return status; }
  public void setStatus(String status) { this.status = status; }
  public Long getReviewedBy() { return reviewedBy; }
  public void setReviewedBy(Long reviewedBy) { this.reviewedBy = reviewedBy; }
  public Instant getReviewedAt() { return reviewedAt; }
  public void setReviewedAt(Instant reviewedAt) { this.reviewedAt = reviewedAt; }
  public Instant getCreatedAt() { return createdAt; }
}
```

`CommunityReportRepository.java`:
```java
package ai.devpath.community.report;

import org.springframework.data.jpa.repository.JpaRepository;

public interface CommunityReportRepository extends JpaRepository<CommunityReport, Long> {
  boolean existsByReporterIdAndTargetTypeAndTargetId(Long reporterId, String targetType, Long targetId);

  /** 같은 대상의 총 신고 수. status 와 무관하다 — "이 글이 그동안 몇 번 신고됐는가"를 본다. */
  long countByTargetTypeAndTargetId(String targetType, Long targetId);
}
```

- [ ] **Step 3: 실패 테스트 작성 — 접수 서비스**

Create `src/test/java/ai/devpath/community/report/ReportServiceTest.java`.

기존 통합 테스트 스타일(`@SpringBootTest` + `@ActiveProfiles("test")` + 실제 postgres)을 따른다:

```java
package ai.devpath.community.report;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import ai.devpath.community.post.CommunityAnswer;
import ai.devpath.community.post.CommunityAnswerRepository;
import ai.devpath.community.post.CommunityComment;
import ai.devpath.community.post.CommunityCommentRepository;
import ai.devpath.community.post.CommunityPost;
import ai.devpath.community.post.CommunityPostRepository;
import ai.devpath.community.post.NotFoundException;
import ai.devpath.shared.error.ApiException;
import ai.devpath.shared.error.ErrorCode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/** 실제 postgres(devpath_citest) 대상. 신고 접수의 검증 계약을 고정한다. */
@SpringBootTest
@ActiveProfiles("test")
class ReportServiceTest {

  @Autowired ReportService service;
  @Autowired CommunityReportRepository reports;
  @Autowired CommunityPostRepository posts;
  @Autowired CommunityAnswerRepository answers;
  @Autowired CommunityCommentRepository comments;

  @Test
  void createsReportForPost() {
    CommunityPost p = savePost(100L);

    CommunityReport r = service.create(1L, "POST", p.getId(), "SPAM", "광고글입니다");

    assertEquals("OPEN", r.getStatus());
    assertEquals("POST", r.getTargetType());
    assertEquals(p.getId(), r.getTargetId());
    assertEquals("광고글입니다", r.getReason());
    assertTrue(reports.existsByReporterIdAndTargetTypeAndTargetId(1L, "POST", p.getId()));
  }

  @Test
  void rejectsDuplicateReportWithConflict() {
    CommunityPost p = savePost(100L);
    service.create(2L, "POST", p.getId(), "SPAM", null);

    ApiException e = assertThrows(ConflictException.class,
        () -> service.create(2L, "POST", p.getId(), "ABUSE", null));
    assertEquals(ErrorCode.CONFLICT, e.getErrorCode());
  }

  @Test
  void rejectsSelfReport() {
    CommunityPost p = savePost(55L);

    ApiException e = assertThrows(ApiException.class,
        () -> service.create(55L, "POST", p.getId(), "SPAM", null));
    assertEquals(ErrorCode.VALIDATION_FAILED, e.getErrorCode());
  }

  @Test
  void rejectsMissingTarget() {
    assertThrows(NotFoundException.class,
        () -> service.create(1L, "POST", 9_999_000_000L, "SPAM", null));
  }

  @Test
  void rejectsUnknownEnumValues() {
    CommunityPost p = savePost(100L);

    ApiException t = assertThrows(ApiException.class,
        () -> service.create(1L, "PHOTO", p.getId(), "SPAM", null));
    assertEquals(ErrorCode.VALIDATION_FAILED, t.getErrorCode());

    ApiException c = assertThrows(ApiException.class,
        () -> service.create(1L, "POST", p.getId(), "NONSENSE", null));
    assertEquals(ErrorCode.VALIDATION_FAILED, c.getErrorCode());
  }

  @Test
  void rejectsReasonOver500Chars() {
    CommunityPost p = savePost(100L);
    String tooLong = "가".repeat(501);

    ApiException e = assertThrows(ApiException.class,
        () -> service.create(1L, "POST", p.getId(), "SPAM", tooLong));
    assertEquals(ErrorCode.VALIDATION_FAILED, e.getErrorCode());
  }

  @Test
  void createsReportForAnswerAndComment() {
    CommunityPost p = savePost(100L);
    CommunityAnswer a = new CommunityAnswer();
    a.setQuestionId(p.getId());
    a.setAuthorId(200L);
    a.setBodyMd("답변 본문");
    a = answers.save(a);
    CommunityComment c = new CommunityComment();
    c.setPostId(p.getId());
    c.setAuthorId(300L);
    c.setBodyMd("댓글 본문");
    c = comments.save(c);

    assertEquals("ANSWER", service.create(1L, "ANSWER", a.getId(), "ABUSE", null).getTargetType());
    assertEquals("COMMENT", service.create(1L, "COMMENT", c.getId(), "ABUSE", null).getTargetType());
  }

  /** AI 시드 답변은 authorId 가 null 이다 — 자기신고 검사에서 NPE 가 나면 안 된다. */
  @Test
  void allowsReportingAiAnswerWithNullAuthor() {
    CommunityPost p = savePost(100L);
    CommunityAnswer ai = new CommunityAnswer();
    ai.setQuestionId(p.getId());
    ai.setAuthorId(null);
    ai.setBodyMd("AI 초안");
    ai.setAiGenerated(true);
    ai = answers.save(ai);

    assertEquals("OPEN", service.create(1L, "ANSWER", ai.getId(), "INAPPROPRIATE", null).getStatus());
  }

  private CommunityPost savePost(long authorId) {
    CommunityPost p = new CommunityPost();
    p.setAuthorId(authorId);
    p.setBoardType("FREE");
    p.setTitle("신고 대상 글");
    p.setBodyMd("본문");
    p.setStatus("PUBLISHED");
    return posts.save(p);
  }
}
```

- [ ] **Step 4: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*ReportServiceTest*"
```
Expected: FAIL — `ReportService` 클래스 없음(컴파일 에러)

- [ ] **Step 5: `ReportService` 구현**

```java
package ai.devpath.community.report;

import ai.devpath.community.post.CommunityAnswer;
import ai.devpath.community.post.CommunityAnswerRepository;
import ai.devpath.community.post.CommunityComment;
import ai.devpath.community.post.CommunityCommentRepository;
import ai.devpath.community.post.CommunityPost;
import ai.devpath.community.post.CommunityPostRepository;
import ai.devpath.community.post.NotFoundException;
import ai.devpath.shared.error.ApiException;
import ai.devpath.shared.error.ErrorCode;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

@Service
public class ReportService {

  private static final int REASON_MAX = 500;

  private final CommunityReportRepository reports;
  private final CommunityPostRepository posts;
  private final CommunityAnswerRepository answers;
  private final CommunityCommentRepository comments;

  public ReportService(CommunityReportRepository reports, CommunityPostRepository posts,
      CommunityAnswerRepository answers, CommunityCommentRepository comments) {
    this.reports = reports;
    this.posts = posts;
    this.answers = answers;
    this.comments = comments;
  }

  /**
   * 신고를 접수한다. 대상 존재·자기신고·중복을 <b>이 시점에</b> 검증한다 — 미루면 관리자
   * 목록에 유령 신고가 쌓여 목록 자체를 신뢰할 수 없게 된다.
   *
   * <p>{@code @Transactional} 을 붙이지 않는다. 저장이 단일 insert 라 필요 없고, 트랜잭션
   * 안에서 {@link DataIntegrityViolationException} 을 잡으면 rollback-only 로 마킹돼
   * 커밋 시점에 다시 터진다(이 프로젝트의 광고 기능에서 겪은 트랩).
   */
  public CommunityReport create(long reporterId, String targetType, Long targetId,
      String category, String reason) {
    ReportTargetType type = parseTargetType(targetType);
    ReportCategory cat = parseCategory(category);
    if (reason != null && reason.length() > REASON_MAX) {
      throw new InvalidReportException("사유는 " + REASON_MAX + "자를 넘을 수 없습니다.");
    }

    Long authorId = targetAuthorId(type, targetId);
    if (authorId != null && authorId == reporterId) {
      throw new InvalidReportException("본인이 작성한 콘텐츠는 신고할 수 없습니다.");
    }
    if (reports.existsByReporterIdAndTargetTypeAndTargetId(reporterId, type.name(), targetId)) {
      throw new ConflictException("이미 신고한 콘텐츠입니다.");
    }

    CommunityReport r = new CommunityReport();
    r.setReporterId(reporterId);
    r.setTargetType(type.name());
    r.setTargetId(targetId);
    r.setCategory(cat.name());
    r.setReason(reason);
    r.setStatus(ReportStatus.OPEN.name());
    try {
      return reports.save(r);
    } catch (DataIntegrityViolationException e) {
      // exists 검사와 save 사이의 경쟁. UNIQUE 제약이 최종 방어선이다.
      throw new ConflictException("이미 신고한 콘텐츠입니다.");
    }
  }

  /** 대상 작성자 id. 대상이 없으면 404. AI 시드 답변은 작성자가 null 일 수 있다. */
  private Long targetAuthorId(ReportTargetType type, Long targetId) {
    return switch (type) {
      case POST -> posts.findById(targetId).map(CommunityPost::getAuthorId)
          .orElseThrow(() -> new NotFoundException("신고 대상 글을 찾을 수 없습니다."));
      case ANSWER -> answers.findById(targetId).map(CommunityAnswer::getAuthorId)
          .orElseThrow(() -> new NotFoundException("신고 대상 답변을 찾을 수 없습니다."));
      case COMMENT -> comments.findById(targetId).map(CommunityComment::getAuthorId)
          .orElseThrow(() -> new NotFoundException("신고 대상 댓글을 찾을 수 없습니다."));
    };
  }

  private ReportTargetType parseTargetType(String raw) {
    try {
      return ReportTargetType.valueOf(raw);
    } catch (IllegalArgumentException | NullPointerException e) {
      throw new InvalidReportException("신고 대상 종류가 올바르지 않습니다: " + raw);
    }
  }

  private ReportCategory parseCategory(String raw) {
    try {
      return ReportCategory.valueOf(raw);
    } catch (IllegalArgumentException | NullPointerException e) {
      throw new InvalidReportException("신고 사유가 올바르지 않습니다: " + raw);
    }
  }
}
```

`InvalidReportException.java`도 함께 만든다(400):
```java
package ai.devpath.community.report;

import ai.devpath.shared.error.ApiException;
import ai.devpath.shared.error.ErrorCode;

/** 잘못된 신고 요청 → 스펙 §3.4 VALIDATION_FAILED(400). */
public class InvalidReportException extends ApiException {
  public InvalidReportException(String msg) {
    super(ErrorCode.VALIDATION_FAILED, msg);
  }
}
```

> `ApiException.getErrorCode()` 의 실제 메서드명을 **먼저 확인**하라(`javap` 또는 shared 소스). 테스트에서 `e.getErrorCode()`로 썼는데 다르면 테스트를 실제 이름에 맞춘다.

- [ ] **Step 6: 테스트 실행 — 통과 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*ReportServiceTest*" --rerun-tasks
```
Expected: PASS (8개 케이스). 결과 XML로 실제 실행 건수를 확인한다:
```bash
grep -o 'tests="[0-9]*" skipped="[0-9]*" failures="[0-9]*" errors="[0-9]*"' D:/workspace/dpa/devpath-community-svc/build/test-results/test/TEST-ai.devpath.community.report.ReportServiceTest.xml
```

- [ ] **Step 7: 실패 테스트 작성 — 접수 컨트롤러**

Create `src/test/java/ai/devpath/community/report/ReportControllerTest.java`. 기존 `SearchControllerTest` 스타일(`@SpringBootTest` + `@AutoConfigureMockMvc` + `@MockitoBean`):

```java
package ai.devpath.community.report;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ReportControllerTest {

  @Autowired MockMvc mvc;
  @MockitoBean ReportService service;

  @Test
  void createsReportAndReturns201() throws Exception {
    CommunityReport saved = new CommunityReport();
    saved.setStatus("OPEN");
    when(service.create(eq(1L), eq("POST"), eq(5L), eq("SPAM"), any())).thenReturn(saved);

    mvc.perform(post("/community/reports")
            .with(jwt().jwt(j -> j.subject("1")))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"targetType\":\"POST\",\"targetId\":5,\"category\":\"SPAM\",\"reason\":\"광고\"}"))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.status").value("OPEN"));
  }

  @Test
  void duplicateReportReturns409() throws Exception {
    when(service.create(anyLong(), any(), anyLong(), any(), any()))
        .thenThrow(new ConflictException("이미 신고한 콘텐츠입니다."));

    mvc.perform(post("/community/reports")
            .with(jwt().jwt(j -> j.subject("1")))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"targetType\":\"POST\",\"targetId\":5,\"category\":\"SPAM\"}"))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.error.code").value("CONFLICT"));
  }

  @Test
  void selfReportReturns400() throws Exception {
    when(service.create(anyLong(), any(), anyLong(), any(), any()))
        .thenThrow(new InvalidReportException("본인이 작성한 콘텐츠는 신고할 수 없습니다."));

    mvc.perform(post("/community/reports")
            .with(jwt().jwt(j -> j.subject("1")))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"targetType\":\"POST\",\"targetId\":5,\"category\":\"SPAM\"}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));
  }

  @Test
  void unauthenticatedReturns401() throws Exception {
    mvc.perform(post("/community/reports")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"targetType\":\"POST\",\"targetId\":5,\"category\":\"SPAM\"}"))
        .andExpect(status().isUnauthorized());
  }
}
```

- [ ] **Step 8: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*ReportControllerTest*"
```
Expected: FAIL — 컨트롤러가 없어 404

- [ ] **Step 9: DTO + 컨트롤러 구현**

`dto/ReportRequest.java`:
```java
package ai.devpath.community.report.dto;

/** 신고 접수 요청. reason 은 선택(최대 500자). */
public record ReportRequest(String targetType, Long targetId, String category, String reason) {}
```

`dto/ReportCreatedView.java`:
```java
package ai.devpath.community.report.dto;

public record ReportCreatedView(long id, String status) {}
```

`ReportController.java`:
```java
package ai.devpath.community.report;

import ai.devpath.community.report.dto.ReportCreatedView;
import ai.devpath.community.report.dto.ReportRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/community")
public class ReportController {

  private final ReportService service;

  public ReportController(ReportService service) {
    this.service = service;
  }

  @PostMapping("/reports")
  public ResponseEntity<ReportCreatedView> report(@AuthenticationPrincipal Jwt jwt,
      @RequestBody ReportRequest req) {
    long reporterId = Long.parseLong(jwt.getSubject());
    CommunityReport saved = service.create(
        reporterId, req.targetType(), req.targetId(), req.category(), req.reason());
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(new ReportCreatedView(saved.getId() == null ? 0L : saved.getId(), saved.getStatus()));
  }
}
```

> `@AuthenticationPrincipal Jwt` + `jwt.getSubject()`가 이 레포의 관용구인지 **기존 컨트롤러에서 확인**하고 맞춰라(`CommunityController.java:133` 부근에 사용처가 있다).

- [ ] **Step 10: 테스트 통과 확인 + 커밋**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*Report*" --rerun-tasks
```
Expected: PASS (서비스 8 + 컨트롤러 4)

```bash
git -C D:/workspace/dpa/devpath-community-svc add src/main/java/ai/devpath/community/report src/test/java/ai/devpath/community/report
git -C D:/workspace/dpa/devpath-community-svc commit -m "feat(report): 신고 접수 API — POST /community/reports

대상 존재·자기신고·중복·enum·사유 길이를 접수 시점에 검증한다. 미루면 관리자 목록에
유령 신고가 쌓여 목록을 신뢰할 수 없게 된다.

ReportService.create 에 @Transactional 을 붙이지 않았다 — 단일 insert 라 불필요하고,
트랜잭션 안에서 DataIntegrityViolationException 을 잡으면 rollback-only 트랩에 걸린다.
exists 검사와 save 사이의 경쟁은 UNIQUE 제약이 최종 방어선이며 그 예외를 409 로 변환한다.

AI 시드 답변(authorId=null)을 신고할 때 자기신고 검사에서 NPE 가 나지 않는지 테스트로 고정."
```

---

## Task 3: 관리자 목록·판정 API + 백엔드 PR

**Repo:** `devpath-community-svc`

**Files:**
- Create: `src/main/java/ai/devpath/community/report/dto/AdminReportView.java`
- Create: `src/main/java/ai/devpath/community/report/dto/AdminReportResponse.java`
- Create: `src/main/java/ai/devpath/community/report/dto/ResolveRequest.java`
- Modify: `src/main/java/ai/devpath/community/report/ReportService.java` — 목록·판정 추가
- Modify: `src/main/java/ai/devpath/community/report/CommunityReportRepository.java` — 조회 메서드 추가
- Create: `src/main/java/ai/devpath/community/report/AdminReportController.java`
- Test: `src/test/java/ai/devpath/community/report/AdminReportServiceTest.java`
- Test: `src/test/java/ai/devpath/community/report/AdminReportControllerTest.java`

**Interfaces:**
- Consumes: Task 2의 `CommunityReport`·`CommunityReportRepository`·`ReportService`
- Produces:
  - `record AdminReportView(long id, String targetType, long targetId, String targetTitle, String targetExcerpt, Long targetAuthorId, String targetPath, long reporterId, String category, String reason, long reportCount, String status, String createdAt)`
  - `record AdminReportResponse(List<AdminReportView> items, long total, int page, int size)`
  - `AdminReportResponse ReportService.list(String status, int page, int size)`
  - `CommunityReport ReportService.resolve(long reportId, long reviewerId, String action)`
  Task 6(admin 프론트)이 이 응답 형태를 소비한다.

- [ ] **Step 1: 리포지토리에 조회 메서드 추가**

`CommunityReportRepository`에 추가한다. `status`가 null이면 전체를 본다:

```java
  @org.springframework.data.jpa.repository.Query(
    "select r from CommunityReport r where (:status is null or r.status = :status) "
    + "order by r.createdAt desc, r.id desc")
  java.util.List<CommunityReport> findPage(String status,
      org.springframework.data.domain.Pageable pageable);

  @org.springframework.data.jpa.repository.Query(
    "select count(r) from CommunityReport r where (:status is null or r.status = :status)")
  long countFiltered(String status);
```

`createdAt` 동률 시 순서가 흔들리지 않도록 `id desc`를 2차 정렬로 둔다.

- [ ] **Step 2: 실패 테스트 작성 — 관리자 서비스**

Create `src/test/java/ai/devpath/community/report/AdminReportServiceTest.java`:

```java
package ai.devpath.community.report;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import ai.devpath.community.post.CommunityPost;
import ai.devpath.community.post.CommunityPostRepository;
import ai.devpath.community.report.dto.AdminReportResponse;
import ai.devpath.community.report.dto.AdminReportView;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * 관리자 목록·판정. 이 레포 테스트는 트랜잭션 롤백 없이 실 데이터를 적재하므로 절대 건수를
 * 단언하지 않고 <b>생성 전 스냅샷 + 델타</b>로 검증한다.
 */
@SpringBootTest
@ActiveProfiles("test")
class AdminReportServiceTest {

  @Autowired ReportService service;
  @Autowired CommunityReportRepository reports;
  @Autowired CommunityPostRepository posts;

  @Test
  void listAssemblesTargetInfo() {
    CommunityPost p = savePost("QNA", "신고당한 질문", "본문 내용입니다");
    service.create(1L, "POST", p.getId(), "SPAM", "광고");

    AdminReportView v = findByTarget(p.getId());

    assertEquals("신고당한 질문", v.targetTitle());
    assertTrue(v.targetExcerpt().contains("본문"));
    assertEquals("/community/" + p.getId(), v.targetPath(), "QNA 는 /community/{id}");
    assertEquals("SPAM", v.category());
    assertEquals("OPEN", v.status());
  }

  @Test
  void freeBoardTargetPathUsesPostRoute() {
    CommunityPost p = savePost("FREE", "자유글", "본문");
    service.create(1L, "POST", p.getId(), "AD", null);

    assertEquals("/community/post/" + p.getId(), findByTarget(p.getId()).targetPath());
  }

  @Test
  void reportCountAggregatesAllReportersRegardlessOfStatus() {
    CommunityPost p = savePost("FREE", "여러 명이 신고한 글", "본문");
    service.create(11L, "POST", p.getId(), "SPAM", null);
    service.create(12L, "POST", p.getId(), "ABUSE", null);
    CommunityReport third = service.create(13L, "POST", p.getId(), "AD", null);
    service.resolve(third.getId(), 99L, "REJECT"); // 처리된 신고도 세어야 한다

    assertEquals(3, findByTarget(p.getId()).reportCount());
  }

  @Test
  void statusFilterSelectsOnlyMatching() {
    long openBefore = service.list("OPEN", 0, 100).total();
    CommunityPost p = savePost("FREE", "필터 대상", "본문");
    CommunityReport r = service.create(21L, "POST", p.getId(), "SPAM", null);

    assertEquals(openBefore + 1, service.list("OPEN", 0, 100).total());

    service.resolve(r.getId(), 99L, "RESOLVE");

    assertEquals(openBefore, service.list("OPEN", 0, 100).total(),
        "처리 후에는 OPEN 목록에서 빠져야 한다");
  }

  @Test
  void sizeIsClampedTo100() {
    AdminReportResponse res = service.list(null, 0, 9999);
    assertEquals(100, res.size(), "응답 size 는 실제 적용값이어야 한다");
    assertTrue(res.items().size() <= 100);
  }

  @Test
  void resolveRecordsReviewerAndTimestamp() {
    CommunityPost p = savePost("FREE", "처리 대상", "본문");
    CommunityReport r = service.create(31L, "POST", p.getId(), "SPAM", null);

    CommunityReport done = service.resolve(r.getId(), 77L, "RESOLVE");

    assertEquals("RESOLVED", done.getStatus());
    assertEquals(77L, done.getReviewedBy());
    assertNotNull(done.getReviewedAt());
  }

  @Test
  void rejectRecordsRejectedStatus() {
    CommunityPost p = savePost("FREE", "기각 대상", "본문");
    CommunityReport r = service.create(32L, "POST", p.getId(), "SPAM", null);

    assertEquals("REJECTED", service.resolve(r.getId(), 77L, "REJECT").getStatus());
  }

  @Test
  void resolvingTwiceIsConflict() {
    CommunityPost p = savePost("FREE", "중복 처리", "본문");
    CommunityReport r = service.create(33L, "POST", p.getId(), "SPAM", null);
    service.resolve(r.getId(), 77L, "RESOLVE");

    assertThrows(ConflictException.class, () -> service.resolve(r.getId(), 77L, "REJECT"));
  }

  @Test
  void unknownActionIsRejected() {
    CommunityPost p = savePost("FREE", "잘못된 액션", "본문");
    CommunityReport r = service.create(34L, "POST", p.getId(), "SPAM", null);

    assertThrows(InvalidReportException.class, () -> service.resolve(r.getId(), 77L, "DELETE"));
  }

  @Test
  void missingTargetLeavesTitleNull() {
    CommunityPost p = savePost("FREE", "곧 사라질 글", "본문");
    CommunityReport r = service.create(41L, "POST", p.getId(), "SPAM", null);
    posts.deleteById(p.getId());

    AdminReportView v = service.list(null, 0, 100).items().stream()
        .filter(i -> i.id() == r.getId()).findFirst().orElseThrow();

    assertNull(v.targetTitle(), "삭제된 대상은 제목이 null 이어야 한다");
    assertNull(v.targetPath(), "이동 링크도 없어야 한다");
  }

  private AdminReportView findByTarget(long targetId) {
    return service.list(null, 0, 100).items().stream()
        .filter(i -> i.targetId() == targetId).findFirst().orElseThrow();
  }

  private CommunityPost savePost(String board, String title, String body) {
    CommunityPost p = new CommunityPost();
    p.setAuthorId(500L);
    p.setBoardType(board);
    p.setTitle(title);
    p.setBodyMd(body);
    p.setStatus("PUBLISHED");
    return posts.save(p);
  }
}
```

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*AdminReportServiceTest*"
```
Expected: FAIL — `ReportService.list`/`resolve` 없음(컴파일 에러)

- [ ] **Step 4: DTO 작성**

`dto/AdminReportView.java`:
```java
package ai.devpath.community.report.dto;

/**
 * 관리자 목록 항목. 신고와 대상 콘텐츠가 같은 DB 에 있어 한 번에 조립한다.
 *
 * <p>{@code targetPath} 는 서버가 준다 — 프론트가 QNA/일반글 경로 규칙을 중복 구현하지
 * 않게 하기 위해서다. 대상이 삭제됐으면 {@code targetTitle}·{@code targetPath} 가 null 이다.
 */
public record AdminReportView(
    long id,
    String targetType,
    long targetId,
    String targetTitle,
    String targetExcerpt,
    Long targetAuthorId,
    String targetPath,
    long reporterId,
    String category,
    String reason,
    long reportCount,
    String status,
    String createdAt) {}
```

`dto/AdminReportResponse.java`:
```java
package ai.devpath.community.report.dto;

import java.util.List;

/** 검색 API 와 같은 envelope 형태. */
public record AdminReportResponse(List<AdminReportView> items, long total, int page, int size) {}
```

`dto/ResolveRequest.java`:
```java
package ai.devpath.community.report.dto;

/** action = RESOLVE | REJECT. */
public record ResolveRequest(String action) {}
```

- [ ] **Step 5: `ReportService`에 목록·판정 추가**

기존 import에 더해 `java.time.Instant`, `java.util.List`, `java.util.Optional`, `java.util.stream.Collectors`, `org.springframework.data.domain.PageRequest`, `ai.devpath.community.post.Excerpts`, dto 3종을 추가한다.

> `Excerpts` 는 이 레포에 이미 있는 발췌 헬퍼다(검색·목록이 쓴다). 정확한 패키지·시그니처를 **먼저 확인**하고 쓰라(`grep -rn "class Excerpts" src/main`).

```java
  private static final int SIZE_MAX = 100;

  /** 관리자 목록. status 가 null 이면 전체. size 는 100 으로 클램프한다(검색 API 와 동일 규칙). */
  public AdminReportResponse list(String status, int page, int size) {
    int p = Math.max(page, 0);
    int s = Math.min(Math.max(size, 1), SIZE_MAX);
    List<CommunityReport> rows = reports.findPage(status, PageRequest.of(p, s));
    List<AdminReportView> items = rows.stream().map(this::toAdminView).collect(Collectors.toList());
    return new AdminReportResponse(items, reports.countFiltered(status), p, s);
  }

  private AdminReportView toAdminView(CommunityReport r) {
    ReportTargetType type = ReportTargetType.valueOf(r.getTargetType());
    // 답변·댓글은 부모 글을 찾아 그 경로를 준다.
    Optional<CommunityPost> parent = switch (type) {
      case POST -> posts.findById(r.getTargetId());
      case ANSWER -> answers.findById(r.getTargetId())
          .flatMap(a -> posts.findById(a.getQuestionId()));
      case COMMENT -> comments.findById(r.getTargetId())
          .flatMap(c -> posts.findById(c.getPostId()));
    };
    String title = parent.map(CommunityPost::getTitle).orElse(null);
    String path = parent.map(this::pathOf).orElse(null);
    String excerpt = switch (type) {
      case POST -> parent.map(x -> Excerpts.from(x.getBodyMd(), 140)).orElse(null);
      case ANSWER -> answers.findById(r.getTargetId())
          .map(a -> Excerpts.from(a.getBodyMd(), 140)).orElse(null);
      case COMMENT -> comments.findById(r.getTargetId())
          .map(c -> Excerpts.from(c.getBodyMd(), 140)).orElse(null);
    };
    Long authorId = switch (type) {
      case POST -> parent.map(CommunityPost::getAuthorId).orElse(null);
      case ANSWER -> answers.findById(r.getTargetId()).map(CommunityAnswer::getAuthorId).orElse(null);
      case COMMENT -> comments.findById(r.getTargetId()).map(CommunityComment::getAuthorId).orElse(null);
    };
    return new AdminReportView(
        r.getId(), r.getTargetType(), r.getTargetId(), title, excerpt, authorId, path,
        r.getReporterId(), r.getCategory(), r.getReason(),
        reports.countByTargetTypeAndTargetId(r.getTargetType(), r.getTargetId()),
        r.getStatus(), r.getCreatedAt() == null ? null : r.getCreatedAt().toString());
  }

  /** QNA 는 /community/{id}, 그 외 보드는 /community/post/{id}. 프론트 라우터 규칙과 일치한다. */
  private String pathOf(CommunityPost p) {
    return "QNA".equals(p.getBoardType())
        ? "/community/" + p.getId()
        : "/community/post/" + p.getId();
  }

  /** 판정. 이미 처리된 신고를 다시 처리하면 409. */
  public CommunityReport resolve(long reportId, long reviewerId, String action) {
    ReportStatus next = switch (action == null ? "" : action) {
      case "RESOLVE" -> ReportStatus.RESOLVED;
      case "REJECT" -> ReportStatus.REJECTED;
      default -> throw new InvalidReportException("처리 방식이 올바르지 않습니다: " + action);
    };
    CommunityReport r = reports.findById(reportId)
        .orElseThrow(() -> new NotFoundException("신고를 찾을 수 없습니다."));
    if (!ReportStatus.OPEN.name().equals(r.getStatus())) {
      throw new ConflictException("이미 처리된 신고입니다.");
    }
    r.setStatus(next.name());
    r.setReviewedBy(reviewerId);
    r.setReviewedAt(Instant.now());
    return reports.save(r);
  }
```

- [ ] **Step 6: 테스트 통과 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*AdminReportServiceTest*" --rerun-tasks
```
Expected: PASS (10개 케이스)

- [ ] **Step 7: 실패 테스트 작성 — 관리자 컨트롤러(권한)**

Create `src/test/java/ai/devpath/community/report/AdminReportControllerTest.java`.

**`jwt()` 후처리기를 쓰지 않는다** — authority 를 직접 주입해 `SecurityConfig` 의 `role`→`ROLE_*` 변환기를 우회하므로 "role=ADMIN 토큰이 실제로 통과하는가"를 검증하지 못한다. nimbus 로 실제 서명 JWT 를 만든다(`AdminSearchControllerTest`와 같은 방식):

```java
package ai.devpath.community.report;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import ai.devpath.community.report.dto.AdminReportResponse;
import ai.devpath.community.report.dto.AdminReportView;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminReportControllerTest {

  @Value("${devpath.auth.jwt-secret}") String secret;

  @Autowired MockMvc mvc;
  @MockitoBean ReportService service;

  @Test
  void listReturnsEnvelopeForAdmin() throws Exception {
    AdminReportView v = new AdminReportView(5L, "POST", 1L, "제목", "발췌", 7L,
        "/community/1", 3L, "SPAM", "광고", 2L, "OPEN", "2026-08-02T00:00:00Z");
    when(service.list(any(), anyInt(), anyInt()))
        .thenReturn(new AdminReportResponse(List.of(v), 1, 0, 20));

    mvc.perform(get("/community/admin/reports?status=OPEN")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenWithRole("ADMIN")))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.items[0].targetTitle").value("제목"))
        .andExpect(jsonPath("$.items[0].reportCount").value(2))
        .andExpect(jsonPath("$.total").value(1));
  }

  @Test
  void listIsForbiddenForNonAdmin() throws Exception {
    mvc.perform(get("/community/admin/reports")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenWithRole("LEARNER")))
        .andExpect(status().isForbidden());

    verify(service, never()).list(any(), anyInt(), anyInt());
  }

  @Test
  void listIsUnauthorizedWithoutToken() throws Exception {
    mvc.perform(get("/community/admin/reports")).andExpect(status().isUnauthorized());
  }

  @Test
  void resolveReturnsUpdatedStatus() throws Exception {
    CommunityReport r = new CommunityReport();
    r.setStatus("RESOLVED");
    when(service.resolve(anyLong(), anyLong(), any())).thenReturn(r);

    mvc.perform(post("/community/admin/reports/5/resolve")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenWithRole("ADMIN"))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"action\":\"RESOLVE\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("RESOLVED"));
  }

  @Test
  void resolveIsForbiddenForNonAdmin() throws Exception {
    mvc.perform(post("/community/admin/reports/5/resolve")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenWithRole("LEARNER"))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"action\":\"RESOLVE\"}"))
        .andExpect(status().isForbidden());

    verify(service, never()).resolve(anyLong(), anyLong(), any());
  }

  /** HS256 서명 토큰. role 이 null 이면 클레임을 넣지 않는다. */
  private String tokenWithRole(String role) throws Exception {
    JWTClaimsSet.Builder claims = new JWTClaimsSet.Builder()
        .subject("1")
        .issueTime(new Date())
        .expirationTime(new Date(System.currentTimeMillis() + 60_000));
    if (role != null) {
      claims.claim("role", role);
    }
    SignedJWT jwt = new SignedJWT(new JWSHeader(JWSAlgorithm.HS256), claims.build());
    jwt.sign(new MACSigner(secret.getBytes(StandardCharsets.UTF_8)));
    return jwt.serialize();
  }
}
```

- [ ] **Step 8: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*AdminReportControllerTest*"
```
Expected: FAIL — 컨트롤러 없음

- [ ] **Step 9: `AdminReportController` 구현**

`/community/admin/**` 는 `SecurityConfig` 에서 이미 `hasRole("ADMIN")` 으로 보호돼 있다(검색 재색인 작업에서 추가). **추가 설정이 필요 없다** — 확인만 하라:

```bash
cd D:/workspace/dpa/devpath-community-svc && grep -n "community/admin" src/main/java/ai/devpath/community/config/SecurityConfig.java
```
Expected: `.requestMatchers("/community/admin/**", "/admin/**").hasRole("ADMIN")`

없으면 멈추고 `NEEDS_CONTEXT`로 보고하라(인증 없이 열어두지 말 것).

```java
package ai.devpath.community.report;

import ai.devpath.community.report.dto.AdminReportResponse;
import ai.devpath.community.report.dto.ReportCreatedView;
import ai.devpath.community.report.dto.ResolveRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

/** /community/admin/** — SecurityConfig 의 hasRole("ADMIN") 으로 보호됨.
 *  경로가 /admin/reports 가 아닌 이유는 게이트웨이가 /admin/** 를 platform-svc 로 보내기 때문이다. */
@RestController
@RequestMapping("/community/admin")
public class AdminReportController {

  private final ReportService service;

  public AdminReportController(ReportService service) {
    this.service = service;
  }

  @GetMapping("/reports")
  public ResponseEntity<AdminReportResponse> list(
      @RequestParam(required = false) String status,
      @RequestParam(required = false, defaultValue = "0") int page,
      @RequestParam(required = false, defaultValue = "20") int size) {
    return ResponseEntity.ok(service.list(status, page, size));
  }

  @PostMapping("/reports/{id}/resolve")
  public ResponseEntity<ReportCreatedView> resolve(@AuthenticationPrincipal Jwt jwt,
      @PathVariable long id, @RequestBody ResolveRequest req) {
    long reviewerId = Long.parseLong(jwt.getSubject());
    CommunityReport r = service.resolve(id, reviewerId, req.action());
    return ResponseEntity.ok(
        new ReportCreatedView(r.getId() == null ? id : r.getId(), r.getStatus()));
  }
}
```

- [ ] **Step 10: 전체 백엔드 테스트 + 커밋 + PR**

```bash
docker exec dpa-test-pg dropdb -U devpath --if-exists devpath_citest
docker exec dpa-test-pg createdb -U devpath -O devpath devpath_citest
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --rerun-tasks
```
Expected: 전체 PASS. 회귀가 있으면 원인을 규명해 수정한다(임시방편 금지).

```bash
git -C D:/workspace/dpa/devpath-community-svc add src/main/java/ai/devpath/community/report src/test/java/ai/devpath/community/report
git -C D:/workspace/dpa/devpath-community-svc commit -m "feat(report): 관리자 목록·판정 API

GET /community/admin/reports · POST /community/admin/reports/{id}/resolve.

- 목록은 신고와 대상 콘텐츠를 한 번에 조립한다(같은 DB). targetPath 를 서버가 주어
  프론트가 QNA//community/{id} vs 일반글//community/post/{id} 규칙을 중복 구현하지 않게 한다.
- reportCount 는 status 무관 총 신고 수 — 처리된 신고도 세야 \"그동안 몇 번 신고됐는가\"를 본다.
- 대상이 삭제된 신고는 targetTitle·targetPath 가 null 로 나가고 프론트가 \"삭제된 콘텐츠\"로 표시한다.
- 이미 처리된 신고 재처리는 409.
- 권한 테스트는 실제 서명 JWT 로 작성했다 — jwt() 후처리기는 authority 를 직접 주입해
  SecurityConfig 의 role→ROLE_* 변환기를 우회하므로 권한을 검증하지 못한다."
git -C D:/workspace/dpa/devpath-community-svc push -u origin feat/community-report
```

PR 생성(base `develop`). **CI green 확인 후 머지까지 진행한다** — 프론트가 이 계약에 의존한다.

---

## Task 4: 프론트 — dp_core 모델 + 데이터 소스 + 목 픽스처

**Repo:** `devpath-frontend`

**Files:**
- Create: `packages/dp_core/lib/src/models/community_report.dart`
- Modify: `packages/dp_core/lib/dp_core.dart`
- Modify: `apps/web/lib/src/features/community/data/community_source.dart`
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart`
- Test: `apps/web/test/features/community/report_source_test.dart`

**Interfaces:**
- Consumes: 백엔드 `POST /community/reports` 계약(Task 2)
- Produces:
  - `enum CommunityReportCategory { spam, abuse, ad, duplicate, inappropriate, etc }` — `wire` getter가 `SPAM` 등 서버 값을, `label` getter가 한글 라벨을 준다
  - `CommunityReportResult`(freezed) — `id`·`status`
  - `communityReportProvider` — `Future<CommunityReportResult> Function({required String targetType, required int targetId, required CommunityReportCategory category, String? reason})`
  Task 5가 소비한다.

- [ ] **Step 1: 브랜치 생성**

```bash
git -C D:/workspace/dpa/devpath-frontend fetch origin
git -C D:/workspace/dpa/devpath-frontend checkout develop
git -C D:/workspace/dpa/devpath-frontend pull origin develop
git -C D:/workspace/dpa/devpath-frontend checkout -b feat/community-report
```

- [ ] **Step 2: 실패 테스트 작성**

Create `apps/web/test/features/community/report_source_test.dart` — 기존 `community_search_source_test.dart` 패턴(실제 `ApiClient` + `MockHttpAdapter`):

```dart
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ApiClient _client(Map<String, MockFixture> fixtures) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = MockHttpAdapter(fixtures);
  return client;
}

ProviderContainer _container(Map<String, MockFixture> fixtures) {
  final c = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(_client(fixtures))],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('communityReport: POST /community/reports 로 접수하고 결과를 파싱한다', () async {
    final c = _container({
      'POST /community/reports': (201, {'id': 5, 'status': 'OPEN'}),
    });

    final r = await c.read(communityReportProvider)(
      targetType: 'POST',
      targetId: 1,
      category: CommunityReportCategory.spam,
      reason: '광고글입니다',
    );

    expect(r.id, 5);
    expect(r.status, 'OPEN');
  });

  test('CommunityReportCategory: 서버 값과 한글 라벨이 대응한다', () {
    expect(CommunityReportCategory.spam.wire, 'SPAM');
    expect(CommunityReportCategory.abuse.wire, 'ABUSE');
    expect(CommunityReportCategory.ad.wire, 'AD');
    expect(CommunityReportCategory.duplicate.wire, 'DUPLICATE');
    expect(CommunityReportCategory.inappropriate.wire, 'INAPPROPRIATE');
    expect(CommunityReportCategory.etc.wire, 'ETC');

    expect(CommunityReportCategory.spam.label, '스팸');
    expect(CommunityReportCategory.abuse.label, '욕설');
    expect(CommunityReportCategory.values.length, 6);
  });
}
```

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/report_source_test.dart
```
Expected: FAIL — `communityReportProvider`·`CommunityReportCategory` 없음

- [ ] **Step 4: dp_core 모델 작성**

Create `packages/dp_core/lib/src/models/community_report.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'community_report.freezed.dart';
part 'community_report.g.dart';

/// 신고 사유. [wire] 는 서버 enum 값, [label] 은 화면 표기다.
/// 서버 CHECK 제약(chk_community_reports_category)과 [wire] 가 일치해야 한다.
enum CommunityReportCategory {
  spam('SPAM', '스팸'),
  abuse('ABUSE', '욕설'),
  ad('AD', '광고'),
  duplicate('DUPLICATE', '중복'),
  inappropriate('INAPPROPRIATE', '부적절'),
  etc('ETC', '기타');

  const CommunityReportCategory(this.wire, this.label);
  final String wire;
  final String label;
}

/// 신고 접수 결과(`POST /community/reports`).
@freezed
abstract class CommunityReportResult with _$CommunityReportResult {
  const factory CommunityReportResult({
    @Default(0) int id,
    @Default('OPEN') String status,
  }) = _CommunityReportResult;

  factory CommunityReportResult.fromJson(Map<String, dynamic> json) =>
      _$CommunityReportResultFromJson(json);
}
```

barrel export 추가 후 코드 생성:

```bash
cd D:/workspace/dpa/devpath-frontend && sed -i "s|^export 'src/models/community_search.dart';|export 'src/models/community_search.dart';\nexport 'src/models/community_report.dart';|" packages/dp_core/lib/dp_core.dart
cd D:/workspace/dpa/devpath-frontend/packages/dp_core && dart run build_runner build --delete-conflicting-outputs
```

생성 파일(`.freezed.dart`·`.g.dart`)은 tracked 이므로 커밋 대상이다.

- [ ] **Step 5: 데이터 소스 provider 추가**

`community_source.dart`의 `communitySearchProvider` 아래에 추가한다:

```dart
/// 신고 접수 `POST /community/reports`. 409=이미 신고함, 400=본인 콘텐츠·잘못된 값.
typedef CommunityReportSubmit =
    Future<CommunityReportResult> Function({
      required String targetType,
      required int targetId,
      required CommunityReportCategory category,
      String? reason,
    });

final communityReportProvider = Provider<CommunityReportSubmit>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required String targetType,
    required int targetId,
    required CommunityReportCategory category,
    String? reason,
  }) async {
    final json = await client.post<Map<String, dynamic>>(
      '/community/reports',
      body: {
        'targetType': targetType,
        'targetId': targetId,
        'category': category.wire,
        'reason': ?reason,
      },
    );
    return CommunityReportResult.fromJson(json);
  };
});
```

- [ ] **Step 6: 목 픽스처 추가**

`web_mock_fixtures.dart`의 `'GET /community/search'` 항목 아래에 추가한다:

```dart
  // 신고 접수(폴백 키). 목 프로토에서는 항상 성공한다.
  'POST /community/reports': (201, {'id': 1, 'status': 'OPEN'}),
```

- [ ] **Step 7: 테스트 통과 + 게이트 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/report_source_test.dart
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run format
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run analyze
```
Expected: 테스트 2건 PASS, format 0 changed(1회차에 변경되면 재실행), analyze SUCCESS

```bash
git -C D:/workspace/dpa/devpath-frontend add packages/dp_core apps/web/lib/src/features/community/data apps/web/lib/src/data apps/web/test/features/community
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): 신고 모델·데이터 소스·목 픽스처

CommunityReportCategory 는 wire(서버 enum)와 label(한글 표기)을 함께 든다 — 두 곳에
흩어지면 서버 CHECK 제약과 어긋나도 컴파일이 통과한다. 대응을 테스트로 고정."
```

---

## Task 5: 프론트 — 신고 다이얼로그 + `⋮` 메뉴

**Repo:** `devpath-frontend`

**Files:**
- Create: `apps/web/lib/src/features/community/presentation/widgets/report_dialog.dart`
- Create: `apps/web/lib/src/features/community/presentation/widgets/report_menu_button.dart`
- Modify: `apps/web/lib/src/features/community/presentation/qna_detail_page.dart`
- Modify: `apps/web/lib/src/features/community/presentation/post_detail_page.dart`
- Test: `apps/web/test/features/community/report_test.dart`

**Interfaces:**
- Consumes: `communityReportProvider`·`CommunityReportCategory`·`CommunityReportResult` (Task 4)
- Produces: `ReportMenuButton`(위젯) — `targetType`·`targetId`·`authorId`(nullable)를 받아 `⋮` 메뉴와 다이얼로그를 담당

- [ ] **Step 1: 현재 상세 화면 구조 확인**

```bash
cd D:/workspace/dpa/devpath-frontend && grep -n "appBar\|AppBar\|authorId\|answers\|comments" apps/web/lib/src/features/community/presentation/qna_detail_page.dart | head -20
cd D:/workspace/dpa/devpath-frontend && grep -n "appBar\|AppBar\|authorId\|comments" apps/web/lib/src/features/community/presentation/post_detail_page.dart | head -20
```

답변·댓글 항목이 어떤 위젯으로 렌더되는지 확인하고, 그 위젯의 trailing 자리에 `ReportMenuButton`을 넣는다.

- [ ] **Step 2: 실패 테스트 작성**

Create `apps/web/test/features/community/report_test.dart`:

```dart
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/widgets/report_menu_button.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _containerWith({CommunityReportSubmit? submit}) {
  final c = ProviderContainer(
    overrides: [
      if (submit != null) communityReportProvider.overrideWithValue(submit),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child)),
);

void main() {
  testWidgets('자기 콘텐츠에는 메뉴가 보이지 않는다', (tester) async {
    final c = _containerWith();
    await tester.pumpWidget(
      _host(
        c,
        const ReportMenuButton(
          targetType: 'POST',
          targetId: 1,
          authorId: 7,
          currentUserId: '7',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('report-menu')), findsNothing);
  });

  testWidgets('남의 콘텐츠에는 메뉴가 보인다', (tester) async {
    final c = _containerWith();
    await tester.pumpWidget(
      _host(
        c,
        const ReportMenuButton(
          targetType: 'POST',
          targetId: 1,
          authorId: 7,
          currentUserId: '3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('report-menu')), findsOneWidget);
  });

  testWidgets('작성자를 모르면(QNA 질문) 메뉴를 보여준다', (tester) async {
    final c = _containerWith();
    await tester.pumpWidget(
      _host(
        c,
        const ReportMenuButton(
          targetType: 'POST',
          targetId: 1,
          authorId: null,
          currentUserId: '3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('report-menu')), findsOneWidget);
  });

  testWidgets('카테고리를 고르고 신고하면 wire 값과 사유가 전달된다', (tester) async {
    String? sentType;
    int? sentId;
    CommunityReportCategory? sentCategory;
    String? sentReason;
    final c = _containerWith(
      submit:
          ({
            required String targetType,
            required int targetId,
            required CommunityReportCategory category,
            String? reason,
          }) async {
            sentType = targetType;
            sentId = targetId;
            sentCategory = category;
            sentReason = reason;
            return const CommunityReportResult(id: 5, status: 'OPEN');
          },
    );
    await tester.pumpWidget(
      _host(
        c,
        const ReportMenuButton(
          targetType: 'ANSWER',
          targetId: 11,
          authorId: 7,
          currentUserId: '3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('report-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('욕설'));
    await tester.enterText(find.byKey(const ValueKey('report-reason')), '심한 표현');
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();

    expect(sentType, 'ANSWER');
    expect(sentId, 11);
    expect(sentCategory, CommunityReportCategory.abuse);
    expect(sentReason, '심한 표현');
    expect(find.textContaining('접수'), findsOneWidget); // 스낵바
  });

  testWidgets('이미 신고한 대상이면 409 안내를 보여준다', (tester) async {
    final c = _containerWith(
      submit:
          ({
            required String targetType,
            required int targetId,
            required CommunityReportCategory category,
            String? reason,
          }) async => throw const ApiException(
            code: ApiErrorCode.conflict,
            message: '이미 신고한 콘텐츠입니다.',
          ),
    );
    await tester.pumpWidget(
      _host(
        c,
        const ReportMenuButton(
          targetType: 'POST',
          targetId: 1,
          authorId: 7,
          currentUserId: '3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('report-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('스팸'));
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('이미 신고'), findsOneWidget);
  });

  testWidgets('본인 콘텐츠 400 은 전용 문구로 안내한다', (tester) async {
    final c = _containerWith(
      submit:
          ({
            required String targetType,
            required int targetId,
            required CommunityReportCategory category,
            String? reason,
          }) async => throw const ApiException(
            code: ApiErrorCode.validationFailed,
            message: '본인이 작성한 콘텐츠는 신고할 수 없습니다.',
          ),
    );
    await tester.pumpWidget(
      _host(
        c,
        const ReportMenuButton(
          targetType: 'POST',
          targetId: 1,
          authorId: null,
          currentUserId: '3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('report-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('스팸'));
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('본인'), findsOneWidget);
  });

  testWidgets('카테고리를 고르지 않으면 신고 버튼이 비활성이다', (tester) async {
    final c = _containerWith();
    await tester.pumpWidget(
      _host(
        c,
        const ReportMenuButton(
          targetType: 'POST',
          targetId: 1,
          authorId: 7,
          currentUserId: '3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('report-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('report-submit')),
    );
    expect(button.onPressed, isNull, reason: '조용히 실패하는 버튼을 만들지 않는다');
  });
}
```

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/report_test.dart
```
Expected: FAIL — `ReportMenuButton` 없음

- [ ] **Step 4: `ReportDialog` 구현**

Create `apps/web/lib/src/features/community/presentation/widgets/report_dialog.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 신고 사유 선택 다이얼로그. 확인을 누르면 (카테고리, 사유)를 돌려준다.
/// 카테고리를 고르기 전에는 제출 버튼이 비활성이다 — 조용히 실패하는 버튼을 두지 않는다.
class ReportDialog extends StatefulWidget {
  const ReportDialog({super.key});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class ReportDialogResult {
  const ReportDialogResult(this.category, this.reason);
  final CommunityReportCategory category;
  final String? reason;
}

class _ReportDialogState extends State<ReportDialog> {
  static const _reasonMax = 500;

  CommunityReportCategory? _category;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('신고하기'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('사유를 골라주세요'),
            const SizedBox(height: DpSpacing.sm),
            Wrap(
              spacing: DpSpacing.xs,
              children: [
                for (final c in CommunityReportCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: DpSpacing.md),
            TextField(
              key: const ValueKey('report-reason'),
              controller: _reason,
              maxLength: _reasonMax,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '상세 설명 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('report-submit'),
          onPressed: _category == null
              ? null
              : () => Navigator.of(context).pop(
                  ReportDialogResult(
                    _category!,
                    _reason.text.trim().isEmpty ? null : _reason.text.trim(),
                  ),
                ),
          child: const Text('신고'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: `ReportMenuButton` 구현**

Create `apps/web/lib/src/features/community/presentation/widgets/report_menu_button.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/community_source.dart';
import 'report_dialog.dart';

/// 콘텐츠 옆 `⋮` 메뉴 — 지금은 신고 하나뿐이다.
///
/// [authorId] 가 현재 사용자와 같으면 메뉴를 감춘다. **[authorId] 가 null 이면 감추지
/// 않는다** — QNA 질문 상세 응답에는 작성자 id 가 없기 때문이다(기존 계약). 그 경우 서버가
/// 400 으로 막고 여기서 안내 문구로 처리한다. UI 미노출은 편의일 뿐 서버 검증이 최종 방어선이다.
class ReportMenuButton extends ConsumerWidget {
  const ReportMenuButton({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.authorId,
    required this.currentUserId,
  });

  final String targetType;
  final int targetId;

  /// 대상 작성자. 모르면 null.
  final int? authorId;

  /// 현재 로그인 사용자 id. `User.id` 가 String 이라 타입을 맞춰 비교한다.
  final String? currentUserId;

  bool get _isMine =>
      authorId != null && currentUserId != null && authorId.toString() == currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isMine) return const SizedBox.shrink();
    return MenuAnchor(
      builder: (context, controller, _) => IconButton(
        key: const ValueKey('report-menu'),
        icon: const Icon(Icons.more_vert, size: 20),
        tooltip: '더보기',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => _openDialog(context, ref),
          child: const Text('신고하기'),
        ),
      ],
    );
  }

  Future<void> _openDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<ReportDialogResult>(
      context: context,
      builder: (_) => const ReportDialog(),
    );
    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(communityReportProvider)(
        targetType: targetType,
        targetId: targetId,
        category: result.category,
        reason: result.reason,
      );
      messenger.showSnackBar(const SnackBar(content: Text('신고가 접수됐어요')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_messageFor(e))));
    }
  }

  /// 서버 메시지를 그대로 쓰지 않고 상황별 문구를 준다 — 사용자가 다음에 뭘 할지 알 수 있어야 한다.
  String _messageFor(ApiException e) => switch (e.code) {
    ApiErrorCode.conflict => '이미 신고한 콘텐츠예요',
    ApiErrorCode.validationFailed => e.message.contains('본인')
        ? '본인이 쓴 글은 신고할 수 없어요'
        : e.message,
    ApiErrorCode.resourceNotFound => '이미 삭제된 콘텐츠예요',
    _ => '신고하지 못했어요. 잠시 후 다시 시도해 주세요',
  };
}
```

> `ApiException.code`·`.message` 의 실제 필드명을 확인하고 맞춰라(`packages/dp_core/lib/src/error/api_exception.dart`).

- [ ] **Step 6: 테스트 통과 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/report_test.dart
```
Expected: PASS (7개 케이스)

- [ ] **Step 7: 상세 화면에 배치**

`qna_detail_page.dart`·`post_detail_page.dart`에 `ReportMenuButton`을 넣는다:

- **질문/글 본문**: 제목 행 우측
  - QNA: `authorId: null`(상세 응답에 없다)
  - 일반글: `authorId: detail.authorId`
- **답변 항목**: `targetType: 'ANSWER'`, `targetId: answer.id`, `authorId: answer.authorId`
- **댓글 항목**: `targetType: 'COMMENT'`, `targetId: comment.id`, `authorId: comment.authorId`

`currentUserId`는 기존 인증 상태 provider에서 읽는다. **provider 이름을 추측하지 말고** 확인하라:

```bash
cd D:/workspace/dpa/devpath-frontend && grep -rn "User?\|currentUser\|authControllerProvider" apps/web/lib/src/features/auth/ apps/web/lib/src/providers/ | head -10
```

- [ ] **Step 8: 전체 게이트 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run format
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run analyze
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run test
```
Expected: 전부 PASS. 기존 커뮤니티 테스트에 회귀가 있으면 원인을 규명해 수정한다.

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): 신고 다이얼로그 + 콘텐츠별 더보기 메뉴

글·답변·댓글 각각에 ⋮ 메뉴를 달고 카테고리 선택 다이얼로그를 띄운다.

- 자기 콘텐츠는 메뉴를 감춘다. 단 **authorId 가 null 이면 감추지 않는다** — QNA 질문
  상세 응답에 작성자 id 가 없다는 기존 계약 때문이며, 그 경우 서버 400 을 전용 문구로 안내한다.
- 카테고리 미선택 시 제출 버튼 비활성 — 조용히 실패하는 버튼을 두지 않는다(이 프로젝트가
  동의 화면에서 겪은 문제).
- 409/400/404 를 각각 다른 문구로 안내한다."
```

---

## Task 6: admin 신고 화면 개편 + 프론트 PR

**Repo:** `devpath-frontend`

**Files:**
- Modify: `apps/admin/lib/src/features/reports/data/report.dart`
- Modify: `apps/admin/lib/src/features/reports/state/reports_state.dart`
- Modify: `apps/admin/lib/src/features/reports/application/reports_controller.dart`
- Modify: `apps/admin/lib/src/features/reports/presentation/reports_page.dart`
- Modify: admin 목 픽스처 (Step 1에서 파일 확인)
- Test: `apps/admin/test/features/reports/reports_page_test.dart`

**Interfaces:**
- Consumes: 백엔드 `GET /community/admin/reports`·`POST /community/admin/reports/{id}/resolve` (Task 3)

- [ ] **Step 1: 현재 admin 구조·목 픽스처 확인**

```bash
cd D:/workspace/dpa/devpath-frontend && cat apps/admin/lib/src/features/reports/state/reports_state.dart
cd D:/workspace/dpa/devpath-frontend && cat apps/admin/lib/src/features/reports/application/reports_controller.dart
cd D:/workspace/dpa/devpath-frontend && ls apps/admin/lib/src/data/
cd D:/workspace/dpa/devpath-frontend && grep -rn "admin/reports" apps/admin/lib/src/data/ | head
cd D:/workspace/dpa/devpath-frontend && ls apps/admin/test/features/ 2>/dev/null
```

기존 admin 테스트 스타일(있다면)을 따른다.

- [ ] **Step 2: 실패 테스트 작성**

Create `apps/admin/test/features/reports/reports_page_test.dart`. 위 Step 1에서 확인한 관용구에 맞춰 작성하되, 검증 항목은 다음과 같다:

1. 목록이 **대상 제목·카테고리 라벨·신고 수**를 렌더한다
2. **[기각]** 을 누르면 `action: 'REJECT'` 로 호출된다
3. **[처리완료]** 를 누르면 `action: 'RESOLVE'` 로 호출된다
4. 대상이 삭제된 항목(`targetTitle == null`)은 **"삭제된 콘텐츠"** 로 표시되고 이동 링크가 비활성이다
5. 빈 목록이면 기존 `DpEmpty` 안내가 나온다

컨트롤러를 직접 검증할 수 있으면(HTTP 스텁) 그 방식을 쓰고, 아니면 위젯 테스트에서 provider override 로 캡처한다.

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/reports/reports_page_test.dart
```
Expected: FAIL

- [ ] **Step 4: 모델 교체**

`data/report.dart`를 백엔드 응답(§Task 3 `AdminReportView`)에 맞춘다. **`id`는 `int`다**(기존 `String`은 틀렸다):

```dart
/// 관리자 신고 목록 항목. 백엔드 AdminReportView 와 1:1 대응한다.
/// targetTitle·targetPath 는 대상이 삭제됐으면 null 이다.
class AdminReport {
  const AdminReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    required this.targetExcerpt,
    required this.targetPath,
    required this.category,
    required this.reason,
    required this.reportCount,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String targetType;
  final int targetId;
  final String? targetTitle;
  final String? targetExcerpt;
  final String? targetPath;
  final String category;
  final String? reason;
  final int reportCount;
  final String status;
  final String? createdAt;

  /// 서버 enum → 화면 표기. web 의 CommunityReportCategory 와 같은 대응이다.
  String get categoryLabel => switch (category) {
    'SPAM' => '스팸',
    'ABUSE' => '욕설',
    'AD' => '광고',
    'DUPLICATE' => '중복',
    'INAPPROPRIATE' => '부적절',
    _ => '기타',
  };

  factory AdminReport.fromJson(Map<String, dynamic> json) => AdminReport(
    id: (json['id'] as num).toInt(),
    targetType: json['targetType'] as String,
    targetId: (json['targetId'] as num).toInt(),
    targetTitle: json['targetTitle'] as String?,
    targetExcerpt: json['targetExcerpt'] as String?,
    targetPath: json['targetPath'] as String?,
    category: json['category'] as String,
    reason: json['reason'] as String?,
    reportCount: (json['reportCount'] as num?)?.toInt() ?? 1,
    status: (json['status'] as String?) ?? 'OPEN',
    createdAt: json['createdAt'] as String?,
  );
}
```

- [ ] **Step 5: 컨트롤러 교체**

경로를 `/community/admin/reports`로 바꾸고 `resolve(id, action)`으로 시그니처를 넓힌다. 응답이 envelope(`items`·`total`)이므로 파싱도 바뀐다. `status` 필터 상태를 들고 있게 한다.

```dart
  Future<void> load({String? status = 'OPEN'}) async {
    state = const ReportsLoading();
    try {
      final json = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
        '/community/admin/reports',
        query: {'status': ?status, 'page': 0, 'size': 50},
      );
      final items = (json['items'] as List? ?? const [])
          .map((e) => AdminReport.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      state = ReportsLoaded(items, status: status);
    } on ApiException catch (e) {
      state = ReportsFailed(e.message);
    }
  }

  Future<void> resolve(int id, String action) async {
    await ref.read(apiClientProvider).post<Map<String, dynamic>>(
      '/community/admin/reports/$id/resolve',
      body: {'action': action},
    );
    await load(status: (state is ReportsLoaded) ? (state as ReportsLoaded).status : 'OPEN');
  }
```

> 실제 `ApiClient` 메서드 시그니처(`get`/`post`의 `query`·`body` 파라미터명)를 기존 admin 코드에서 확인하고 맞춰라.

`ReportsLoaded`에 `status` 필드를 추가한다.

- [ ] **Step 6: 화면 개편**

`reports_page.dart`:
- 상단에 `SegmentedButton`으로 status 필터(전체 / 미처리 / 처리완료 / 기각)
- 각 항목 카드: 대상 제목(없으면 **"삭제된 콘텐츠"**) · 카테고리 라벨 칩 · **신고 수 배지**(`reportCount > 1`일 때 강조) · 사유 · 작성일
- 우측에 **[기각] [처리완료]** 두 버튼
- `targetPath`가 있으면 제목을 눌러 이동(admin은 web과 다른 앱이므로 **새 탭으로 web URL 열기**). URL 조립 방식은 기존 admin 코드에 선례가 있는지 확인하고, 없으면 제목 옆에 경로 텍스트만 표시하고 이동은 후속으로 남긴다 — **추측해서 구현하지 말 것.**

- [ ] **Step 7: 테스트 통과 + 전체 게이트**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run format
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run analyze
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run test
```
Expected: 전부 PASS

- [ ] **Step 8: 커밋 + PR**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/admin
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(admin): 신고 처리 화면 개편 — 실제 백엔드 계약에 맞춤

기존 화면은 /admin/reports 를 부르고 있었는데 그 백엔드는 어디에도 없었다(목 픽스처로만
도는 껍데기였다). 경로를 /community/admin/reports 로 바꾸고 모델을 실제 응답에 맞춘다.

- Report.id 가 String 이었으나 실제로는 정수다
- 대상 제목·발췌·신고 수·이동 경로를 표시한다
- resolve 를 [기각]/[처리완료] 두 갈래로 나눈다(백엔드 REJECTED/RESOLVED 와 대응)
- status 필터 추가
- 대상이 삭제된 신고는 \"삭제된 콘텐츠\"로 표시한다"
git -C D:/workspace/dpa/devpath-frontend push -u origin feat/community-report
```

PR 생성(base `develop`). CI green 확인 후 머지.

---

## Task 7: API 명세서 갱신

**Repo:** `documents`

**Files:**
- Modify: `04_API_명세서.md` — §8.1.2 신고

- [ ] **Step 1: 브랜치 생성**

```bash
git -C D:/workspace/dpa/documents fetch origin
git -C D:/workspace/dpa/documents checkout develop
git -C D:/workspace/dpa/documents pull origin develop
git -C D:/workspace/dpa/documents checkout -b docs/community-report-api
```

- [ ] **Step 2: §8.1.1(검색) 바로 뒤에 §8.1.2를 추가**

기존 §8.1.1의 형식(표 + 요청/응답 예시 + 계약 목록)을 그대로 따른다. 담을 내용:

| Method | Endpoint | 설명 | 권한 |
|---|---|---|---|
| POST | `/community/reports` | 글·답변·댓글 신고 | LEARNER |
| GET | `/community/admin/reports?status=&page=&size=` | 신고 목록 | ADMIN |
| POST | `/community/admin/reports/{id}/resolve` | 판정(RESOLVE/REJECT) | ADMIN |

- 요청·응답 JSON 예시(Task 2·3의 실제 계약 그대로)
- `targetType`·`category`·`status`·`action` enum 값 전체
- 오류: 409(중복 신고·재처리) · 400(본인 콘텐츠·enum 밖·사유 500자 초과) · 404(대상 없음)
- **계약 명시**: `reportCount`는 status 무관 총합 · `targetPath`는 서버가 준다 · 대상 삭제 시 `targetTitle`·`targetPath`가 null
- ⚠️ **관리자 경로가 `/community/admin/reports`인 이유**(게이트웨이가 `/admin/**`를 platform-svc로 선점) — 이 근거가 없으면 다음 사람이 "일관성" 명목으로 되돌려 404를 만든다
- **이번 범위의 한계**: 판정만 기록하며 **콘텐츠 조치(숨김·삭제)·제재는 없다**

§8 상태 배너의 구현 목록에 `reports`·`admin/reports`를 추가한다.

- [ ] **Step 3: 커밋 + PR**

```bash
git -C D:/workspace/dpa/documents add 04_API_명세서.md
git -C D:/workspace/dpa/documents commit -m "docs(api): 커뮤니티 신고 API 명세 추가(8.1.2)"
git -C D:/workspace/dpa/documents push -u origin docs/community-report-api
```

PR 생성(base `develop`) 후 머지.

---

## Self-Review

**1. spec 커버리지**

| spec 항목 | 담당 Task |
|---|---|
| §3 테이블 스키마·UNIQUE·인덱스 | Task 1 |
| §4 패키지 구조 | Task 2·3 |
| §4.1 관리자 경로가 `/community/admin/**` 인 이유 | Task 3 Step 9(주석) · Task 7(명세) |
| §4.2 접수 시점 검증 4종 | Task 2 Step 3(테스트)·Step 5(구현) |
| §4.2 rollback-only 트랩 회피 | Task 2 Step 5(`@Transactional` 미부착 + 주석) |
| §4.3 단일 쿼리 조립 · `reportCount` | Task 3 Step 5 |
| §5.1 접수 API + 오류 4종 + `reason` 500자 | Task 2 |
| §5.2 목록 envelope · `targetPath` · 삭제 대상 null · size 클램프 | Task 3 |
| §5.3 판정 API · 재처리 409 | Task 3 |
| §6.1 다이얼로그 · `⋮` 메뉴 · 자기 콘텐츠 미노출 · QNA 예외 | Task 5 |
| §6.1 dp_core 모델 | Task 4 |
| §6.2 admin 개편 | Task 6 |
| §8 테스트 범위 | Task 2·3·5·6 |
| §9 실행 순서 · shared 수동 발행 | Task 1 Step 5 |
| §7 조치 수단 부재의 완화(이동 링크) | Task 3(`targetPath`) · Task 6 Step 6 |

누락 없음.

**2. 플레이스홀더 점검**

의도적으로 실측에 맡긴 지점과 그 절차:

- `ApiException.getErrorCode()`·`ApiException.code/message` 실제 이름 — Task 2 Step 5·Task 5 Step 5에 확인 명령 명시
- `Excerpts` 시그니처 — Task 3 Step 5에 `grep` 명령 명시
- `@AuthenticationPrincipal Jwt` 관용구 — Task 2 Step 9에 확인 위치 명시
- 현재 사용자 provider 이름 — Task 5 Step 7에 `grep` 명령 명시
- admin 목 픽스처 파일명·`ApiClient` 시그니처·admin 테스트 관용구 — Task 6 Step 1에 확인 명령 명시
- admin에서 web URL 여는 방식 — Task 6 Step 6에 "선례 없으면 이동은 후속으로, **추측 구현 금지**" 명시

전부 "확인 명령 + 실패 시 행동"이 붙어 있다.

**3. 타입 일관성**

- `ReportService.create(long, String, Long, String, String)` — Task 2 정의, Task 2 Step 7(컨트롤러 테스트)에서 같은 시그니처로 mock
- `ReportService.list(String, int, int)` → `AdminReportResponse` — Task 3 정의·사용 일치
- `ReportService.resolve(long, long, String)` → `CommunityReport` — Task 3 정의·사용 일치
- `AdminReportView` 필드 13개 = admin `AdminReport.fromJson` 파싱 키와 일치(`id`·`targetType`·`targetId`·`targetTitle`·`targetExcerpt`·`targetAuthorId`·`targetPath`·`reporterId`·`category`·`reason`·`reportCount`·`status`·`createdAt`)
  - admin 모델은 `targetAuthorId`·`reporterId`를 쓰지 않는다(화면에 안 쓴다) — 파싱에서 빠져도 무방하며 이는 의도된 것이다
- `CommunityReportCategory.wire` 6종 = SQL CHECK 제약 6종 = `ReportCategory` enum 6종 일치
- `status` 3종(`OPEN`/`RESOLVED`/`REJECTED`)이 SQL CHECK·`ReportStatus`·admin 필터에서 동일
- `action` 2종(`RESOLVE`/`REJECT`)이 `ResolveRequest`·`ReportService.resolve`·admin 버튼에서 동일

**4. 알려진 리스크**

- **Task 1 Step 5(shared 발행)가 최대 관문이다.** 발행이 반영되지 않으면 Task 2~3이 전부 컴파일·실행 불가다. 확인 절차와 실패 시 `NEEDS_CONTEXT`를 명시했다.
- **Task 6은 기존 화면 개편이라 회귀 위험이 있다.** admin 앱 전체 테스트(42건)를 게이트로 둔다.
- QNA 질문 상세에 작성자 id가 없어 자기 신고를 UI에서 막지 못한다 — 서버 400 + 전용 문구로 처리하며, 이는 설계된 동작이다(spec §6.1).
