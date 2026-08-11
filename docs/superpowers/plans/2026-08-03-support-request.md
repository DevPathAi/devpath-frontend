# ④ 오류 신고·문의 (Support Request) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인 사용자가 어느 화면에서든 서비스 오류·문의를 접수하고, 관리자가 admin 콘솔에서 목록·상세·상태 전이로 처리한다.

**Architecture:** platform-svc가 소유한다(`/support/**` 접수, `/admin/support-requests` 관리). 스키마는 devpath-shared 중앙 마이그레이션 1개(부모 `support_requests` + 자식 `support_request_failures`). 클라이언트는 dio 인터셉터 링버퍼로 최근 API 실패 최대 10건을 **마스킹된 상태로** 모아 접수 시 함께 보내고, 서버가 같은 규칙으로 재마스킹한다.

**Tech Stack:** Spring Boot 4.0.7 · Java 21 · JPA/Flyway · Spring Cloud Gateway(WebFlux) · Flutter Web(Dart 3, riverpod 3.x, dio 5.9.2, go_router)

**스펙:** `devpath-frontend/docs/superpowers/specs/2026-08-02-support-request-design.md` (frontend PR #101)

---

## Global Constraints

모든 Task에 예외 없이 적용된다.

- **착수 전 브랜치 정리 (필수)**: `devpath-platform-svc`는 `feat/refresh-reuse-detection`, `devpath-gateway`는 `fix/actuator-probe-permit`에 체크아웃돼 있다(7월 말 코드). 각 레포에서 `git checkout develop && git pull` 후 작업 브랜치를 딴다.
- **브랜치**: 각 레포 `develop`에서 `feat/support-request` 분기 → `develop`으로 PR. `main` 직접 금지.
- **TDD**: 실패하는 테스트를 먼저 쓰고, 실패를 눈으로 확인한 뒤 최소 구현한다. 테스트 없는 구현 변경 금지.
- **추측 금지**: 명세에 없는 코드를 즉흥 구현하지 않는다. 부족하면 멈추고 `NEEDS_CONTEXT`로 보고한다.
- **마스킹 규칙은 Task 2(Java)와 Task 6(Dart)이 문자 단위로 동일**해야 한다. 두 Task의 케이스 표는 같은 12행이며 입력·기대 출력이 완전히 같다.
- **패턴 문자열에 `(?i)` 인라인 플래그와 lookbehind를 쓰지 않는다.** Dart `RegExp`가 지원하지 않는다. 대소문자 무시는 각 언어 API로 준다 — Dart `caseSensitive: false`, Java `Pattern.CASE_INSENSITIVE`.
- **DB 이름**: platform-svc 테스트 DB는 **`devpath`**다(community-svc의 `devpath_citest`가 아니다).
- **컨테이너**: `dpa-test-pg`가 떠 있어야 platform-svc 테스트가 돈다.
- **Windows**: 파이썬은 `python`이 아니라 **`py`**. Git Bash에서 한글 JSON을 `curl -d`로 넘기면 CP949로 깨진다 — UTF-8 파일 + `--data-binary @file`.
- **상태값 4종**: `OPEN` · `IN_PROGRESS` · `RESOLVED` · `WONTFIX`. **유형 2종**: `ERROR` · `INQUIRY`.
- **화면 낱말 규칙**: 상태 필터는 명사(접수됨 · 처리중 · 처리됨 · 보류), 전이 버튼은 동사(처리 시작 · 처리 완료 · 보류로 표시 · 다시 열기). 같은 낱말을 두 뜻으로 쓰지 않는다.
- **커밋**: Conventional Commits. Task 단위로 커밋한다.

## 레포 의존 순서

```
Task 1     devpath-shared (마이그레이션 + 수동 발행)   ← 임계 경로
Task 2~4   devpath-platform-svc (마스커 → 접수 API → admin API)
Task 5     devpath-gateway (/support/** 라우트)
Task 6~8   devpath-frontend/packages (dp_core 마스커 → dp_core 수집 → dp_design)
Task 9~11  devpath-frontend/apps/web (배선 → 다이얼로그 → 진입점)
Task 12    devpath-frontend/apps/admin (처리 콘솔)
Task 13    documents (§8.1.3)
```

Task 5는 Task 2~4와 독립이다(게이트웨이는 라우트만 안다). Task 6~8도 백엔드와 독립이라 병렬 가능하다. **Task 3·4는 Task 1의 발행이 끝나야 테스트가 돈다.**

프론트 내부 순서는 지켜야 한다: Task 9(provider·모델) → Task 10(다이얼로그) → Task 11(진입점). Task 8(dp_design)은 Task 11보다 먼저면 된다.

## 파일 구조

### devpath-shared
| 파일 | 책임 |
|---|---|
| `src/main/resources/db/migration/V202608031001__support_requests.sql` (신규) | 부모·자식 테이블 + 인덱스 |

### devpath-platform-svc (`ai.devpath.platform.support`)
| 파일 | 책임 |
|---|---|
| `support/SensitiveTextMasker.java` (신규) | 10규칙 순차 마스킹 + 절단 |
| `support/SupportRequest.java` (신규) | 부모 엔티티 |
| `support/SupportRequestFailure.java` (신규) | 자식 엔티티(FK는 plain Long 컬럼) |
| `support/SupportRequestRepository.java` (신규) | keyset 조회 |
| `support/SupportRequestFailureRepository.java` (신규) | request_id별 조회 |
| `support/SupportService.java` (신규) | 접수·목록·상세·전이 로직 |
| `support/SupportController.java` (신규) | `POST /support/requests` |
| `support/AdminSupportController.java` (신규) | `/admin/support-requests` 3종 |
| `support/dto/*.java` (신규 7개) | 요청·응답 record |

### devpath-gateway
| 파일 | 책임 |
|---|---|
| `src/main/resources/application.yml` (수정) | `platform-auth` predicates에 `/support/**` 추가 |
| `src/test/java/ai/devpath/gateway/SupportRouteTest.java` (신규) | 라우트 매칭 회귀 |

### devpath-frontend
| 파일 | 책임 |
|---|---|
| `packages/dp_core/lib/src/support/sensitive_text_masker.dart` (신규) | Dart 마스커 |
| `packages/dp_core/lib/src/support/api_failure_log.dart` (신규) | 링버퍼 + 엔트리 모델 |
| `packages/dp_core/lib/src/support/api_failure_recorder.dart` (신규) | dio 인터셉터 |
| `packages/dp_core/lib/src/models/support_request.dart` (신규) | 접수 요청·admin 뷰 모델 |
| `packages/dp_core/lib/dp_core.dart` (수정) | export 4줄 추가 |
| `packages/dp_design/lib/src/states/dp_state_scaffold.dart` (수정) | 보조 액션 선택 파라미터 |
| `packages/dp_design/lib/src/states/dp_error.dart` (수정) | `onReport` 노출 |
| `apps/web/lib/src/app/app_config.dart` (수정) | `APP_VERSION` dart-define |
| `apps/web/lib/src/features/support/data/support_context_collector.dart` (신규) | 환경 수집(조건부 임포트) |
| `apps/web/lib/src/features/support/data/support_context_collector_web.dart` (신규) | `window.navigator.userAgent` |
| `apps/web/lib/src/features/support/application/support_controller.dart` (신규) | 접수 제출 |
| `apps/web/lib/src/features/support/presentation/support_dialog.dart` (신규) | 제보 다이얼로그 |
| `apps/web/lib/src/providers/api_providers.dart` (수정) | recorder 삽입 + provider |
| `apps/web/lib/src/data/web_mock_fixtures.dart` (수정) | `POST /support/requests` 픽스처 |
| `apps/web/lib/src/features/shell/presentation/app_shell.dart` (수정) | trailing `Row` 2버튼 |
| `apps/admin/lib/src/features/support/{data,application,state,presentation}/*` (신규 4개) | admin 화면 |
| `apps/admin/lib/src/app/router.dart` (수정) | `/support` 라우트 |
| `apps/admin/lib/src/features/shell/presentation/admin_shell.dart` (수정) | 내비 목적지 추가 |

### documents
| 파일 | 책임 |
|---|---|
| `04_API_명세서.md` (수정) | §8.1.3 오류 신고·문의 |

---

## Task 1: shared 마이그레이션 + 수동 발행

**Files:**
- Create: `devpath-shared/src/main/resources/db/migration/V202608031001__support_requests.sql`

**Interfaces:**
- Produces: 테이블 `support_requests`(컬럼 18개) · `support_request_failures`(컬럼 9개), 인덱스 `idx_support_requests_status_id` · `idx_support_request_failures_request`. Task 3·4가 이 스키마에 의존한다.

- [ ] **Step 1: 브랜치 생성**

```bash
git -C D:/workspace/dpa/devpath-shared checkout develop && git -C D:/workspace/dpa/devpath-shared pull
git -C D:/workspace/dpa/devpath-shared checkout -b feat/support-request
```

- [ ] **Step 2: 마이그레이션 작성**

`devpath-shared/src/main/resources/db/migration/V202608031001__support_requests.sql`:

```sql
-- 오류 신고·문의. ③ community_reports 와 별개다 — 대상이 콘텐츠가 아니라 서비스 자체라
-- target_type/1인1회 UNIQUE/콘텐츠 위반 category 가 모두 맞지 않는다.
CREATE TABLE support_requests (
  id           BIGSERIAL PRIMARY KEY,
  reporter_id  BIGINT       NOT NULL,
  type         VARCHAR(16)  NOT NULL,     -- ERROR | INQUIRY
  title        VARCHAR(200) NOT NULL,
  body         TEXT         NOT NULL,
  page_path    VARCHAR(512),              -- 제보 시점 라우트(쿼리스트링 제거)
  app_version  VARCHAR(32),
  user_agent   VARCHAR(512),
  viewport     VARCHAR(32),               -- "1920x1080"
  trace_id     VARCHAR(64),
  error_code   VARCHAR(64),
  occurred_at  TIMESTAMPTZ,               -- 사용자 체감 발생 시각(클라 제공)
  status       VARCHAR(16)  NOT NULL DEFAULT 'OPEN',
  admin_note   TEXT,
  handled_by   BIGINT,
  handled_at   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT chk_support_requests_type
    CHECK (type IN ('ERROR','INQUIRY')),
  CONSTRAINT chk_support_requests_status
    CHECK (status IN ('OPEN','IN_PROGRESS','RESOLVED','WONTFIX'))
);

-- 관리자 목록 = status 필터 + 최신순 keyset. 정렬 키는 created_at 이 아니라 id 다
-- (BIGSERIAL 이라 단조 증가 = 시간 순서이고, keyset cursor 로 쓰려면 유일해야 한다).
CREATE INDEX idx_support_requests_status_id
  ON support_requests (status, id DESC);

-- 정규화 자식. 부모가 단일이라 ③과 달리 실제 FK 를 걸 수 있다.
CREATE TABLE support_request_failures (
  id          BIGSERIAL PRIMARY KEY,
  request_id  BIGINT       NOT NULL REFERENCES support_requests(id) ON DELETE CASCADE,
  seq         SMALLINT     NOT NULL,      -- 0 = 가장 최근, 최대 9
  method      VARCHAR(8)   NOT NULL,
  path        VARCHAR(512) NOT NULL,      -- 쿼리스트링 제거
  status_code SMALLINT,                   -- 네트워크 실패면 NULL
  error_code  VARCHAR(64),
  trace_id    VARCHAR(64),
  message     VARCHAR(500),               -- 마스킹된 응답 message
  occurred_at TIMESTAMPTZ  NOT NULL,
  CONSTRAINT uq_support_request_failures_seq UNIQUE (request_id, seq)
);

CREATE INDEX idx_support_request_failures_request
  ON support_request_failures (request_id, seq);
```

- [ ] **Step 3: 빌드 확인**

Run: `cd D:/workspace/dpa/devpath-shared && ./gradlew build`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: 커밋·푸시·PR**

```bash
git -C D:/workspace/dpa/devpath-shared add src/main/resources/db/migration/V202608031001__support_requests.sql
git -C D:/workspace/dpa/devpath-shared commit -m "feat: add support_requests migration"
git -C D:/workspace/dpa/devpath-shared push -u origin feat/support-request
gh pr create -R DevPathAi/devpath-shared --base develop --head feat/support-request \
  --title "feat: support_requests 마이그레이션" \
  --body "④ 오류 신고·문의 스키마. 부모 support_requests + 자식 support_request_failures."
```

- [ ] **Step 5: CI 녹색 확인 후 머지**

```bash
gh pr checks <PR번호> -R DevPathAi/devpath-shared
gh pr merge <PR번호> -R DevPathAi/devpath-shared --merge
```

- [ ] **Step 6: ★수동 발행 (임계 경로)★**

shared는 `main` push에만 자동 발행된다. develop 머지만으로는 platform-svc가 새 마이그레이션을 못 받는다.

```bash
gh workflow run publish.yml --ref develop -R DevPathAi/devpath-shared
gh run list -R DevPathAi/devpath-shared --workflow publish.yml --limit 1
```

- [ ] **Step 7: 발행 반영 실측**

platform-svc에서 의존성을 새로 받아 Flyway가 새 버전을 적용하는지 확인한다.

```bash
cd D:/workspace/dpa/devpath-platform-svc && ./gradlew test --refresh-dependencies --tests '*DbConnectionTest*'
docker exec dpa-test-pg psql -U devpath -d devpath -c \
  "SELECT version, success FROM flyway_schema_history WHERE version='202608031001';"
```

Expected: `202608031001 | t` 한 행. 이 행이 없으면 **다음 Task로 진행하지 않는다.**

---

## Task 2: platform-svc 마스킹 유틸

**Files:**
- Create: `devpath-platform-svc/src/main/java/ai/devpath/platform/support/SensitiveTextMasker.java`
- Test: `devpath-platform-svc/src/test/java/ai/devpath/platform/support/SensitiveTextMaskerTest.java`

**Interfaces:**
- Produces: `SensitiveTextMasker.mask(String) -> String`, `SensitiveTextMasker.maskAndTruncate(String, int) -> String`. Task 3이 접수 시 호출한다.

- [ ] **Step 1: 브랜치 생성 (develop 정리 포함)**

platform-svc는 7월 말 브랜치에 체크아웃돼 있다. 반드시 develop으로 돌린 뒤 분기한다.

```bash
git -C D:/workspace/dpa/devpath-platform-svc checkout develop
git -C D:/workspace/dpa/devpath-platform-svc pull
git -C D:/workspace/dpa/devpath-platform-svc checkout -b feat/support-request
```

- [ ] **Step 2: 실패하는 테스트 작성**

`src/test/java/ai/devpath/platform/support/SensitiveTextMaskerTest.java`:

```java
package ai.devpath.platform.support;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.api.Test;

/**
 * 마스킹 케이스 표 — 스펙 §6.3.
 * dp_core 의 sensitive_text_masker_test.dart 와 **입력·기대 출력이 완전히 같다.**
 * 한쪽만 고치면 두 구현이 어긋난다.
 */
class SensitiveTextMaskerTest {

  @ParameterizedTest
  @CsvSource(delimiter = '|', value = {
      "연락처는 hong@example.com 입니다|연락처는 [EMAIL] 입니다",
      "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc|Authorization=[REDACTED]",
      "token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc 만료|token [TOKEN] 만료",
      "연결 실패 jdbc:postgresql://db:5432/devpath?user=x|연결 실패 [DSN]",
      "주민번호 900101-1234567 조회|주민번호 [RRN] 조회",
      "카드 1234-5678-9012-3456 승인|카드 [CARD] 승인",
      "전화 010-1234-5678 로 연락|전화 [PHONE] 로 연락",
      "파일 C:\\Users\\deepe\\project\\a.txt 없음|파일 [PATH]\\project\\a.txt 없음",
      "경로 /home/ubuntu/app/x.log 실패|경로 [PATH]/app/x.log 실패",
      "서버 10.0.1.23 응답 없음|서버 [IP] 응답 없음",
      "정상 메시지입니다|정상 메시지입니다",
  })
  void masksBySpecTable(String input, String expected) {
    assertThat(SensitiveTextMasker.mask(input)).isEqualTo(expected);
  }

  @Test
  void emptyAndNullPassThrough() {
    assertThat(SensitiveTextMasker.mask("")).isEqualTo("");
    assertThat(SensitiveTextMasker.mask(null)).isNull();
  }

  @Test
  void truncationHappensAfterMasking() {
    // 절단이 마스킹보다 뒤여야 잘린 토큰 조각이 남지 않는다.
    String input = "메일 hong@example.com 그리고 " + "가".repeat(600);
    String out = SensitiveTextMasker.maskAndTruncate(input, 500);
    assertThat(out).hasSize(500);
    assertThat(out).startsWith("메일 [EMAIL] 그리고");
    assertThat(out).doesNotContain("hong@example.com");
  }
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*SensitiveTextMaskerTest*'`
Expected: FAIL — `cannot find symbol: class SensitiveTextMasker` (컴파일 오류)

- [ ] **Step 4: 구현**

`src/main/java/ai/devpath/platform/support/SensitiveTextMasker.java`:

```java
package ai.devpath.platform.support;

import java.util.List;
import java.util.regex.Pattern;

/**
 * 민감 패턴 마스킹 — 스펙 §6.2. 규칙 순서가 결과를 결정하므로 <b>순서를 바꾸지 않는다.</b>
 *
 * <p>dp_core 의 {@code SensitiveTextMasker}(Dart)와 같은 규칙·같은 순서다. 한쪽만 고치면
 * 두 구현이 어긋나고, 스펙 §6.3 케이스 표 테스트가 그 어긋남을 잡는다.
 *
 * <p>패턴 문자열에 {@code (?i)} 인라인 플래그와 lookbehind 를 쓰지 않는다 —
 * Dart {@code RegExp} 가 지원하지 않아 두 구현을 같은 문자열로 유지할 수 없게 된다.
 */
public final class SensitiveTextMasker {

  private SensitiveTextMasker() {}

  private record Rule(Pattern pattern, String replacement) {}

  private static final List<Rule> RULES = List.of(
      // 1. 키=값 형태 비밀. 규칙 2보다 먼저다 — 반대면 "Authorization=[REDACTED] [TOKEN]" 이 남는다.
      //    값 패턴의 (Bearer\s+)? 도 같은 이유(헤더 값이 두 토큰이라 \S+ 하나로는 본체가 남는다).
      new Rule(Pattern.compile(
          "(api[_-]?key|authorization|password|secret|token)\\s*[:=]\\s*(Bearer\\s+)?[^\\s,;]+",
          Pattern.CASE_INSENSITIVE), "$1=[REDACTED]"),
      // 2. 키 없이 노출된 JWT
      new Rule(Pattern.compile("eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]*"), "[TOKEN]"),
      // 3. DB 접속 문자열. 이메일·IP 보다 먼저 — 통째로 지워야 호스트·계정 흔적이 안 남는다.
      new Rule(Pattern.compile("(jdbc:|postgresql://|postgres://|mysql://|redis://)\\S+"), "[DSN]"),
      // 4. 이메일
      new Rule(Pattern.compile("[\\w.+-]+@[\\w-]+\\.[\\w.-]+"), "[EMAIL]"),
      // 5. 카드(16자리). 주민번호(13자리)보다 먼저 — 반대면 구분자 없는 16자리의 중간
      //    13자리가 RRN 으로 잡혀 카드번호를 조각낸다.
      new Rule(Pattern.compile("\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}"), "[CARD]"),
      // 6. 주민등록번호
      new Rule(Pattern.compile("\\d{6}-?[1-4]\\d{6}"), "[RRN]"),
      // 7. 휴대전화
      new Rule(Pattern.compile("01[016789]-?\\d{3,4}-?\\d{4}"), "[PHONE]"),
      // 8. 윈도 홈 경로 — 사용자명까지만 지우고 하위 경로는 진단용으로 남긴다.
      new Rule(Pattern.compile("[A-Za-z]:\\\\Users\\\\[^\\\\\\s]+"), "[PATH]"),
      // 9. POSIX 홈 경로 — 같은 이유.
      new Rule(Pattern.compile("/(home|Users)/[^/\\s]+"), "[PATH]"),
      // 10. IPv4. 마지막이다 — 앞 규칙이 끝난 뒤 남은 것만 보게 해 오탐을 줄인다.
      new Rule(Pattern.compile("\\b\\d{1,3}(\\.\\d{1,3}){3}\\b"), "[IP]"));

  /** null·빈 문자열은 그대로 통과한다. */
  public static String mask(String input) {
    if (input == null || input.isEmpty()) {
      return input;
    }
    String out = input;
    for (Rule r : RULES) {
      out = r.pattern().matcher(out).replaceAll(r.replacement());
    }
    return out;
  }

  /** 마스킹 후 절단. 절단이 뒤여야 잘린 토큰 조각이 남지 않는다. */
  public static String maskAndTruncate(String input, int max) {
    String masked = mask(input);
    if (masked == null || masked.length() <= max) {
      return masked;
    }
    return masked.substring(0, max);
  }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd D:/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*SensitiveTextMaskerTest*'`
Expected: PASS (13 tests — 파라미터 11 + 단독 2)

- [ ] **Step 6: 커밋**

```bash
git -C D:/workspace/dpa/devpath-platform-svc add src/main/java/ai/devpath/platform/support/SensitiveTextMasker.java src/test/java/ai/devpath/platform/support/SensitiveTextMaskerTest.java
git -C D:/workspace/dpa/devpath-platform-svc commit -m "feat: add SensitiveTextMasker with spec case table"
```

---

## Task 3: platform-svc 접수 API

**Files:**
- Create: `src/main/java/ai/devpath/platform/support/SupportRequest.java`
- Create: `src/main/java/ai/devpath/platform/support/SupportRequestFailure.java`
- Create: `src/main/java/ai/devpath/platform/support/SupportRequestRepository.java`
- Create: `src/main/java/ai/devpath/platform/support/SupportRequestFailureRepository.java`
- Create: `src/main/java/ai/devpath/platform/support/SupportService.java`
- Create: `src/main/java/ai/devpath/platform/support/SupportController.java`
- Create: `src/main/java/ai/devpath/platform/support/dto/SupportCreateRequest.java`
- Create: `src/main/java/ai/devpath/platform/support/dto/SupportCreatedView.java`
- Test: `src/test/java/ai/devpath/platform/support/SupportControllerTest.java`

**Interfaces:**
- Consumes: `SensitiveTextMasker.mask/maskAndTruncate` (Task 2), `support_requests`·`support_request_failures` 테이블 (Task 1)
- Produces:
  - `SupportRequest` 엔티티 — getter/setter: `getId/getReporterId/getType/getTitle/getBody/getPagePath/getAppVersion/getUserAgent/getViewport/getTraceId/getErrorCode/getOccurredAt/getStatus/getAdminNote/getHandledBy/getHandledAt/getCreatedAt`
  - `SupportRequestFailure` 엔티티 — `getId/getRequestId/getSeq/getMethod/getPath/getStatusCode/getErrorCode/getTraceId/getMessage/getOccurredAt`
  - `SupportRequestRepository extends JpaRepository<SupportRequest, Long>` — `findByIdLessThanOrderByIdDesc(long, Pageable)`, `findByStatusAndIdLessThanOrderByIdDesc(String, long, Pageable)`, `findByTypeAndIdLessThanOrderByIdDesc(String, long, Pageable)`, `findByStatusAndTypeAndIdLessThanOrderByIdDesc(String, String, long, Pageable)`
  - `SupportRequestFailureRepository extends JpaRepository<SupportRequestFailure, Long>` — `findByRequestIdOrderBySeqAsc(long)`, `countByRequestId(long)`
  - `SupportService.create(long reporterId, SupportCreateRequest req) -> SupportRequest`
  - `SupportCreatedView(long id)` — Task 9의 web 모델이 이 형태를 파싱한다

- [ ] **Step 1: DTO 작성 (테스트가 참조하므로 먼저)**

`src/main/java/ai/devpath/platform/support/dto/SupportCreateRequest.java`:

```java
package ai.devpath.platform.support.dto;

import java.util.List;

/**
 * 접수 요청. 날짜는 <b>String ISO-8601</b>로 받는다 — 서비스에서 {@code Instant.parse} 한다.
 * (jsr310 모듈 의존 없이 계약을 단순하게 유지하기 위함. 파싱 실패는 null 로 흡수한다.)
 */
public record SupportCreateRequest(String type, String title, String body, Context context) {

  public record Context(
      String pagePath,
      String appVersion,
      String userAgent,
      String viewport,
      String traceId,
      String errorCode,
      String occurredAt,
      List<Failure> failures) {}

  public record Failure(
      String method,
      String path,
      Integer statusCode,
      String errorCode,
      String traceId,
      String message,
      String occurredAt) {}
}
```

`src/main/java/ai/devpath/platform/support/dto/SupportCreatedView.java`:

```java
package ai.devpath.platform.support.dto;

/** 접수 성공 응답. 프론트가 접수 번호로 스낵바에 표시한다. */
public record SupportCreatedView(long id) {}
```

- [ ] **Step 2: 실패하는 테스트 작성**

`src/test/java/ai/devpath/platform/support/SupportControllerTest.java`:

```java
package ai.devpath.platform.support;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
import org.springframework.test.web.servlet.MockMvc;

/**
 * 접수 API 계약.
 *
 * <p>권한 테스트는 {@code jwt()} 후처리기가 아니라 <b>실제 HS256 서명 JWT</b>를 쓴다 —
 * 후처리기는 authority 를 직접 주입해 SecurityConfig 의 role→ROLE_* 변환기를 우회한다.
 *
 * <p>건수 단언은 <b>델타</b>로 한다(롤백 없는 통합 테스트라 절대값은 다른 테스트에 오염된다).
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SupportControllerTest {

  @Value("${devpath.auth.jwt-secret}") String secret;

  @Autowired MockMvc mvc;
  @Autowired SupportRequestRepository requests;
  @Autowired SupportRequestFailureRepository failures;

  @Test
  void createsRequestWithMaskedFailures() throws Exception {
    long before = requests.count();

    String json = """
        {"type":"ERROR","title":"경로 화면이 멈춰요","body":"진행률 40%에서 멈춥니다.",
         "context":{"pagePath":"/path","appVersion":"0.1.0+42","userAgent":"UA","viewport":"1920x1080",
           "errorCode":"PATH_GENERATION_FAILED","occurredAt":"2026-08-03T10:11:12Z",
           "failures":[{"method":"POST","path":"/learning-paths","statusCode":500,
             "errorCode":"INTERNAL_ERROR","message":"문의: hong@example.com",
             "occurredAt":"2026-08-03T10:11:09Z"}]}}
        """;

    String res = mvc.perform(post("/support/requests")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("7", "LEARNER"))
            .contentType(MediaType.APPLICATION_JSON)
            .content(json.getBytes(StandardCharsets.UTF_8)))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.id").isNumber())
        .andReturn().getResponse().getContentAsString();

    assertThat(requests.count()).isEqualTo(before + 1);

    long id = Long.parseLong(res.replaceAll("\\D+", ""));
    SupportRequest saved = requests.findById(id).orElseThrow();
    assertThat(saved.getReporterId()).isEqualTo(7L);
    assertThat(saved.getStatus()).isEqualTo("OPEN");
    assertThat(saved.getPagePath()).isEqualTo("/path");

    var rows = failures.findByRequestIdOrderBySeqAsc(id);
    assertThat(rows).hasSize(1);
    assertThat(rows.get(0).getSeq()).isEqualTo((short) 0);
    // 서버 재마스킹 — 클라가 마스킹을 건너뛰었어도 원문이 저장되지 않는다.
    assertThat(rows.get(0).getMessage()).isEqualTo("문의: [EMAIL]");
  }

  @Test
  void reporterIdComesFromJwtNotBody() throws Exception {
    String json = """
        {"type":"INQUIRY","title":"문의","body":"내용","context":{"reporterId":999}}
        """;
    String res = mvc.perform(post("/support/requests")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("11", "LEARNER"))
            .contentType(MediaType.APPLICATION_JSON)
            .content(json.getBytes(StandardCharsets.UTF_8)))
        .andExpect(status().isCreated())
        .andReturn().getResponse().getContentAsString();

    long id = Long.parseLong(res.replaceAll("\\D+", ""));
    assertThat(requests.findById(id).orElseThrow().getReporterId()).isEqualTo(11L);
  }

  @Test
  void keepsOnlyFirstTenFailures() throws Exception {
    StringBuilder items = new StringBuilder();
    for (int i = 0; i < 11; i++) {
      if (i > 0) items.append(',');
      items.append("""
          {"method":"GET","path":"/x/%d","statusCode":500,"occurredAt":"2026-08-03T10:00:00Z"}"""
          .formatted(i));
    }
    String json = """
        {"type":"ERROR","title":"제목","body":"본문","context":{"failures":[%s]}}"""
        .formatted(items);

    String res = mvc.perform(post("/support/requests")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("7", "LEARNER"))
            .contentType(MediaType.APPLICATION_JSON)
            .content(json.getBytes(StandardCharsets.UTF_8)))
        .andExpect(status().isCreated())
        .andReturn().getResponse().getContentAsString();

    long id = Long.parseLong(res.replaceAll("\\D+", ""));
    // 초과분은 400 이 아니라 절단이다 — 부가 정보의 형식 문제로 제보를 거절하지 않는다.
    assertThat(failures.countByRequestId(id)).isEqualTo(10L);
  }

  @Test
  void rejectsBadType() throws Exception {
    mvc.perform(post("/support/requests")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("7", "LEARNER"))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"type\":\"BOGUS\",\"title\":\"제목\",\"body\":\"본문\"}"))
        .andExpect(status().isBadRequest());
  }

  @Test
  void rejectsBlankTitleAndBody() throws Exception {
    mvc.perform(post("/support/requests")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("7", "LEARNER"))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"type\":\"ERROR\",\"title\":\"   \",\"body\":\"본문\"}"))
        .andExpect(status().isBadRequest());

    mvc.perform(post("/support/requests")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("7", "LEARNER"))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"type\":\"ERROR\",\"title\":\"제목\",\"body\":\"\"}"))
        .andExpect(status().isBadRequest());
  }

  @Test
  void requiresAuthentication() throws Exception {
    mvc.perform(post("/support/requests")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"type\":\"ERROR\",\"title\":\"제목\",\"body\":\"본문\"}"))
        .andExpect(status().isUnauthorized());
  }

  /** HS256 서명 토큰. role 이 null 이면 클레임 자체를 넣지 않는다. */
  private String token(String sub, String role) throws Exception {
    JWTClaimsSet.Builder claims = new JWTClaimsSet.Builder()
        .subject(sub)
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

- [ ] **Step 3: 테스트 실패 확인**

Run: `./gradlew test --tests '*SupportControllerTest*'`
Expected: FAIL — 컴파일 오류(`SupportRequestRepository` 등 미존재)

- [ ] **Step 4: 엔티티 구현**

`src/main/java/ai/devpath/platform/support/SupportRequest.java`:

```java
package ai.devpath.platform.support;

import jakarta.persistence.*;
import java.time.Instant;

/** 오류 신고·문의 접수 건. plain JPA(ads/Advertisement 스타일). */
@Entity
@Table(name = "support_requests")
public class SupportRequest {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "reporter_id")
  private Long reporterId;

  /** ERROR | INQUIRY */
  private String type;

  private String title;
  private String body;

  @Column(name = "page_path")
  private String pagePath;

  @Column(name = "app_version")
  private String appVersion;

  @Column(name = "user_agent")
  private String userAgent;

  private String viewport;

  @Column(name = "trace_id")
  private String traceId;

  @Column(name = "error_code")
  private String errorCode;

  @Column(name = "occurred_at")
  private Instant occurredAt;

  /** OPEN | IN_PROGRESS | RESOLVED | WONTFIX */
  private String status = "OPEN";

  @Column(name = "admin_note")
  private String adminNote;

  @Column(name = "handled_by")
  private Long handledBy;

  @Column(name = "handled_at")
  private Instant handledAt;

  @Column(name = "created_at", insertable = false, updatable = false)
  private Instant createdAt;

  public Long getId() { return id; }
  public Long getReporterId() { return reporterId; }
  public void setReporterId(Long v) { this.reporterId = v; }
  public String getType() { return type; }
  public void setType(String v) { this.type = v; }
  public String getTitle() { return title; }
  public void setTitle(String v) { this.title = v; }
  public String getBody() { return body; }
  public void setBody(String v) { this.body = v; }
  public String getPagePath() { return pagePath; }
  public void setPagePath(String v) { this.pagePath = v; }
  public String getAppVersion() { return appVersion; }
  public void setAppVersion(String v) { this.appVersion = v; }
  public String getUserAgent() { return userAgent; }
  public void setUserAgent(String v) { this.userAgent = v; }
  public String getViewport() { return viewport; }
  public void setViewport(String v) { this.viewport = v; }
  public String getTraceId() { return traceId; }
  public void setTraceId(String v) { this.traceId = v; }
  public String getErrorCode() { return errorCode; }
  public void setErrorCode(String v) { this.errorCode = v; }
  public Instant getOccurredAt() { return occurredAt; }
  public void setOccurredAt(Instant v) { this.occurredAt = v; }
  public String getStatus() { return status; }
  public void setStatus(String v) { this.status = v; }
  public String getAdminNote() { return adminNote; }
  public void setAdminNote(String v) { this.adminNote = v; }
  public Long getHandledBy() { return handledBy; }
  public void setHandledBy(Long v) { this.handledBy = v; }
  public Instant getHandledAt() { return handledAt; }
  public void setHandledAt(Instant v) { this.handledAt = v; }
  public Instant getCreatedAt() { return createdAt; }
}
```

`src/main/java/ai/devpath/platform/support/SupportRequestFailure.java`:

```java
package ai.devpath.platform.support;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * 제보에 첨부된 최근 API 실패 1건. 부모 참조는 <b>plain Long 컬럼</b>이다 —
 * {@code @OneToMany} cascade 대신 저장·조회를 명시적으로 두어 테스트를 단순하게 유지한다.
 * FK 와 ON DELETE CASCADE 는 DB 제약이 담당한다.
 */
@Entity
@Table(name = "support_request_failures")
public class SupportRequestFailure {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "request_id")
  private Long requestId;

  /** 0 = 가장 최근. (request_id, seq) UNIQUE. */
  private short seq;

  private String method;
  private String path;

  /** 네트워크 실패면 null — 이 구분 자체가 진단 정보다. */
  @Column(name = "status_code")
  private Short statusCode;

  @Column(name = "error_code")
  private String errorCode;

  @Column(name = "trace_id")
  private String traceId;

  private String message;

  @Column(name = "occurred_at")
  private Instant occurredAt;

  public Long getId() { return id; }
  public Long getRequestId() { return requestId; }
  public void setRequestId(Long v) { this.requestId = v; }
  public short getSeq() { return seq; }
  public void setSeq(short v) { this.seq = v; }
  public String getMethod() { return method; }
  public void setMethod(String v) { this.method = v; }
  public String getPath() { return path; }
  public void setPath(String v) { this.path = v; }
  public Short getStatusCode() { return statusCode; }
  public void setStatusCode(Short v) { this.statusCode = v; }
  public String getErrorCode() { return errorCode; }
  public void setErrorCode(String v) { this.errorCode = v; }
  public String getTraceId() { return traceId; }
  public void setTraceId(String v) { this.traceId = v; }
  public String getMessage() { return message; }
  public void setMessage(String v) { this.message = v; }
  public Instant getOccurredAt() { return occurredAt; }
  public void setOccurredAt(Instant v) { this.occurredAt = v; }
}
```

- [ ] **Step 5: 리포지토리 구현**

`src/main/java/ai/devpath/platform/support/SupportRequestRepository.java`:

```java
package ai.devpath.platform.support;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * keyset 페이지네이션 — <b>id 내림차순(최신순)</b>.
 * AdminUserController(사용자 목록)는 가입 순이 자연스러워 오름차순이지만, 제보 목록은
 * 최신순이어야 하므로 방향만 반대다. 응답 계약({data,nextCursor,limit})은 동일하다.
 */
public interface SupportRequestRepository extends JpaRepository<SupportRequest, Long> {

  List<SupportRequest> findByIdLessThanOrderByIdDesc(long cursor, Pageable pageable);

  List<SupportRequest> findByStatusAndIdLessThanOrderByIdDesc(
      String status, long cursor, Pageable pageable);

  List<SupportRequest> findByTypeAndIdLessThanOrderByIdDesc(
      String type, long cursor, Pageable pageable);

  List<SupportRequest> findByStatusAndTypeAndIdLessThanOrderByIdDesc(
      String status, String type, long cursor, Pageable pageable);
}
```

`src/main/java/ai/devpath/platform/support/SupportRequestFailureRepository.java`:

```java
package ai.devpath.platform.support;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SupportRequestFailureRepository
    extends JpaRepository<SupportRequestFailure, Long> {

  List<SupportRequestFailure> findByRequestIdOrderBySeqAsc(long requestId);

  long countByRequestId(long requestId);
}
```

- [ ] **Step 6: 서비스 구현**

`src/main/java/ai/devpath/platform/support/SupportService.java`:

```java
package ai.devpath.platform.support;

import ai.devpath.platform.support.dto.SupportCreateRequest;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 접수 로직.
 *
 * <p><b>본문(title·body)만 엄격 검증</b>한다. 부가 정보(failures 개수·컬럼 길이)는 거절이 아니라
 * 절단으로 처리한다 — 제보는 사용자가 이미 문제를 겪은 뒤의 마지막 행동이라, 형식 문제로
 * 제보 자체를 잃게 하면 안 된다.
 */
@Service
public class SupportService {

  private static final int MAX_FAILURES = 10;
  private static final int TITLE_MAX = 200;
  private static final int BODY_MAX = 5000;
  private static final int MESSAGE_MAX = 500;
  private static final int PATH_MAX = 512;
  private static final int UA_MAX = 512;
  private static final int SHORT_MAX = 64;
  private static final int VERSION_MAX = 32;
  private static final int VIEWPORT_MAX = 32;

  private final SupportRequestRepository requests;
  private final SupportRequestFailureRepository failures;

  public SupportService(SupportRequestRepository requests,
      SupportRequestFailureRepository failures) {
    this.requests = requests;
    this.failures = failures;
  }

  @Transactional
  public SupportRequest create(long reporterId, SupportCreateRequest req) {
    String type = req.type();
    if (!"ERROR".equals(type) && !"INQUIRY".equals(type)) {
      throw new IllegalArgumentException("type must be ERROR or INQUIRY");
    }
    String title = req.title() == null ? "" : req.title().trim();
    String body = req.body() == null ? "" : req.body().trim();
    if (title.isEmpty() || title.length() > TITLE_MAX) {
      throw new IllegalArgumentException("title must be 1-" + TITLE_MAX + " characters");
    }
    if (body.isEmpty() || body.length() > BODY_MAX) {
      throw new IllegalArgumentException("body must be 1-" + BODY_MAX + " characters");
    }

    SupportCreateRequest.Context ctx = req.context();
    SupportRequest saved = new SupportRequest();
    saved.setReporterId(reporterId);
    saved.setType(type);
    saved.setTitle(SensitiveTextMasker.mask(title));
    saved.setBody(SensitiveTextMasker.mask(body));
    saved.setStatus("OPEN");
    if (ctx != null) {
      saved.setPagePath(cut(SensitiveTextMasker.mask(stripQuery(ctx.pagePath())), PATH_MAX));
      saved.setAppVersion(cut(ctx.appVersion(), VERSION_MAX));
      saved.setUserAgent(cut(ctx.userAgent(), UA_MAX));
      saved.setViewport(cut(ctx.viewport(), VIEWPORT_MAX));
      saved.setTraceId(cut(ctx.traceId(), SHORT_MAX));
      saved.setErrorCode(cut(ctx.errorCode(), SHORT_MAX));
      saved.setOccurredAt(parseOrNull(ctx.occurredAt()));
    }
    requests.save(saved);

    if (ctx != null && ctx.failures() != null) {
      List<SupportCreateRequest.Failure> list = ctx.failures();
      int n = Math.min(list.size(), MAX_FAILURES);
      for (int i = 0; i < n; i++) {
        SupportCreateRequest.Failure f = list.get(i);
        SupportRequestFailure row = new SupportRequestFailure();
        row.setRequestId(saved.getId());
        row.setSeq((short) i);
        row.setMethod(cut(f.method() == null ? "GET" : f.method(), 8));
        row.setPath(cut(stripQuery(f.path() == null ? "" : f.path()), PATH_MAX));
        row.setStatusCode(f.statusCode() == null ? null : f.statusCode().shortValue());
        row.setErrorCode(cut(f.errorCode(), SHORT_MAX));
        row.setTraceId(cut(f.traceId(), SHORT_MAX));
        // 서버 재마스킹 — 조작된 클라이언트가 원문을 밀어넣어도 원문이 저장되지 않는다.
        row.setMessage(SensitiveTextMasker.maskAndTruncate(f.message(), MESSAGE_MAX));
        Instant at = parseOrNull(f.occurredAt());
        row.setOccurredAt(at == null ? Instant.now() : at);
        failures.save(row);
      }
    }
    return saved;
  }

  /** 쿼리스트링 제거 — 클라가 이미 빼지만 서버도 보장한다. */
  private static String stripQuery(String path) {
    if (path == null) {
      return null;
    }
    int q = path.indexOf('?');
    return q < 0 ? path : path.substring(0, q);
  }

  private static String cut(String s, int max) {
    if (s == null) {
      return null;
    }
    return s.length() <= max ? s : s.substring(0, max);
  }

  /** 파싱 실패는 null 로 흡수한다 — 부가 정보의 형식 문제로 제보를 잃지 않는다. */
  private static Instant parseOrNull(String iso) {
    if (iso == null || iso.isBlank()) {
      return null;
    }
    try {
      return Instant.parse(iso);
    } catch (DateTimeParseException e) {
      return null;
    }
  }
}
```

- [ ] **Step 7: 컨트롤러 구현**

`src/main/java/ai/devpath/platform/support/SupportController.java`:

```java
package ai.devpath.platform.support;

import ai.devpath.platform.support.dto.SupportCreateRequest;
import ai.devpath.platform.support.dto.SupportCreatedView;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 사용자 접수. 관리자 조회·전이는 {@link AdminSupportController}.
 *
 * <p>SecurityConfig 의 {@code anyRequest().authenticated()} 로 보호된다 — /support/** 는
 * permitAll 목록에 없다. reporterId 는 요청 본문이 아니라 <b>JWT sub</b>에서 취한다.
 */
@RestController
@RequestMapping("/support")
public class SupportController {

  private final SupportService service;

  public SupportController(SupportService service) {
    this.service = service;
  }

  @PostMapping("/requests")
  public ResponseEntity<SupportCreatedView> create(@AuthenticationPrincipal Jwt jwt,
      @RequestBody SupportCreateRequest req) {
    long reporterId = Long.parseLong(jwt.getSubject());
    SupportRequest saved = service.create(reporterId, req);
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(new SupportCreatedView(saved.getId() == null ? 0L : saved.getId()));
  }
}
```

- [ ] **Step 8: 테스트 통과 확인**

Run: `cd D:/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*SupportControllerTest*'`
Expected: PASS (6 tests)

실패 시 확인 순서: ① `dpa-test-pg` 컨테이너가 떠 있는가 ② Task 1 Step 7의 `flyway_schema_history` 행이 있는가 ③ `--refresh-dependencies`로 shared를 다시 받았는가.

- [ ] **Step 9: 커밋**

```bash
git -C D:/workspace/dpa/devpath-platform-svc add src/main/java/ai/devpath/platform/support src/test/java/ai/devpath/platform/support/SupportControllerTest.java
git -C D:/workspace/dpa/devpath-platform-svc commit -m "feat: add support request intake API"
```

---

## Task 4: platform-svc admin API (목록 · 상세 · 상태 전이)

목록·상세·전이를 한 Task로 묶는다 — 같은 컨트롤러·같은 DTO 세트라 리뷰어가 하나만 따로 반려할 여지가 없다.

**Files:**
- Create: `src/main/java/ai/devpath/platform/support/AdminSupportController.java`
- Create: `src/main/java/ai/devpath/platform/support/dto/AdminSupportRow.java`
- Create: `src/main/java/ai/devpath/platform/support/dto/AdminSupportPage.java`
- Create: `src/main/java/ai/devpath/platform/support/dto/AdminSupportDetail.java`
- Create: `src/main/java/ai/devpath/platform/support/dto/SupportFailureView.java`
- Create: `src/main/java/ai/devpath/platform/support/dto/StatusUpdateRequest.java`
- Modify: `src/main/java/ai/devpath/platform/support/SupportService.java` (메서드 3개 추가)
- Test: `src/test/java/ai/devpath/platform/support/AdminSupportControllerTest.java`

**Interfaces:**
- Consumes: Task 3의 엔티티·리포지토리·`SupportService`
- Produces:
  - `GET /admin/support-requests?status=&type=&cursor=&limit=` → `{data,nextCursor,limit}`
  - `GET /admin/support-requests/{id}` → `AdminSupportDetail`
  - `POST /admin/support-requests/{id}/status` body `{status, adminNote?}` → `AdminSupportDetail`
  - `SupportService.list(String status, String type, String cursor, int limit) -> AdminSupportPage`
  - `SupportService.detail(long id) -> AdminSupportDetail`
  - `SupportService.updateStatus(long id, long adminId, String status, String adminNote) -> AdminSupportDetail`
  - Task 11의 admin 화면이 이 3개 계약을 그대로 소비한다.

**에러 계약 (실측 확인함):**
- 잘못된 입력 → `IllegalArgumentException` → shared `ApiExceptionHandler`가 **`VALIDATION_FAILED` 400** (스펙 문구 "INVALID_ARGUMENT"가 아니라 실제 enum 이름은 `VALIDATION_FAILED`다)
- 없는 id → `new ApiException(ErrorCode.RESOURCE_NOT_FOUND, ...)` → **404**

- [ ] **Step 1: DTO 5개 작성**

`dto/AdminSupportRow.java`:

```java
package ai.devpath.platform.support.dto;

/** 관리자 목록 행. 날짜는 String ISO-8601. */
public record AdminSupportRow(
    long id,
    String type,
    String title,
    String status,
    String pagePath,
    Long reporterId,
    long failureCount,
    String createdAt) {}
```

`dto/AdminSupportPage.java`:

```java
package ai.devpath.platform.support.dto;

import java.util.List;

/**
 * GET /admin/support-requests 응답 봉투.
 * 프론트 dp_core Page.fromJson 계약: { data, nextCursor, limit }.
 * Map.of()는 null 값을 허용하지 않으므로 전용 record 를 쓴다(AdminUsersPage 와 동일).
 */
public record AdminSupportPage(List<AdminSupportRow> data, String nextCursor, int limit) {}
```

`dto/SupportFailureView.java`:

```java
package ai.devpath.platform.support.dto;

/** 상세의 실패 목록 1행(seq 오름차순). statusCode 는 네트워크 실패면 null. */
public record SupportFailureView(
    short seq,
    String method,
    String path,
    Short statusCode,
    String errorCode,
    String traceId,
    String message,
    String occurredAt) {}
```

`dto/AdminSupportDetail.java`:

```java
package ai.devpath.platform.support.dto;

import java.util.List;

/** 관리자 상세 = 목록 필드 전체 + 본문 + 수집 컨텍스트 + 실패 목록 + 처리 정보. */
public record AdminSupportDetail(
    long id,
    String type,
    String title,
    String body,
    String status,
    String pagePath,
    String appVersion,
    String userAgent,
    String viewport,
    String traceId,
    String errorCode,
    String occurredAt,
    Long reporterId,
    String adminNote,
    Long handledBy,
    String handledAt,
    String createdAt,
    List<SupportFailureView> failures) {}
```

`dto/StatusUpdateRequest.java`:

```java
package ai.devpath.platform.support.dto;

/** adminNote 는 선택. 주어지면 덮어쓴다(누적 이력이 아니다). */
public record StatusUpdateRequest(String status, String adminNote) {}
```

- [ ] **Step 2: 실패하는 테스트 작성**

`src/test/java/ai/devpath/platform/support/AdminSupportControllerTest.java`:

```java
package ai.devpath.platform.support;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import ai.devpath.platform.support.dto.SupportCreateRequest;
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
import org.springframework.test.web.servlet.MockMvc;

/** 관리자 API 의 권한·계약. 실서명 JWT 로 role→ROLE_* 변환기를 실제로 통과시킨다. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminSupportControllerTest {

  @Value("${devpath.auth.jwt-secret}") String secret;

  @Autowired MockMvc mvc;
  @Autowired SupportService service;
  @Autowired SupportRequestRepository requests;

  @Test
  void listIsForbiddenForNonAdmin() throws Exception {
    mvc.perform(get("/admin/support-requests")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("7", "LEARNER")))
        .andExpect(status().isForbidden());
  }

  @Test
  void listIsUnauthorizedWithoutToken() throws Exception {
    mvc.perform(get("/admin/support-requests")).andExpect(status().isUnauthorized());
  }

  @Test
  void listReturnsPageEnvelopeNewestFirst() throws Exception {
    long a = seed("먼저 접수").getId();
    long b = seed("나중 접수").getId();

    mvc.perform(get("/admin/support-requests?status=OPEN&limit=100")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("1", "ADMIN")))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.limit").value(100))
        .andExpect(jsonPath("$.data").isArray());

    // 최신순: 나중에 만든 b 가 a 보다 앞에 온다.
    String body = mvc.perform(get("/admin/support-requests?limit=100")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("1", "ADMIN")))
        .andReturn().getResponse().getContentAsString();
    assertThat(body.indexOf("\"id\":" + b)).isLessThan(body.indexOf("\"id\":" + a));
  }

  @Test
  void detailIncludesFailuresInSeqOrder() throws Exception {
    long id = seedWithFailures().getId();

    mvc.perform(get("/admin/support-requests/" + id)
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("1", "ADMIN")))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.failures.length()").value(2))
        .andExpect(jsonPath("$.failures[0].seq").value(0))
        .andExpect(jsonPath("$.failures[1].seq").value(1))
        .andExpect(jsonPath("$.failures[0].path").value("/first"));
  }

  @Test
  void detailIsNotFoundForUnknownId() throws Exception {
    mvc.perform(get("/admin/support-requests/99999999")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("1", "ADMIN")))
        .andExpect(status().isNotFound());
  }

  @Test
  void statusTransitionRecordsHandler() throws Exception {
    long id = seed("전이 대상").getId();

    mvc.perform(post("/admin/support-requests/" + id + "/status")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("3", "ADMIN"))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"status\":\"IN_PROGRESS\",\"adminNote\":\"재현 확인함\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
        .andExpect(jsonPath("$.adminNote").value("재현 확인함"))
        .andExpect(jsonPath("$.handledBy").value(3));

    SupportRequest after = requests.findById(id).orElseThrow();
    assertThat(after.getHandledAt()).isNotNull();
  }

  @Test
  void reopeningClearsHandler() throws Exception {
    long id = seed("되돌릴 건").getId();
    service.updateStatus(id, 3L, "RESOLVED", "처리함");

    mvc.perform(post("/admin/support-requests/" + id + "/status")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("3", "ADMIN"))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"status\":\"OPEN\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("OPEN"));

    SupportRequest after = requests.findById(id).orElseThrow();
    assertThat(after.getHandledBy()).isNull();
    assertThat(after.getHandledAt()).isNull();
  }

  @Test
  void rejectsUnknownStatus() throws Exception {
    long id = seed("이상값").getId();

    mvc.perform(post("/admin/support-requests/" + id + "/status")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("3", "ADMIN"))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"status\":\"BOGUS\"}"))
        .andExpect(status().isBadRequest());
  }

  @Test
  void statusTransitionIsForbiddenForNonAdmin() throws Exception {
    long id = seed("권한 확인").getId();

    mvc.perform(post("/admin/support-requests/" + id + "/status")
            .header(HttpHeaders.AUTHORIZATION, "Bearer " + token("7", "LEARNER"))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"status\":\"RESOLVED\"}"))
        .andExpect(status().isForbidden());
  }

  private SupportRequest seed(String title) {
    return service.create(7L,
        new SupportCreateRequest("ERROR", title, "본문", null));
  }

  private SupportRequest seedWithFailures() {
    var ctx = new SupportCreateRequest.Context("/path", "0.1.0", "UA", "800x600", null, null,
        "2026-08-03T10:00:00Z",
        List.of(
            new SupportCreateRequest.Failure("GET", "/first", 500, "INTERNAL_ERROR", null,
                "첫 실패", "2026-08-03T10:00:01Z"),
            new SupportCreateRequest.Failure("POST", "/second", null, null, null,
                "두 번째", "2026-08-03T10:00:02Z")));
    return service.create(7L, new SupportCreateRequest("ERROR", "실패 포함", "본문", ctx));
  }

  private String token(String sub, String role) throws Exception {
    JWTClaimsSet.Builder claims = new JWTClaimsSet.Builder()
        .subject(sub)
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

- [ ] **Step 3: 테스트 실패 확인**

Run: `./gradlew test --tests '*AdminSupportControllerTest*'`
Expected: FAIL — 컴파일 오류(`service.list` 등 미존재)

- [ ] **Step 4: SupportService에 조회·전이 메서드 추가**

`SupportService.java`의 클래스 끝(마지막 `private static Instant parseOrNull` 바로 위)에 다음을 추가하고, 상단 import에 `ai.devpath.platform.support.dto.*` 5개와 `ai.devpath.shared.error.ApiException`·`ai.devpath.shared.error.ErrorCode`·`org.springframework.data.domain.PageRequest`를 더한다:

```java
  private static final int LIMIT_MAX = 100;
  private static final List<String> STATUSES =
      List.of("OPEN", "IN_PROGRESS", "RESOLVED", "WONTFIX");

  /**
   * keyset 목록 — id 내림차순(최신순). cursor 가 없으면 처음부터, 있으면 id &lt; cursor 만.
   * nextCursor 는 <b>꽉 찬 페이지일 때만</b> 마지막 행 id, 아니면 null.
   */
  @Transactional(readOnly = true)
  public AdminSupportPage list(String status, String type, String cursor, int limit) {
    int size = Math.min(Math.max(limit, 1), LIMIT_MAX);
    long before = (cursor == null || cursor.isBlank()) ? Long.MAX_VALUE : Long.parseLong(cursor);
    var pageable = PageRequest.of(0, size);

    boolean hasStatus = status != null && !status.isBlank();
    boolean hasType = type != null && !type.isBlank();
    List<SupportRequest> rows;
    if (hasStatus && hasType) {
      rows = requests.findByStatusAndTypeAndIdLessThanOrderByIdDesc(status, type, before, pageable);
    } else if (hasStatus) {
      rows = requests.findByStatusAndIdLessThanOrderByIdDesc(status, before, pageable);
    } else if (hasType) {
      rows = requests.findByTypeAndIdLessThanOrderByIdDesc(type, before, pageable);
    } else {
      rows = requests.findByIdLessThanOrderByIdDesc(before, pageable);
    }

    String nextCursor = (rows.size() == size)
        ? String.valueOf(rows.get(rows.size() - 1).getId())
        : null;

    List<AdminSupportRow> data = rows.stream()
        .map(r -> new AdminSupportRow(
            r.getId(), r.getType(), r.getTitle(), r.getStatus(), r.getPagePath(),
            r.getReporterId(), failures.countByRequestId(r.getId()), iso(r.getCreatedAt())))
        .toList();
    return new AdminSupportPage(data, nextCursor, size);
  }

  @Transactional(readOnly = true)
  public AdminSupportDetail detail(long id) {
    return toDetail(find(id));
  }

  /**
   * 상태 전이. handled_by = 관리자 id, handled_at = now.
   * OPEN 으로 되돌리면 둘 다 NULL 로 초기화한다(처리 이력이 없는 상태로 복귀).
   */
  @Transactional
  public AdminSupportDetail updateStatus(long id, long adminId, String status, String adminNote) {
    if (status == null || !STATUSES.contains(status)) {
      throw new IllegalArgumentException("status must be one of " + STATUSES);
    }
    SupportRequest r = find(id);
    r.setStatus(status);
    if (adminNote != null) {
      r.setAdminNote(adminNote);
    }
    if ("OPEN".equals(status)) {
      r.setHandledBy(null);
      r.setHandledAt(null);
    } else {
      r.setHandledBy(adminId);
      r.setHandledAt(Instant.now());
    }
    requests.save(r);
    return toDetail(r);
  }

  private SupportRequest find(long id) {
    return requests.findById(id).orElseThrow(() ->
        new ApiException(ErrorCode.RESOURCE_NOT_FOUND, "support request not found: " + id));
  }

  private AdminSupportDetail toDetail(SupportRequest r) {
    List<SupportFailureView> rows = failures.findByRequestIdOrderBySeqAsc(r.getId()).stream()
        .map(f -> new SupportFailureView(f.getSeq(), f.getMethod(), f.getPath(), f.getStatusCode(),
            f.getErrorCode(), f.getTraceId(), f.getMessage(), iso(f.getOccurredAt())))
        .toList();
    return new AdminSupportDetail(
        r.getId(), r.getType(), r.getTitle(), r.getBody(), r.getStatus(), r.getPagePath(),
        r.getAppVersion(), r.getUserAgent(), r.getViewport(), r.getTraceId(), r.getErrorCode(),
        iso(r.getOccurredAt()), r.getReporterId(), r.getAdminNote(), r.getHandledBy(),
        iso(r.getHandledAt()), iso(r.getCreatedAt()), rows);
  }

  /** 날짜는 String ISO-8601 로 내보낸다(요청 계약과 대칭). */
  private static String iso(Instant at) {
    return at == null ? null : at.toString();
  }
```

- [ ] **Step 5: 컨트롤러 구현**

`src/main/java/ai/devpath/platform/support/AdminSupportController.java`:

```java
package ai.devpath.platform.support;

import ai.devpath.platform.support.dto.AdminSupportDetail;
import ai.devpath.platform.support.dto.AdminSupportPage;
import ai.devpath.platform.support.dto.StatusUpdateRequest;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 관리자 제보 처리.
 *
 * <p>경로가 {@code /admin/**} 라 SecurityConfig 의 {@code hasRole("ADMIN")} 로 이미 보호된다.
 * ③ 커뮤니티 신고가 게이트웨이의 {@code /admin/**} 선점 때문에
 * {@code /community/admin/...} 로 우회해야 했던 것과 달리, ④는 소유가 platform-svc 라
 * 그 선점이 오히려 유리하게 작용한다 — 게이트웨이 추가 작업이 없다.
 */
@RestController
@RequestMapping("/admin/support-requests")
public class AdminSupportController {

  private final SupportService service;

  public AdminSupportController(SupportService service) {
    this.service = service;
  }

  @GetMapping
  public AdminSupportPage list(
      @RequestParam(required = false) String status,
      @RequestParam(required = false) String type,
      @RequestParam(required = false) String cursor,
      @RequestParam(required = false, defaultValue = "20") int limit) {
    return service.list(status, type, cursor, limit);
  }

  @GetMapping("/{id}")
  public AdminSupportDetail detail(@PathVariable long id) {
    return service.detail(id);
  }

  @PostMapping("/{id}/status")
  public AdminSupportDetail updateStatus(@AuthenticationPrincipal Jwt jwt,
      @PathVariable long id, @RequestBody StatusUpdateRequest req) {
    long adminId = Long.parseLong(jwt.getSubject());
    return service.updateStatus(id, adminId, req.status(), req.adminNote());
  }
}
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `./gradlew test --tests '*AdminSupportControllerTest*'`
Expected: PASS (9 tests)

- [ ] **Step 7: 전체 스위트 회귀 확인**

Run: `cd D:/workspace/dpa/devpath-platform-svc && ./gradlew test`
Expected: BUILD SUCCESSFUL (기존 테스트 무회귀)

- [ ] **Step 8: 커밋·푸시·PR**

```bash
git -C D:/workspace/dpa/devpath-platform-svc add src/main/java/ai/devpath/platform/support src/test/java/ai/devpath/platform/support
git -C D:/workspace/dpa/devpath-platform-svc commit -m "feat: add admin support request API"
git -C D:/workspace/dpa/devpath-platform-svc push -u origin feat/support-request
gh pr create -R DevPathAi/devpath-platform-svc --base develop --head feat/support-request \
  --title "feat: 오류 신고·문의 접수/관리 API" \
  --body "④ 접수(POST /support/requests) + 관리자 목록/상세/상태전이. 마스킹 2중(클라+서버) 중 서버측."
```

---

## Task 5: gateway `/support/**` 라우트

Task 2~4와 독립이다(게이트웨이는 경로만 안다). 병렬 진행 가능.

**Files:**
- Modify: `devpath-gateway/src/main/resources/application.yml:12`
- Test: `devpath-gateway/src/test/java/ai/devpath/gateway/SupportRouteTest.java`

**Interfaces:**
- Produces: `/support/**` → `PLATFORM_URI` 라우팅. `/admin/**`는 이미 같은 라우트에 있어 추가 작업이 없다.

- [ ] **Step 1: 브랜치 생성 (develop 정리 포함)**

gateway는 `fix/actuator-probe-permit`에 체크아웃돼 있다.

```bash
git -C D:/workspace/dpa/devpath-gateway checkout develop
git -C D:/workspace/dpa/devpath-gateway pull
git -C D:/workspace/dpa/devpath-gateway checkout -b feat/support-request
```

- [ ] **Step 2: 실패하는 테스트 작성**

`src/test/java/ai/devpath/gateway/SupportRouteTest.java`:

```java
package ai.devpath.gateway;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.ReactiveJwtDecoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.reactive.server.WebTestClient;
import reactor.core.publisher.Mono;

/** /support/** 가 platform-auth 라우트에 매칭되는지. CommunityRouteTest 와 같은 형태다. */
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class SupportRouteTest {

  @LocalServerPort int port;

  @MockitoBean ReactiveJwtDecoder jwtDecoder;

  WebTestClient web;

  @BeforeEach
  void setUp() {
    web = WebTestClient.bindToServer().baseUrl("http://localhost:" + port).build();
    when(jwtDecoder.decode("test-token")).thenReturn(Mono.just(jwt()));
  }

  @Test
  void supportRequestsRequireJwt() {
    web.post().uri("/support/requests").exchange()
        .expectStatus().isUnauthorized();
  }

  @Test
  void authenticatedSupportRequestMatchesRoute() {
    web.post().uri("/support/requests")
        .header(HttpHeaders.AUTHORIZATION, "Bearer test-token")
        .exchange()
        .expectStatus().value(SupportRouteTest::assertGatewayMatchedRoute);
  }

  private static void assertGatewayMatchedRoute(int status) {
    assertThat(status)
        .isNotEqualTo(HttpStatus.UNAUTHORIZED.value())
        .isNotEqualTo(HttpStatus.FORBIDDEN.value())
        .isNotEqualTo(HttpStatus.NOT_FOUND.value());
  }

  private static Jwt jwt() {
    Instant now = Instant.now();
    return Jwt.withTokenValue("test-token")
        .header("alg", "HS256")
        .subject("42")
        .issuedAt(now)
        .expiresAt(now.plusSeconds(600))
        .claim("scope", "ROLE_LEARNER")
        .build();
  }
}
```

`@MockitoBean` import는 `org.springframework.test.context.bean.override.mockito.MockitoBean`이다(CommunityRouteTest와 동일). 위 코드 상단 import에 추가한다.

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-gateway && ./gradlew test --tests '*SupportRouteTest*'`
Expected: FAIL — `authenticatedSupportRequestMatchesRoute`가 **404**(매칭되는 라우트 없음)

- [ ] **Step 4: 라우트 추가**

`src/main/resources/application.yml`의 `platform-auth` predicates 끝에 `/support/**`를 더한다:

```yaml
            - id: platform-auth
              uri: ${PLATFORM_URI:http://localhost:8081}
              predicates:
                - Path=/oauth2/**,/login/**,/auth/**,/users/**,/admin/**,/consents/**,/beta/**,/ads/**,/support/**
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `./gradlew test --tests '*SupportRouteTest*'`
Expected: PASS (2 tests)

- [ ] **Step 6: 전체 스위트 확인 후 커밋·PR**

```bash
cd D:/workspace/dpa/devpath-gateway && ./gradlew test
git -C D:/workspace/dpa/devpath-gateway add src/main/resources/application.yml src/test/java/ai/devpath/gateway/SupportRouteTest.java
git -C D:/workspace/dpa/devpath-gateway commit -m "feat: route /support/** to platform-svc"
git -C D:/workspace/dpa/devpath-gateway push -u origin feat/support-request
gh pr create -R DevPathAi/devpath-gateway --base develop --head feat/support-request \
  --title "feat: /support/** 라우트 추가" \
  --body "④ 오류 신고·문의 접수 경로. /admin/**는 이미 platform-auth 라우트에 있어 추가 작업 없음."
```

---

## Task 6: dp_core 마스킹 유틸 (Dart)

Task 2(Java)와 **같은 규칙·같은 순서·같은 케이스 표**다. 두 Task의 테스트 표가 어긋나면 두 구현이 갈라진다.

**Files:**
- Create: `packages/dp_core/lib/src/support/sensitive_text_masker.dart`
- Modify: `packages/dp_core/lib/dp_core.dart` (export 1줄)
- Test: `packages/dp_core/test/support/sensitive_text_masker_test.dart`

**Interfaces:**
- Produces: `SensitiveTextMasker.mask(String) -> String`, `SensitiveTextMasker.maskAndTruncate(String?, int) -> String?`. Task 7의 recorder와 Task 10의 다이얼로그 미리보기가 쓴다.

- [ ] **Step 1: 브랜치 생성**

frontend는 현재 `docs/support-request-spec`(스펙 PR #101)에 있다. develop에서 새로 딴다.

```bash
git -C D:/workspace/dpa/devpath-frontend checkout develop
git -C D:/workspace/dpa/devpath-frontend pull
git -C D:/workspace/dpa/devpath-frontend checkout -b feat/support-request
```

- [ ] **Step 2: 실패하는 테스트 작성**

`packages/dp_core/test/support/sensitive_text_masker_test.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

/// 마스킹 케이스 표 — 스펙 §6.3.
/// platform-svc 의 SensitiveTextMaskerTest.java 와 **입력·기대 출력이 완전히 같다.**
/// 한쪽만 고치면 두 구현이 어긋난다.
void main() {
  const cases = <(String, String)>[
    ('연락처는 hong@example.com 입니다', '연락처는 [EMAIL] 입니다'),
    (
      'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc',
      'Authorization=[REDACTED]',
    ),
    (
      'token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc 만료',
      'token [TOKEN] 만료',
    ),
    ('연결 실패 jdbc:postgresql://db:5432/devpath?user=x', '연결 실패 [DSN]'),
    ('주민번호 900101-1234567 조회', '주민번호 [RRN] 조회'),
    ('카드 1234-5678-9012-3456 승인', '카드 [CARD] 승인'),
    ('전화 010-1234-5678 로 연락', '전화 [PHONE] 로 연락'),
    (r'파일 C:\Users\deepe\project\a.txt 없음', r'파일 [PATH]\project\a.txt 없음'),
    ('경로 /home/ubuntu/app/x.log 실패', '경로 [PATH]/app/x.log 실패'),
    ('서버 10.0.1.23 응답 없음', '서버 [IP] 응답 없음'),
    ('정상 메시지입니다', '정상 메시지입니다'),
    ('', ''),
  ];

  group('SensitiveTextMasker', () {
    for (var i = 0; i < cases.length; i++) {
      final (input, expected) = cases[i];
      test('case ${i + 1}', () {
        expect(SensitiveTextMasker.mask(input), expected);
      });
    }

    test('절단은 마스킹보다 뒤 — 잘린 토큰 조각이 남지 않는다', () {
      final input = '메일 hong@example.com 그리고 ${'가' * 600}';
      final out = SensitiveTextMasker.maskAndTruncate(input, 500)!;
      expect(out.length, 500);
      expect(out.startsWith('메일 [EMAIL] 그리고'), isTrue);
      expect(out.contains('hong@example.com'), isFalse);
    });

    test('null 은 그대로 통과', () {
      expect(SensitiveTextMasker.maskAndTruncate(null, 500), isNull);
    });
  });
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/support/sensitive_text_masker_test.dart`
Expected: FAIL — `Undefined name 'SensitiveTextMasker'` (컴파일 오류)

- [ ] **Step 4: 구현**

`packages/dp_core/lib/src/support/sensitive_text_masker.dart`:

```dart
/// 민감 패턴 마스킹 — 스펙 §6.2. 규칙 순서가 결과를 결정하므로 **순서를 바꾸지 않는다.**
///
/// platform-svc 의 `SensitiveTextMasker`(Java)와 같은 규칙·같은 순서다. 한쪽만 고치면
/// 두 구현이 어긋나고, 스펙 §6.3 케이스 표 테스트가 그 어긋남을 잡는다.
///
/// 패턴에 `(?i)` 인라인 플래그와 lookbehind 를 쓰지 않는다 — Dart RegExp 가 지원하지 않는다.
/// 대소문자 무시는 `caseSensitive: false` 로 준다.
///
/// Dart 는 `replaceAll` 치환 문자열의 `$1` 을 해석하지 않으므로 **replaceAllMapped** 를 쓴다.
class SensitiveTextMasker {
  const SensitiveTextMasker._();

  static final List<(RegExp, String Function(Match))> _rules = [
    // 1. 키=값 형태 비밀. 규칙 2보다 먼저다 — 반대면 'Authorization=[REDACTED] [TOKEN]' 이 남는다.
    (
      RegExp(
        r'(api[_-]?key|authorization|password|secret|token)\s*[:=]\s*(Bearer\s+)?[^\s,;]+',
        caseSensitive: false,
      ),
      (m) => '${m[1]}=[REDACTED]',
    ),
    // 2. 키 없이 노출된 JWT
    (
      RegExp(r'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*'),
      (_) => '[TOKEN]',
    ),
    // 3. DB 접속 문자열. 이메일·IP 보다 먼저 — 통째로 지워야 호스트·계정 흔적이 안 남는다.
    (
      RegExp(r'(jdbc:|postgresql://|postgres://|mysql://|redis://)\S+'),
      (_) => '[DSN]',
    ),
    // 4. 이메일
    (RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), (_) => '[EMAIL]'),
    // 5. 카드(16자리). 주민번호(13자리)보다 먼저 — 반대면 구분자 없는 16자리의 중간
    //    13자리가 RRN 으로 잡혀 카드번호를 조각낸다.
    (RegExp(r'\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}'), (_) => '[CARD]'),
    // 6. 주민등록번호
    (RegExp(r'\d{6}-?[1-4]\d{6}'), (_) => '[RRN]'),
    // 7. 휴대전화
    (RegExp(r'01[016789]-?\d{3,4}-?\d{4}'), (_) => '[PHONE]'),
    // 8. 윈도 홈 경로 — 사용자명까지만 지우고 하위 경로는 진단용으로 남긴다.
    (RegExp(r'[A-Za-z]:\\Users\\[^\\\s]+'), (_) => '[PATH]'),
    // 9. POSIX 홈 경로 — 같은 이유.
    (RegExp(r'/(home|Users)/[^/\s]+'), (_) => '[PATH]'),
    // 10. IPv4. 마지막이다 — 앞 규칙이 끝난 뒤 남은 것만 보게 해 오탐을 줄인다.
    (RegExp(r'\b\d{1,3}(\.\d{1,3}){3}\b'), (_) => '[IP]'),
  ];

  /// 빈 문자열은 그대로 통과한다.
  static String mask(String input) {
    if (input.isEmpty) return input;
    var out = input;
    for (final (pattern, replace) in _rules) {
      out = out.replaceAllMapped(pattern, replace);
    }
    return out;
  }

  /// 마스킹 후 절단. 절단이 뒤여야 잘린 토큰 조각이 남지 않는다.
  static String? maskAndTruncate(String? input, int max) {
    if (input == null) return null;
    final masked = mask(input);
    return masked.length <= max ? masked : masked.substring(0, max);
  }
}
```

- [ ] **Step 5: export 추가**

`packages/dp_core/lib/dp_core.dart`의 `export 'src/api/page.dart';` 다음 줄에 추가:

```dart
export 'src/support/sensitive_text_masker.dart';
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/support/sensitive_text_masker_test.dart`
Expected: PASS (14 tests)

- [ ] **Step 7: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add packages/dp_core/lib/src/support/sensitive_text_masker.dart packages/dp_core/lib/dp_core.dart packages/dp_core/test/support/sensitive_text_masker_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(dp_core): add SensitiveTextMasker matching server rules"
```

---

## Task 7: dp_core 링버퍼 + 실패 기록 인터셉터

**Files:**
- Create: `packages/dp_core/lib/src/support/api_failure_log.dart`
- Create: `packages/dp_core/lib/src/support/api_failure_recorder.dart`
- Modify: `packages/dp_core/lib/dp_core.dart` (export 2줄)
- Test: `packages/dp_core/test/support/api_failure_recorder_test.dart`

**Interfaces:**
- Consumes: `SensitiveTextMasker` (Task 6), `ApiException.fromDio` (기존)
- Produces:
  - `ApiFailureEntry({required String method, required String path, int? statusCode, String? errorCode, String? traceId, String? message, required DateTime occurredAt})` + `toJson() -> Map<String, dynamic>`
  - `ApiFailureLog({int capacity = 10})` — `add(ApiFailureEntry)`, `List<ApiFailureEntry> get recent` (**0 = 가장 최근**), `int get length`, `void clear()`
  - `ApiFailureRecorder(ApiFailureLog log, {DateTime Function()? clock}) extends Interceptor`
  - Task 9의 web provider가 `ApiFailureLog`를 provider로 노출하고 recorder를 체인에 삽입한다.

**★이 Task의 핵심 불변식★**

recorder는 **`Auth` 뒤 · `ErrorNormalizer` 앞**에 들어간다.

- index 0에 넣으면 `AuthInterceptor`가 refresh로 자동 복구하는 일시적 401까지 기록되어, 사용자가 겪지도 않은 실패가 제보에 섞인다. (실측 근거: `auth_interceptor.dart:82` — refresh 성공 시 `handler.resolve(res)`로 체인을 **종료**하므로 뒤 인터셉터는 에러를 못 본다. 실패 시에만 `handler.next(err)`로 뒤로 넘긴다.)
- `ErrorNormalizer` 뒤에 넣으면 아무것도 못 본다. `ApiClient.create`가 정규화를 마지막에 두고 `handler.reject()`로 끝내기 때문이다(`api_client.dart:28-39`). dio 5.9.2에서 `reject`는 체인을 종료한다.

따라서 삽입은 `insert(interceptors.length - 1, recorder)`이며, 이는 "정규화가 항상 마지막"이라는 불변식에 의존한다. **Step 2의 마지막 테스트가 그 불변식을 지킨다.**

- [ ] **Step 1: 실패하는 테스트 작성**

`packages/dp_core/test/support/api_failure_recorder_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

/// 고정 상태코드·본문을 돌려주는 어댑터.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.status, this.body);
  final int status;
  final Object body;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _clientWithRecorder(
  ApiFailureLog log, {
  List<Interceptor> before = const [],
  required HttpClientAdapter adapter,
}) {
  final client = ApiClient.create(
    const ApiConfig(baseUrl: 'https://example.test', useMock: false),
    interceptors: before,
  );
  // Auth 뒤 · ErrorNormalizer 앞.
  client.dio.interceptors.insert(
    client.dio.interceptors.length - 1,
    ApiFailureRecorder(log),
  );
  client.dio.httpClientAdapter = adapter;
  return client;
}

void main() {
  group('ApiFailureLog', () {
    test('11건째에 가장 오래된 것이 밀려난다', () {
      final log = ApiFailureLog();
      for (var i = 0; i < 11; i++) {
        log.add(
          ApiFailureEntry(
            method: 'GET',
            path: '/x/$i',
            occurredAt: DateTime.utc(2026, 8, 3, 0, 0, i),
          ),
        );
      }
      expect(log.length, 10);
      // 0 = 가장 최근
      expect(log.recent.first.path, '/x/10');
      expect(log.recent.last.path, '/x/1');
      expect(log.recent.any((e) => e.path == '/x/0'), isFalse);
    });
  });

  group('ApiFailureRecorder', () {
    test('실패를 버퍼에 쌓는다 — 마스킹·쿼리스트링 제거 포함', () async {
      final log = ApiFailureLog();
      final client = _clientWithRecorder(
        log,
        adapter: _FixedAdapter(500, {
          'error': {
            'code': 'INTERNAL_ERROR',
            'message': '문의: hong@example.com',
            'trace_id': 't-1',
          },
        }),
      );

      await expectLater(
        client.post<Map<String, dynamic>>('/learning-paths?draft=1'),
        throwsA(isA<ApiException>()),
      );

      expect(log.length, 1);
      final e = log.recent.first;
      expect(e.method, 'POST');
      expect(e.path, '/learning-paths'); // 쿼리스트링 제거
      expect(e.statusCode, 500);
      expect(e.errorCode, 'INTERNAL_ERROR'); // enum 밖 코드도 원문 보존
      expect(e.traceId, 't-1');
      expect(e.message, '문의: [EMAIL]'); // 기록 시점에 이미 마스킹
    });

    test('refresh 로 복구된 401 은 기록되지 않는다', () async {
      final log = ApiFailureLog();
      final store = InMemoryTokenStore();
      await store.save(access: 'old', refresh: 'r');

      final auth = AuthInterceptor(
        store: store,
        refresh: (_) async => const TokenPair(access: 'new', refresh: 'r'),
        retry: (options) async =>
            Response<dynamic>(requestOptions: options, statusCode: 200, data: const {}),
      );

      final client = _clientWithRecorder(
        log,
        before: [auth],
        adapter: _FixedAdapter(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': '만료'},
        }),
      );

      await client.get<Map<String, dynamic>>('/dashboard');

      // Auth 가 handler.resolve 로 체인을 종료하므로 recorder 에 도달하지 않는다.
      expect(log.length, 0);
    });

    test('refresh 가 실패한 401 은 기록된다', () async {
      final log = ApiFailureLog();
      final store = InMemoryTokenStore();
      await store.save(access: 'old', refresh: 'r');

      final auth = AuthInterceptor(
        store: store,
        refresh: (_) async => null, // 갱신 불가
        retry: (options) async =>
            Response<dynamic>(requestOptions: options, statusCode: 200, data: const {}),
      );

      final client = _clientWithRecorder(
        log,
        before: [auth],
        adapter: _FixedAdapter(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': '만료'},
        }),
      );

      await expectLater(
        client.get<Map<String, dynamic>>('/dashboard'),
        throwsA(isA<ApiException>()),
      );

      expect(log.length, 1);
      expect(log.recent.first.statusCode, 401);
    });

    test('기록 중 예외가 원래 에러 흐름을 바꾸지 않는다', () async {
      final client = _clientWithRecorder(
        _ThrowingLog(),
        adapter: _FixedAdapter(503, {
          'error': {'code': 'SANDBOX_UNAVAILABLE', 'message': '점검 중'},
        }),
      );

      // recorder 가 삼켜야 하므로, 던져지는 것은 여전히 ApiException 이다.
      await expectLater(
        client.get<Map<String, dynamic>>('/sandbox'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.sandboxUnavailable,
          ),
        ),
      );
    });

    test('★불변식★ 정규화 인터셉터가 체인의 마지막이다', () {
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://example.test', useMock: false),
        interceptors: [
          AuthInterceptor(
            store: InMemoryTokenStore(),
            refresh: (_) async => null,
            retry: (o) async => Response<dynamic>(requestOptions: o),
          ),
        ],
      );
      // ApiClient.create 가 마지막에 추가하는 정규화는 InterceptorsWrapper 다.
      // 이 단언이 깨지면 `insert(length - 1, recorder)` 배선이 조용히 틀려진다.
      expect(client.dio.interceptors.last, isA<InterceptorsWrapper>());
      expect(client.dio.interceptors.first, isA<AuthInterceptor>());
    });
  });
}

/// add 가 항상 던지는 로그 — recorder 가 예외를 삼키는지 검증한다.
class _ThrowingLog implements ApiFailureLog {
  @override
  int get capacity => 10;

  @override
  void add(ApiFailureEntry entry) => throw StateError('boom');

  @override
  void clear() {}

  @override
  int get length => 0;

  @override
  List<ApiFailureEntry> get recent => const [];
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/support/api_failure_recorder_test.dart`
Expected: FAIL — `Undefined name 'ApiFailureLog'` (컴파일 오류)

- [ ] **Step 3: 링버퍼 구현**

`packages/dp_core/lib/src/support/api_failure_log.dart`:

```dart
import 'dart:collection';

/// 제보에 첨부할 API 실패 1건. **기록 시점에 이미 마스킹된 값만** 담는다 —
/// 버퍼에 원문을 두지 않으면 이후 어떤 경로로도 원문이 새지 않는다.
class ApiFailureEntry {
  const ApiFailureEntry({
    required this.method,
    required this.path,
    required this.occurredAt,
    this.statusCode,
    this.errorCode,
    this.traceId,
    this.message,
  });

  final String method;

  /// 쿼리스트링이 제거된 경로.
  final String path;

  /// 네트워크 실패면 null — 이 구분 자체가 진단 정보다.
  final int? statusCode;
  final String? errorCode;
  final String? traceId;

  /// 마스킹 후 500자로 절단된 응답 message.
  final String? message;

  final DateTime occurredAt;

  /// 접수 요청의 `context.failures[]` 원소 형태(서버 SupportCreateRequest.Failure 와 대응).
  Map<String, dynamic> toJson() => {
    'method': method,
    'path': path,
    'statusCode': statusCode,
    'errorCode': errorCode,
    'traceId': traceId,
    'message': message,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };
}

/// 최근 실패 링버퍼. 메모리 전용 — 앱 재시작 시 소멸한다(영속화하지 않는다).
class ApiFailureLog {
  ApiFailureLog({this.capacity = 10});

  final int capacity;
  final ListQueue<ApiFailureEntry> _entries = ListQueue<ApiFailureEntry>();

  void add(ApiFailureEntry entry) {
    if (_entries.length >= capacity) {
      _entries.removeFirst();
    }
    _entries.addLast(entry);
  }

  /// **0 = 가장 최근.** 서버 `seq` 와 같은 순서다.
  List<ApiFailureEntry> get recent =>
      List<ApiFailureEntry>.unmodifiable(_entries.toList().reversed);

  int get length => _entries.length;

  void clear() => _entries.clear();
}
```

- [ ] **Step 4: 인터셉터 구현**

`packages/dp_core/lib/src/support/api_failure_recorder.dart`:

```dart
import 'package:dio/dio.dart';

import '../error/api_exception.dart';
import 'api_failure_log.dart';
import 'sensitive_text_masker.dart';

/// 최근 API 실패를 링버퍼에 기록하는 인터셉터.
///
/// **배선 위치가 정확도를 좌우한다: `Auth` 뒤 · `ErrorNormalizer` 앞.**
/// - index 0 이면 AuthInterceptor 가 refresh 로 복구하는 일시적 401까지 기록되어,
///   사용자가 겪지도 않은 실패가 제보에 섞인다.
/// - 정규화 뒤면 아무것도 못 본다 — 정규화가 `handler.reject()` 로 체인을 끝낸다.
///
/// **절대 예외를 던지지 않는다.** 진단 기능이 진단 대상을 망가뜨리면 안 된다.
class ApiFailureRecorder extends Interceptor {
  ApiFailureRecorder(this.log, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const int _messageMax = 500;

  final ApiFailureLog log;
  final DateTime Function() _clock;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    try {
      log.add(_toEntry(err));
    } catch (_) {
      // 기록 중 어떤 오류가 나도 삼키고 원래 에러를 그대로 통과시킨다.
    }
    handler.next(err);
  }

  ApiFailureEntry _toEntry(DioException err) {
    final req = err.requestOptions;
    final res = err.response;
    // 이 인터셉터는 정규화 **앞**이라 err.error 는 아직 ApiException 이 아니다.
    // message·traceId 는 직접 정규화해 얻는다.
    final normalized = ApiException.fromDio(err);
    // errorCode 는 enum 으로 좁히지 않고 응답 본문의 **원문 문자열**을 읽는다 —
    // 서버가 ApiErrorCode 에 없는 코드(예: INTERNAL_ERROR)도 보내기 때문이다.
    final body = res?.data;
    final errObj = (body is Map && body['error'] is Map)
        ? (body['error'] as Map)
        : const <dynamic, dynamic>{};

    return ApiFailureEntry(
      method: req.method,
      path: _stripQuery(req.path),
      statusCode: res?.statusCode,
      errorCode: errObj['code'] as String?,
      traceId: normalized.traceId,
      message: SensitiveTextMasker.maskAndTruncate(
        normalized.message,
        _messageMax,
      ),
      occurredAt: _clock(),
    );
  }

  static String _stripQuery(String path) {
    final i = path.indexOf('?');
    return i < 0 ? path : path.substring(0, i);
  }
}
```

- [ ] **Step 5: export 추가**

`packages/dp_core/lib/dp_core.dart`의 Task 6에서 추가한 줄 다음에:

```dart
export 'src/support/api_failure_log.dart';
export 'src/support/api_failure_recorder.dart';
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/support/`
Expected: PASS (20 tests — Task 6의 14 + 이번 6)

- [ ] **Step 7: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add packages/dp_core/lib/src/support packages/dp_core/lib/dp_core.dart packages/dp_core/test/support
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(dp_core): add API failure ring buffer and recorder interceptor"
```

---

## Task 8: dp_design 보조 액션

**Files:**
- Modify: `packages/dp_design/lib/src/states/dp_state_scaffold.dart`
- Modify: `packages/dp_design/lib/src/states/dp_error.dart`
- Test: `packages/dp_design/test/states/dp_error_test.dart`

**Interfaces:**
- Produces:
  - `DpStateScaffold(..., String? secondaryActionLabel, VoidCallback? onSecondaryAction)` — **둘 다 기본 null**
  - `DpError(..., VoidCallback? onReport)` — null이면 보조 버튼 미노출
  - Task 10의 web 화면들이 `DpError(onReport: ...)`를 쓴다.

**무회귀가 중요한 이유:** `DpError` 호출부는 **12개 파일**이다(실측: web 8 · admin 4). 새 파라미터가 전부 선택이고 기본 null이라 기존 호출부는 한 줄도 바뀌지 않는다. `DpEmpty` · `DpQuota` · `DpSandboxUnavailable` · `DpKillSwitch`도 `DpStateScaffold`를 쓰지만 마찬가지로 무변경이다.

- [ ] **Step 1: 실패하는 테스트 작성**

`packages/dp_design/test/states/dp_error_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  group('DpError 보조 액션', () {
    testWidgets('onReport 가 없으면 문의하기 버튼이 없다 — 기존 호출부 무회귀', (tester) async {
      await tester.pumpWidget(
        _wrap(DpError(message: '문제가 생겼어요', onRetry: () {})),
      );

      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.text('문의하기'), findsNothing);
    });

    testWidgets('onReport 가 있으면 문의하기 버튼이 보이고 눌린다', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          DpError(
            message: '문제가 생겼어요',
            onRetry: () {},
            onReport: () => tapped++,
          ),
        ),
      );

      expect(find.text('문의하기'), findsOneWidget);
      await tester.tap(find.text('문의하기'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('onRetry 없이 onReport 만 있어도 보조 버튼이 보인다', (tester) async {
      await tester.pumpWidget(
        _wrap(DpError(message: '문제가 생겼어요', onReport: () {})),
      );

      expect(find.text('다시 시도'), findsNothing);
      expect(find.text('문의하기'), findsOneWidget);
    });
  });

  group('DpStateScaffold 보조 액션', () {
    testWidgets('보조 파라미터가 없으면 1차 행동만 렌더한다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DpStateScaffold(
            icon: DpIcons.empty,
            title: '비었어요',
            actionLabel: '새로고침',
            onAction: () {},
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('보조 파라미터가 둘 다 있어야 렌더한다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DpStateScaffold(
            icon: DpIcons.error,
            title: '오류',
            secondaryActionLabel: '문의하기',
            onSecondaryAction: () {},
          ),
        ),
      );

      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text('문의하기'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_design && flutter test test/states/dp_error_test.dart`
Expected: FAIL — `No named parameter with the name 'onReport'` (컴파일 오류)

- [ ] **Step 3: DpStateScaffold 수정**

`packages/dp_design/lib/src/states/dp_state_scaffold.dart` — 주석 · 생성자 · 필드 · 빌드에 각각 추가한다.

주석(1행)을 교체:

```dart
/// 상태 화면 공통 레이아웃: 아이콘 + 제목 + (메시지) + (단일 1차 행동) + (선택 보조 행동).
///
/// 1차 행동은 여전히 **하나**다. 보조 행동은 1차와 경쟁하지 않도록 TextButton 으로,
/// 1차 아래에 둔다(예: 오류 화면의 [다시 시도] 밑 [문의하기]).
```

생성자에 두 줄 추가:

```dart
  const DpStateScaffold({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });
```

필드에 두 줄 추가(`final Color? iconColor;` 다음):

```dart
  /// 보조 행동 라벨. [onSecondaryAction] 과 **둘 다** 있어야 렌더된다.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
```

`build`의 1차 행동 블록 다음에 추가(`Column`의 children 마지막):

```dart
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DpSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              SizedBox(
                height: (actionLabel != null && onAction != null)
                    ? DpSpacing.xs
                    : DpSpacing.lg,
              ),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
```

- [ ] **Step 4: DpError 수정**

`packages/dp_design/lib/src/states/dp_error.dart` 전체를 다음으로 교체:

```dart
import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import 'dp_state_scaffold.dart';

/// 오류 상태. [onReport] 를 주면 [다시 시도] 아래에 [문의하기] 가 붙는다.
///
/// 이 한 파라미터로 DpError 를 쓰는 모든 화면이 제보 진입점을 얻는다
/// (기획 06_화면_기능_정의서:798 의 `[다시 시도] [문의하기]` 조합).
class DpError extends StatelessWidget {
  const DpError({
    super.key,
    required this.message,
    this.onRetry,
    this.onReport,
    this.title = '문제가 발생했어요',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  /// null 이면 보조 버튼이 렌더되지 않는다 — 기존 호출부는 무변경이다.
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) => DpStateScaffold(
    icon: DpIcons.error,
    iconColor: context.dpColors.danger,
    title: title,
    message: message,
    actionLabel: onRetry == null ? null : '다시 시도',
    onAction: onRetry,
    secondaryActionLabel: onReport == null ? null : '문의하기',
    onSecondaryAction: onReport,
  );
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_design && flutter test test/states/dp_error_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 6: dp_design 전체 회귀 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_design && flutter test --exclude-tags golden`
Expected: 전부 PASS (기존 상태 위젯 테스트 무회귀)

- [ ] **Step 7: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add packages/dp_design/lib/src/states packages/dp_design/test/states/dp_error_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(dp_design): add optional secondary action to state scaffold and DpError"
```

---

## Task 9: web 배선 (설정 · 수집기 · provider · 목 픽스처)

UI 없이 **데이터 경로만** 완성한다. 화면은 Task 10.

**Files:**
- Modify: `apps/web/lib/src/app/app_config.dart`
- Create: `apps/web/lib/src/features/support/data/support_draft.dart`
- Create: `apps/web/lib/src/features/support/data/support_context_collector.dart`
- Create: `apps/web/lib/src/features/support/data/support_context_collector_web.dart`
- Create: `apps/web/lib/src/features/support/data/support_context_collector_stub.dart`
- Create: `apps/web/lib/src/features/support/application/support_controller.dart`
- Modify: `apps/web/lib/src/providers/api_providers.dart`
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart`
- Test: `apps/web/test/features/support/support_controller_test.dart`

**Interfaces:**
- Consumes: `ApiFailureLog` · `ApiFailureRecorder` (Task 7), `SensitiveTextMasker` (Task 6)
- Produces:
  - `AppConfig.appVersion` (String, 기본 `'dev'`)
  - `SupportDraft({required String type, required String title, required String body})`
  - `SupportContext` — `toJson()`이 접수 요청의 `context` 객체를 만든다
  - `UserAgentReader` 인터페이스 + `createUserAgentReader()` 팩토리(조건부 임포트)
  - `apiFailureLogProvider` (Provider\<ApiFailureLog>)
  - `supportControllerProvider` (AsyncNotifierProvider) — `submit(SupportDraft, SupportContext) -> Future<int>` 접수 번호 반환
  - Task 10의 다이얼로그가 `supportControllerProvider`와 `SupportContext.toJson()` 미리보기를 쓴다.

- [ ] **Step 1: AppConfig에 APP_VERSION 추가**

`apps/web/lib/src/app/app_config.dart` — 생성자·팩토리·필드에 추가한다.

```dart
  const AppConfig({
    required this.baseUrl,
    required this.useMock,
    this.appVersion = 'dev',
    this.sseTimeout = const Duration(seconds: 60),
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://mock.devpath.ai',
    ),
    useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
    appVersion: String.fromEnvironment('APP_VERSION', defaultValue: 'dev'),
  );
```

필드 추가(`final bool useMock;` 다음):

```dart
  /// 빌드 식별자. `--dart-define=APP_VERSION=0.1.0+42` 로 주입한다.
  /// 미주입이면 'dev' — 제보에 "어느 빌드였는지"가 비지 않게 기본값을 둔다.
  final String appVersion;
```

클래스 주석의 dart-define 목록에도 한 줄 더한다:

```dart
/// - `APP_VERSION`: 빌드 식별자(기본 `dev`). 오류 제보에 함께 전송된다.
```

- [ ] **Step 2: 실패하는 테스트 작성**

`apps/web/test/features/support/support_controller_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/support/application/support_controller.dart';
import 'package:devpath_web/src/features/support/data/support_draft.dart';
import 'package:devpath_web/src/providers/api_providers.dart';

/// 요청 본문을 붙잡아 두는 어댑터.
class _CapturingAdapter implements HttpClientAdapter {
  Object? lastBody;
  String? lastPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastBody = options.data;
    return ResponseBody.fromString(
      jsonEncode({'id': 42}),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('접수 요청이 계약대로 조립된다 — 실패 목록·컨텍스트 포함', () async {
    final adapter = _CapturingAdapter();
    final log = ApiFailureLog();
    log.add(
      ApiFailureEntry(
        method: 'POST',
        path: '/learning-paths',
        statusCode: 500,
        errorCode: 'INTERNAL_ERROR',
        message: '일시적 오류',
        occurredAt: DateTime.utc(2026, 8, 3, 10, 11, 9),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(
          (ref) => const AppConfig(
            baseUrl: 'https://api.test',
            useMock: false,
            appVersion: '0.1.0+42',
          ),
        ),
        apiFailureLogProvider.overrideWithValue(log),
      ],
    );
    addTearDown(container.dispose);

    container.read(apiClientProvider).dio.httpClientAdapter = adapter;

    final id = await container
        .read(supportControllerProvider.notifier)
        .submit(
          const SupportDraft(type: 'ERROR', title: '제목', body: '본문'),
          SupportContext(
            pagePath: '/path',
            appVersion: '0.1.0+42',
            userAgent: 'UA',
            viewport: '1920x1080',
            errorCode: 'PATH_GENERATION_FAILED',
            occurredAt: DateTime.utc(2026, 8, 3, 10, 11, 12),
            failures: log.recent,
          ),
        );

    expect(id, 42);
    expect(adapter.lastPath, '/support/requests');

    final body = adapter.lastBody as Map<String, dynamic>;
    expect(body['type'], 'ERROR');
    expect(body['title'], '제목');
    final ctx = body['context'] as Map<String, dynamic>;
    expect(ctx['pagePath'], '/path');
    expect(ctx['appVersion'], '0.1.0+42');
    expect(ctx['occurredAt'], '2026-08-03T10:11:12.000Z');
    final failures = ctx['failures'] as List;
    expect(failures, hasLength(1));
    expect((failures.first as Map)['errorCode'], 'INTERNAL_ERROR');
  });

  test('제목·본문은 마스킹해서 보낸다', () {
    final ctx = SupportContext(
      pagePath: '/path?token=abc',
      appVersion: 'dev',
      userAgent: 'UA',
      viewport: '800x600',
      occurredAt: DateTime.utc(2026, 8, 3),
      failures: const [],
    );
    // pagePath 는 쿼리스트링이 제거된 상태로 나간다.
    expect(ctx.toJson()['pagePath'], '/path');
  });
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/support/support_controller_test.dart`
Expected: FAIL — `support_draft.dart` 미존재(컴파일 오류)

- [ ] **Step 4: 데이터 모델 구현**

`apps/web/lib/src/features/support/data/support_draft.dart`:

```dart
import 'package:dp_core/dp_core.dart';

/// 사용자가 입력한 부분. 수집 컨텍스트와 분리해 두면 다이얼로그가 입력만 다룬다.
class SupportDraft {
  const SupportDraft({
    required this.type,
    required this.title,
    required this.body,
  });

  /// ERROR | INQUIRY
  final String type;
  final String title;
  final String body;
}

/// 자동 수집되는 부분. `toJson()` 이 접수 요청의 `context` 객체가 된다.
class SupportContext {
  const SupportContext({
    required this.pagePath,
    required this.appVersion,
    required this.userAgent,
    required this.viewport,
    required this.occurredAt,
    required this.failures,
    this.traceId,
    this.errorCode,
  });

  final String pagePath;
  final String appVersion;
  final String userAgent;
  final String viewport;
  final DateTime occurredAt;

  /// 링버퍼의 최근 실패(0 = 가장 최근). 이미 마스킹된 값이다.
  final List<ApiFailureEntry> failures;

  /// 오류 화면에서 진입한 경우에만 채워진다.
  /// 서버는 현재 trace_id 를 항상 null 로 보낸다(분산 트레이싱 미도입) — 배관만 있다.
  final String? traceId;
  final String? errorCode;

  Map<String, dynamic> toJson() => {
    'pagePath': _stripQuery(pagePath),
    'appVersion': appVersion,
    'userAgent': userAgent,
    'viewport': viewport,
    'traceId': traceId,
    'errorCode': errorCode,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'failures': [for (final f in failures) f.toJson()],
  };

  static String _stripQuery(String path) {
    final i = path.indexOf('?');
    return i < 0 ? path : path.substring(0, i);
  }
}
```

- [ ] **Step 5: 수집기 구현 (조건부 임포트)**

`apps/web/lib/src/features/support/data/support_context_collector.dart`:

```dart
import 'support_context_collector_web.dart'
    if (dart.library.io) 'support_context_collector_stub.dart';

/// userAgent 만 브라우저 API 가 필요하다 — dp_core(순수 Dart)에 둘 수 없어 web 앱이 소유한다.
/// pagePath·viewport 는 Flutter 위젯 트리에서 얻으므로 여기 없다(다이얼로그 호출부에서 채운다).
abstract interface class UserAgentReader {
  String read();
}

/// 조건부 임포트 팩토리. VM/테스트는 스텁('unknown')을 돌려준다.
UserAgentReader userAgentReader() => createUserAgentReader();
```

`apps/web/lib/src/features/support/data/support_context_collector_web.dart`:

```dart
import 'package:web/web.dart' as web;

import 'support_context_collector.dart';

class _WebUserAgentReader implements UserAgentReader {
  const _WebUserAgentReader();

  @override
  String read() => web.window.navigator.userAgent;
}

/// 조건부 임포트에서 호출하는 팩토리 함수.
UserAgentReader createUserAgentReader() => const _WebUserAgentReader();
```

`apps/web/lib/src/features/support/data/support_context_collector_stub.dart`:

```dart
import 'support_context_collector.dart';

/// VM/테스트 스텁. 제보를 막지 않도록 던지지 않고 'unknown' 을 돌려준다 —
/// 진단 정보 하나가 없다고 제보 자체가 실패하면 안 된다.
class _StubUserAgentReader implements UserAgentReader {
  const _StubUserAgentReader();

  @override
  String read() => 'unknown';
}

/// 조건부 임포트에서 호출하는 팩토리 함수.
UserAgentReader createUserAgentReader() => const _StubUserAgentReader();
```

- [ ] **Step 6: 컨트롤러 구현**

`apps/web/lib/src/features/support/application/support_controller.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../data/support_draft.dart';

/// 접수 제출. 실패를 삼키지 않고 [ApiException] 을 그대로 올린다 —
/// 다이얼로그가 사용자가 쓴 내용을 유지한 채 에러를 보여주고 재시도할 수 있어야 한다.
class SupportController extends Notifier<AsyncValue<int?>> {
  @override
  AsyncValue<int?> build() => const AsyncValue.data(null);

  /// 성공 시 접수 번호를 돌려준다.
  Future<int> submit(SupportDraft draft, SupportContext context) async {
    state = const AsyncValue.loading();
    try {
      final json = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        '/support/requests',
        body: {
          'type': draft.type,
          // 서버도 마스킹하지만 클라에서도 지운다 — 원문이 네트워크와 접근 로그를 지나지 않는다.
          'title': SensitiveTextMasker.mask(draft.title),
          'body': SensitiveTextMasker.mask(draft.body),
          'context': context.toJson(),
        },
      );
      final id = (json['id'] as num).toInt();
      state = AsyncValue.data(id);
      return id;
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final supportControllerProvider =
    NotifierProvider<SupportController, AsyncValue<int?>>(
      SupportController.new,
    );
```

- [ ] **Step 7: provider 배선**

`apps/web/lib/src/providers/api_providers.dart` — import에 아무것도 더할 필요 없다(`dp_core`가 이미 export한다).

`tokenStoreProvider` 아래에 추가:

```dart
/// 최근 API 실패 링버퍼. 제보 다이얼로그가 읽고, 인터셉터가 쓴다.
/// 메모리 전용이라 새로고침하면 비어 있다.
final apiFailureLogProvider = Provider<ApiFailureLog>((ref) => ApiFailureLog());
```

`apiClientProvider` 안에서 **OnboardingGate를 index 0에 넣은 다음**(=배선의 마지막 단계) recorder를 삽입한다. `if (config.useMock)` 블록 바로 위에:

```dart
  // 제보용 실패 기록 — **Auth 뒤 · ErrorNormalizer 앞**.
  // index 0 이면 Auth 가 refresh 로 복구하는 일시적 401까지 기록되어, 사용자가 겪지도
  // 않은 실패가 제보에 섞인다. 정규화 뒤면 handler.reject() 로 체인이 끝나 아무것도 못 본다.
  // dp_core 의 api_failure_recorder_test 가 "정규화가 마지막"이라는 이 불변식을 지킨다.
  client.dio.interceptors.insert(
    client.dio.interceptors.length - 1,
    ApiFailureRecorder(ref.watch(apiFailureLogProvider)),
  );
```

- [ ] **Step 8: 목 픽스처 추가**

`apps/web/lib/src/data/web_mock_fixtures.dart`의 맵에 추가한다(`'POST /auth/refresh'` 항목 다음이 읽기 좋다):

```dart
  // ④ 오류 신고·문의 접수. 목 모드 기본값이 true 라 이 픽스처가 없으면 제보가 404로 실패한다.
  'POST /support/requests': (201, {'id': 42}),
```

- [ ] **Step 9: 테스트 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/support/support_controller_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 10: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web/lib/src/app/app_config.dart apps/web/lib/src/features/support apps/web/lib/src/providers/api_providers.dart apps/web/lib/src/data/web_mock_fixtures.dart apps/web/test/features/support
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): wire support request data path and failure recorder"
```

---

## Task 10: web 제보 다이얼로그

화면 없이 다이얼로그만 만든다 — 진입점 배선은 Task 11.

**Files:**
- Create: `apps/web/lib/src/features/support/presentation/support_dialog.dart`
- Test: `apps/web/test/features/support/support_dialog_test.dart`

**Interfaces:**
- Consumes: `supportControllerProvider` · `SupportDraft` · `SupportContext` (Task 9), `apiFailureLogProvider` (Task 9), `userAgentReader()` (Task 9)
- Produces: `Future<int?> showSupportDialog(BuildContext context, {String? traceId, String? errorCode})` — 접수 성공 시 접수 번호, 취소면 null. Task 11의 두 진입점이 이 함수만 호출한다.

**설계 제약(스펙 §7.3):**
- **조용한 비활성 버튼을 만들지 않는다**(2026-07-27 동의화면 사고). 제목·내용이 비어도 버튼은 살아 있고, 누르면 검증 메시지를 띄운다.
- "함께 보낼 정보"는 선택이 아니라 **고지**다. 접이식으로 열어 볼 수 있어야 하고, **마스킹된 값 그대로** 보여준다.
- **접수 실패를 삼키지 않는다.** 다이얼로그 안에서 에러를 보이고 **입력을 유지한 채** 재시도할 수 있어야 한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`apps/web/test/features/support/support_dialog_test.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:devpath_web/src/features/support/application/support_controller.dart';
import 'package:devpath_web/src/features/support/data/support_draft.dart';
import 'package:devpath_web/src/features/support/presentation/support_dialog.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 제출 결과를 조종할 수 있는 가짜 컨트롤러.
class _FakeSupportController extends SupportController {
  _FakeSupportController(this.result);

  /// 성공이면 id, 실패면 던질 예외.
  final Object result;
  SupportDraft? lastDraft;
  SupportContext? lastContext;
  int calls = 0;

  @override
  Future<int> submit(SupportDraft draft, SupportContext context) async {
    calls++;
    lastDraft = draft;
    lastContext = context;
    if (result is int) return result as int;
    throw result;
  }
}

Future<void> _pumpHost(
  WidgetTester tester,
  _FakeSupportController fake, {
  ApiFailureLog? log,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supportControllerProvider.overrideWith(() => fake),
        if (log != null) apiFailureLogProvider.overrideWithValue(log),
      ],
      child: MaterialApp(
        theme: DpTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSupportDialog(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('빈 입력으로 제출하면 검증 메시지 — 버튼을 죽이지 않는다', (tester) async {
    final fake = _FakeSupportController(1);
    await _pumpHost(tester, fake);

    final submit = find.byKey(const ValueKey('support-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('제목과 내용을 모두 입력해 주세요'), findsOneWidget);
    expect(fake.calls, 0);
  });

  testWidgets('유형을 전환할 수 있고 기본은 오류다', (tester) async {
    final fake = _FakeSupportController(7);
    await _pumpHost(tester, fake);

    await tester.enterText(find.byKey(const ValueKey('support-title')), '제목');
    await tester.enterText(find.byKey(const ValueKey('support-body')), '내용');
    await tester.tap(find.text('문의'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle();

    expect(fake.lastDraft?.type, 'INQUIRY');
  });

  testWidgets('함께 보낼 정보를 펼치면 마스킹된 실패가 보인다', (tester) async {
    final log = ApiFailureLog();
    log.add(
      ApiFailureEntry(
        method: 'POST',
        path: '/learning-paths',
        statusCode: 500,
        errorCode: 'INTERNAL_ERROR',
        message: '문의: [EMAIL]',
        occurredAt: DateTime.utc(2026, 8, 3, 10),
      ),
    );
    final fake = _FakeSupportController(1);
    await _pumpHost(tester, fake, log: log);

    expect(find.text('POST /learning-paths'), findsNothing);

    await tester.tap(find.text('함께 보낼 정보'));
    await tester.pumpAndSettle();

    expect(find.text('POST /learning-paths'), findsOneWidget);
    expect(find.textContaining('[EMAIL]'), findsOneWidget);
  });

  testWidgets('접수 실패 시 입력이 보존되고 에러가 보인다', (tester) async {
    final fake = _FakeSupportController(
      const ApiException(code: ApiErrorCode.network, message: '네트워크 연결을 확인해 주세요.'),
    );
    await _pumpHost(tester, fake);

    await tester.enterText(find.byKey(const ValueKey('support-title')), '유지될 제목');
    await tester.enterText(find.byKey(const ValueKey('support-body')), '유지될 내용');
    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle();

    // 다이얼로그가 닫히지 않는다.
    expect(find.byKey(const ValueKey('support-submit')), findsOneWidget);
    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
    // 사용자가 쓴 글을 날리지 않는다 — 제보 실패로 글을 잃으면 두 번째 사고다.
    expect(find.text('유지될 제목'), findsOneWidget);
    expect(find.text('유지될 내용'), findsOneWidget);
  });

  testWidgets('성공하면 접수 번호를 돌려주고 닫힌다', (tester) async {
    final fake = _FakeSupportController(42);
    await _pumpHost(tester, fake);

    await tester.enterText(find.byKey(const ValueKey('support-title')), '제목');
    await tester.enterText(find.byKey(const ValueKey('support-body')), '내용');
    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-submit')), findsNothing);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/support/support_dialog_test.dart`
Expected: FAIL — `support_dialog.dart` 미존재(컴파일 오류)

- [ ] **Step 3: 다이얼로그 구현**

`apps/web/lib/src/features/support/presentation/support_dialog.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/api_providers.dart';
import '../application/support_controller.dart';
import '../data/support_context_collector.dart';
import '../data/support_draft.dart';

/// 제보 다이얼로그를 띄우고 접수 번호를 돌려준다(취소면 null).
///
/// 두 진입점(앱셸 상시 버튼 · 오류 화면의 [문의하기])이 이 함수만 호출한다.
Future<int?> showSupportDialog(
  BuildContext context, {
  String? traceId,
  String? errorCode,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => SupportDialog(traceId: traceId, errorCode: errorCode),
  );
}

class SupportDialog extends ConsumerStatefulWidget {
  const SupportDialog({super.key, this.traceId, this.errorCode});

  final String? traceId;
  final String? errorCode;

  @override
  ConsumerState<SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends ConsumerState<SupportDialog> {
  static const _titleMax = 200;
  static const _bodyMax = 5000;

  /// 오류 화면에서 열렸으면 오류가 기본이다.
  late String _type = 'ERROR';

  // FocusNode·Controller 는 State 가 소유한다 — 매 빌드 교체하면 IME 조합이 끊긴다
  // (2026-08-01 서식 에디터에서 겪은 문제).
  final _title = TextEditingController();
  final _body = TextEditingController();

  String? _validationMessage;
  String? _submitError;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final failures = ref.watch(apiFailureLogProvider).recent;

    return AlertDialog(
      title: const Text('오류 신고·문의'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ERROR', label: Text('오류')),
                  ButtonSegment(value: 'INQUIRY', label: Text('문의')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: DpSpacing.md),
              TextField(
                key: const ValueKey('support-title'),
                controller: _title,
                maxLength: _titleMax,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: DpSpacing.sm),
              TextField(
                key: const ValueKey('support-body'),
                controller: _body,
                maxLength: _bodyMax,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '내용',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: DpSpacing.sm),
              // 선택이 아니라 고지다 — 무엇이 전송되는지 열어 볼 수 있어야 한다.
              // 마스킹된 값을 그대로 보여주므로 "여기 이메일이 남아 있다"를 발견할 수 있다.
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('함께 보낼 정보'),
                  subtitle: Text(
                    '최근 실패 ${failures.length}건 · 화면 경로 · 브라우저 정보',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  children: [
                    for (final f in failures)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${f.method} ${f.path}'),
                        subtitle: Text(
                          '${f.statusCode ?? '네트워크 실패'}'
                          '${f.errorCode == null ? '' : ' · ${f.errorCode}'}'
                          '${f.message == null ? '' : '\n${f.message}'}',
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ),
                    if (failures.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: DpSpacing.xs),
                        child: Text(
                          '기록된 API 실패가 없습니다.',
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: DpSpacing.xs),
                Text(
                  _validationMessage!,
                  style: TextStyle(color: c.danger, fontSize: 12),
                ),
              ],
              if (_submitError != null) ...[
                const SizedBox(height: DpSpacing.xs),
                Text(_submitError!, style: TextStyle(color: c.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('support-submit'),
          // 입력이 비어도 **버튼을 죽이지 않는다** — 눌러도 아무 일 없는 버튼을 두지 않는다.
          onPressed: _submitting ? null : _submit,
          child: const Text('보내기'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() {
        _validationMessage = '제목과 내용을 모두 입력해 주세요';
        _submitError = null;
      });
      return;
    }

    setState(() {
      _validationMessage = null;
      _submitError = null;
      _submitting = true;
    });

    final media = MediaQuery.sizeOf(context);
    final ctx = SupportContext(
      // .path 를 쓰므로 쿼리스트링이 구조적으로 빠진다.
      pagePath: GoRouterState.of(context).uri.path,
      appVersion: ref.read(appConfigProvider).appVersion,
      userAgent: userAgentReader().read(),
      viewport: '${media.width.round()}x${media.height.round()}',
      traceId: widget.traceId,
      errorCode: widget.errorCode,
      occurredAt: DateTime.now(),
      failures: ref.read(apiFailureLogProvider).recent,
    );

    try {
      final id = await ref
          .read(supportControllerProvider.notifier)
          .submit(SupportDraft(type: _type, title: title, body: body), ctx);
      if (mounted) Navigator.of(context).pop(id);
    } on ApiException catch (e) {
      // 입력을 유지한 채 에러만 보여준다.
      if (mounted) {
        setState(() {
          _submitError = e.message;
          _submitting = false;
        });
      }
    }
  }
}
```

> **테스트 호스트 주의**: `GoRouterState.of(context)`는 go_router 트리 밖에서 던진다. Step 1의 테스트 호스트는 `MaterialApp`만 쓰므로, 구현 시 `pagePath`를 안전하게 얻도록 감싼다:
>
> ```dart
>   String _pagePath(BuildContext context) {
>     try {
>       return GoRouterState.of(context).uri.path;
>     } catch (_) {
>       return '/'; // 라우터 밖(테스트 호스트) — 제보를 막지 않는다.
>     }
>   }
> ```
>
> `pagePath: _pagePath(context)`로 호출한다. 진단 정보 하나 때문에 제보가 실패하면 안 된다는 §5.2 원칙과 같은 판단이다.

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/support/support_dialog_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web/lib/src/features/support/presentation apps/web/test/features/support/support_dialog_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): add support request dialog"
```

---

## Task 11: web 진입점 배선 (앱셸 버튼 + 오류 화면)

**Files:**
- Create: `apps/web/lib/src/features/support/presentation/supportable_error.dart`
- Modify: `apps/web/lib/src/features/shell/presentation/app_shell.dart:70-77`
- Modify (8개, `DpError(` → `SupportableError(` 기계적 교체):
  - `apps/web/lib/src/features/community/presentation/community_home_page.dart`
  - `apps/web/lib/src/features/community/presentation/post_detail_page.dart`
  - `apps/web/lib/src/features/community/presentation/qna_detail_page.dart`
  - `apps/web/lib/src/features/content/presentation/content_page.dart`
  - `apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart`
  - `apps/web/lib/src/features/mypage/presentation/mypage_page.dart`
  - `apps/web/lib/src/features/path/presentation/path_page.dart`
  - `apps/web/lib/src/features/review/presentation/review_panel.dart`
- Test: `apps/web/test/features/support/support_entrypoints_test.dart`

**Interfaces:**
- Consumes: `showSupportDialog` (Task 10), `DpError.onReport` (Task 8)
- Produces: `SupportableError({required String message, VoidCallback? onRetry, String? title, String? traceId, String? errorCode})`

**왜 래퍼를 만드나:** 8개 호출부에 `onReport: () => showSupportDialog(context)`를 각각 손으로 넣으면 화면마다 문구·traceId 전달이 갈라진다. 위젯 이름만 바꾸는 기계적 교체가 회귀 위험이 낮고 리뷰도 쉽다. **admin 앱은 교체 대상이 아니다** — 관리자는 제보자가 아니라 처리자다.

- [ ] **Step 1: 실패하는 테스트 작성**

`apps/web/test/features/support/support_entrypoints_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:devpath_web/src/features/support/presentation/supportable_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SupportableError 는 문의하기 버튼을 항상 노출한다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SupportableError(message: '문제가 생겼어요'),
          ),
        ),
      ),
    );

    expect(find.text('문의하기'), findsOneWidget);
  });

  testWidgets('앱셸 trailing 에 명령 팔레트와 제보 버튼이 함께 있다', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AppShellView(
            location: '/dashboard',
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 기존 명령 팔레트 버튼이 살아 있다(회귀 방지).
    expect(find.byTooltip('명령 팔레트 (Ctrl/Cmd+K)'), findsOneWidget);
    // 새 제보 버튼이 추가됐다.
    expect(find.byTooltip('오류 신고·문의'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/support/support_entrypoints_test.dart`
Expected: FAIL — `supportable_error.dart` 미존재 + `byTooltip('오류 신고·문의')` findsNothing

- [ ] **Step 3: 래퍼 위젯 구현**

`apps/web/lib/src/features/support/presentation/supportable_error.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import 'support_dialog.dart';

/// [DpError] + 제보 진입점.
///
/// web 의 오류 화면은 전부 이 위젯을 쓴다 — 화면마다 onReport 를 손으로 넘기면
/// 문구·traceId 전달이 갈라진다. admin 은 쓰지 않는다(관리자는 처리자다).
class SupportableError extends StatelessWidget {
  const SupportableError({
    super.key,
    required this.message,
    this.onRetry,
    this.title = '문제가 발생했어요',
    this.traceId,
    this.errorCode,
  });

  final String message;
  final VoidCallback? onRetry;
  final String title;

  /// 서버는 현재 trace_id 를 항상 null 로 보낸다(분산 트레이싱 미도입) — 배관만 있다.
  final String? traceId;
  final String? errorCode;

  @override
  Widget build(BuildContext context) => DpError(
    title: title,
    message: message,
    onRetry: onRetry,
    onReport: () =>
        showSupportDialog(context, traceId: traceId, errorCode: errorCode),
  );
}
```

- [ ] **Step 4: 앱셸 trailing 수정**

`apps/web/lib/src/features/shell/presentation/app_shell.dart` — `trailing:` 슬롯을 `Row`로 바꾼다. `DpAppShell.trailing`은 단일 위젯이고 **`DpAppShell` 자체는 손대지 않는다.**

상단 import에 추가:

```dart
import '../../support/presentation/support_dialog.dart';
```

`trailing:` 블록 교체:

```dart
      trailing: Builder(
        builder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(DpIcons.error),
              tooltip: '오류 신고·문의',
              onPressed: () => showSupportDialog(context),
            ),
            IconButton(
              icon: const Icon(DpIcons.search),
              tooltip: '명령 팔레트 (Ctrl/Cmd+K)',
              onPressed: () =>
                  Actions.invoke(context, const OpenCommandPaletteIntent()),
            ),
          ],
        ),
      ),
```

- [ ] **Step 5: 8개 오류 화면 교체**

각 파일에서 `DpError(` → `SupportableError(`로 바꾸고, import를 `package:dp_design/dp_design.dart` 유지한 채 다음 한 줄을 추가한다(상대 깊이는 파일마다 다르다 — `features/<name>/presentation/`에서는 `../../support/presentation/supportable_error.dart`):

```dart
import '../../support/presentation/supportable_error.dart';
```

교체 후 각 파일에서 `DpError`가 더 이상 참조되지 않는지 확인한다:

```bash
cd D:/workspace/dpa/devpath-frontend
grep -rn "DpError" apps/web/lib
```

Expected: 출력 없음(모두 `SupportableError`로 교체됨). `apps/admin/lib`의 `DpError`는 **그대로 둔다.**

- [ ] **Step 6: 테스트 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/support/`
Expected: PASS (Task 9의 2 + Task 10의 5 + 이번 2 = 9 tests)

- [ ] **Step 7: web 전체 회귀 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test --exclude-tags golden`
Expected: 전부 PASS. 8개 화면의 기존 테스트가 `DpError`를 `find.byType`으로 찾고 있으면 여기서 깨진다 — 그 테스트들의 타입만 `SupportableError`로 바꾼다(동작 단언은 그대로).

- [ ] **Step 8: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web/lib apps/web/test
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): add support entry points to app shell and error screens"
```

---

## Task 12: admin 제보 처리 화면

**Files:**
- Create: `apps/admin/lib/src/features/support/data/support_request.dart`
- Create: `apps/admin/lib/src/features/support/state/support_state.dart`
- Create: `apps/admin/lib/src/features/support/application/support_controller.dart`
- Create: `apps/admin/lib/src/features/support/presentation/support_page.dart`
- Modify: `apps/admin/lib/src/app/router.dart`
- Modify: `apps/admin/lib/src/features/shell/presentation/admin_shell.dart`
- Test: `apps/admin/test/features/support/support_request_test.dart`

**Interfaces:**
- Consumes: Task 4의 3개 엔드포인트
- Produces: `/support` 라우트 + 셸 목적지. `SupportRequestRow.fromJson` · `SupportRequestDetail.fromJson`

**낱말 규칙(스펙 §7.4 — ③에서 "처리완료"가 필터와 버튼에 겹쳐 두 뜻으로 쓰인 문제를 미리 피한다):**

| 위치 | 표현 |
|---|---|
| 상태 필터(명사) | 접수됨 · 처리중 · 처리됨 · 보류 |
| 전이 버튼(동사) | 처리 시작 · 처리 완료 · 보류로 표시 · 다시 열기 |

- [ ] **Step 1: 실패하는 테스트 작성**

`apps/admin/test/features/support/support_request_test.dart`:

```dart
import 'package:devpath_admin/src/features/support/data/support_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportRequestRow', () {
    test('목록 행을 파싱한다', () {
      final row = SupportRequestRow.fromJson(const {
        'id': 42,
        'type': 'ERROR',
        'title': '경로 화면이 멈춰요',
        'status': 'OPEN',
        'pagePath': '/path',
        'reporterId': 7,
        'failureCount': 3,
        'createdAt': '2026-08-03T10:11:12Z',
      });

      expect(row.id, 42);
      expect(row.failureCount, 3);
      expect(row.typeLabel, '오류');
      expect(row.statusLabel, '접수됨'); // 필터·표기는 명사
    });

    test('상태 라벨 4종이 명사다', () {
      String label(String s) => SupportRequestRow.fromJson({
        'id': 1,
        'type': 'INQUIRY',
        'title': 't',
        'status': s,
        'failureCount': 0,
      }).statusLabel;

      expect(label('OPEN'), '접수됨');
      expect(label('IN_PROGRESS'), '처리중');
      expect(label('RESOLVED'), '처리됨');
      expect(label('WONTFIX'), '보류');
    });
  });

  group('SupportRequestDetail', () {
    test('실패 목록을 seq 순으로 담는다', () {
      final d = SupportRequestDetail.fromJson(const {
        'id': 42,
        'type': 'ERROR',
        'title': '제목',
        'body': '본문',
        'status': 'OPEN',
        'pagePath': '/path',
        'appVersion': '0.1.0+42',
        'userAgent': 'UA',
        'viewport': '1920x1080',
        'occurredAt': '2026-08-03T10:11:12Z',
        'reporterId': 7,
        'createdAt': '2026-08-03T10:11:12Z',
        'failures': [
          {
            'seq': 0,
            'method': 'POST',
            'path': '/learning-paths',
            'statusCode': 500,
            'errorCode': 'INTERNAL_ERROR',
            'message': '문의: [EMAIL]',
            'occurredAt': '2026-08-03T10:11:09Z',
          },
          {
            'seq': 1,
            'method': 'GET',
            'path': '/dashboard',
            'statusCode': null,
            'occurredAt': '2026-08-03T10:11:00Z',
          },
        ],
      });

      expect(d.failures, hasLength(2));
      expect(d.failures.first.seq, 0);
      // 네트워크 실패는 statusCode 가 null 이고, 그 구분 자체가 진단 정보다.
      expect(d.failures.last.statusCode, isNull);
      expect(d.failures.last.statusLabel, '네트워크 실패');
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/support/support_page_test.dart`
Expected: FAIL — `support_request.dart` 미존재(컴파일 오류)

- [ ] **Step 3: 모델 구현**

`apps/admin/lib/src/features/support/data/support_request.dart`:

```dart
/// 관리자 목록 행. 백엔드 `AdminSupportRow`(platform-svc)와 1:1 대응한다.
class SupportRequestRow {
  const SupportRequestRow({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.failureCount,
    this.pagePath,
    this.reporterId,
    this.createdAt,
  });

  final int id;

  /// ERROR | INQUIRY
  final String type;
  final String title;

  /// OPEN | IN_PROGRESS | RESOLVED | WONTFIX
  final String status;
  final int failureCount;
  final String? pagePath;
  final int? reporterId;
  final String? createdAt;

  String get typeLabel => type == 'INQUIRY' ? '문의' : '오류';

  /// **명사** — 상태 표기·필터용. 전이 버튼(동사)과 낱말이 겹치지 않게 한다.
  String get statusLabel => switch (status) {
    'IN_PROGRESS' => '처리중',
    'RESOLVED' => '처리됨',
    'WONTFIX' => '보류',
    _ => '접수됨',
  };

  factory SupportRequestRow.fromJson(Map<String, dynamic> json) =>
      SupportRequestRow(
        id: (json['id'] as num).toInt(),
        type: json['type'] as String,
        title: json['title'] as String,
        status: (json['status'] as String?) ?? 'OPEN',
        failureCount: (json['failureCount'] as num?)?.toInt() ?? 0,
        pagePath: json['pagePath'] as String?,
        reporterId: (json['reporterId'] as num?)?.toInt(),
        createdAt: json['createdAt'] as String?,
      );
}

/// 상세의 실패 1행.
class SupportFailure {
  const SupportFailure({
    required this.seq,
    required this.method,
    required this.path,
    required this.occurredAt,
    this.statusCode,
    this.errorCode,
    this.traceId,
    this.message,
  });

  final int seq;
  final String method;
  final String path;
  final String? occurredAt;
  final int? statusCode;
  final String? errorCode;
  final String? traceId;
  final String? message;

  /// null 은 상태코드가 없는 실패(타임아웃·연결 단절)다.
  String get statusLabel => statusCode == null ? '네트워크 실패' : '$statusCode';

  factory SupportFailure.fromJson(Map<String, dynamic> json) => SupportFailure(
    seq: (json['seq'] as num).toInt(),
    method: json['method'] as String,
    path: json['path'] as String,
    occurredAt: json['occurredAt'] as String?,
    statusCode: (json['statusCode'] as num?)?.toInt(),
    errorCode: json['errorCode'] as String?,
    traceId: json['traceId'] as String?,
    message: json['message'] as String?,
  );
}

/// 관리자 상세. 백엔드 `AdminSupportDetail` 과 1:1 대응한다.
class SupportRequestDetail {
  const SupportRequestDetail({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    required this.failures,
    this.pagePath,
    this.appVersion,
    this.userAgent,
    this.viewport,
    this.traceId,
    this.errorCode,
    this.occurredAt,
    this.reporterId,
    this.adminNote,
    this.handledBy,
    this.handledAt,
    this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final String status;
  final List<SupportFailure> failures;
  final String? pagePath;
  final String? appVersion;
  final String? userAgent;
  final String? viewport;
  final String? traceId;
  final String? errorCode;
  final String? occurredAt;
  final int? reporterId;
  final String? adminNote;
  final int? handledBy;
  final String? handledAt;
  final String? createdAt;

  factory SupportRequestDetail.fromJson(Map<String, dynamic> json) =>
      SupportRequestDetail(
        id: (json['id'] as num).toInt(),
        type: json['type'] as String,
        title: json['title'] as String,
        body: (json['body'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'OPEN',
        failures: [
          for (final o in (json['failures'] as List? ?? const []))
            SupportFailure.fromJson((o as Map).cast<String, dynamic>()),
        ],
        pagePath: json['pagePath'] as String?,
        appVersion: json['appVersion'] as String?,
        userAgent: json['userAgent'] as String?,
        viewport: json['viewport'] as String?,
        traceId: json['traceId'] as String?,
        errorCode: json['errorCode'] as String?,
        occurredAt: json['occurredAt'] as String?,
        reporterId: (json['reporterId'] as num?)?.toInt(),
        adminNote: json['adminNote'] as String?,
        handledBy: (json['handledBy'] as num?)?.toInt(),
        handledAt: json['handledAt'] as String?,
        createdAt: json['createdAt'] as String?,
      );
}
```

- [ ] **Step 4: 상태 구현**

`apps/admin/lib/src/features/support/state/support_state.dart`:

```dart
import '../data/support_request.dart';

sealed class SupportListState {
  const SupportListState();
}

class SupportListLoading extends SupportListState {
  const SupportListLoading();
}

class SupportListLoaded extends SupportListState {
  const SupportListLoaded(this.rows, {this.status = 'OPEN', this.type});

  final List<SupportRequestRow> rows;

  /// 현재 필터. null 이면 전체. 재조회 시 유지한다.
  final String? status;
  final String? type;
}

class SupportListFailed extends SupportListState {
  const SupportListFailed(this.message);
  final String message;
}
```

- [ ] **Step 5: 컨트롤러 구현**

`apps/admin/lib/src/features/support/application/support_controller.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../data/support_request.dart';
import '../state/support_state.dart';

/// 제보 처리.
///
/// 경로가 `/admin/support-requests` 인 것이 ③(신고)과 다르다 — ④는 소유가 platform-svc 라
/// 게이트웨이의 `/admin/**` 선점이 오히려 유리하게 작용해 우회 경로가 필요 없다.
class SupportListController extends Notifier<SupportListState> {
  static const _pageSize = 50;

  @override
  SupportListState build() {
    load();
    return const SupportListLoading();
  }

  Future<void> load({String? status = 'OPEN', String? type}) async {
    state = const SupportListLoading();
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/admin/support-requests',
            query: {'status': ?status, 'type': ?type, 'limit': _pageSize},
          );
      final rows = (json['data'] as List? ?? const [])
          .map(
            (o) =>
                SupportRequestRow.fromJson((o as Map).cast<String, dynamic>()),
          )
          .toList();
      state = SupportListLoaded(rows, status: status, type: type);
    } on ApiException catch (e) {
      state = SupportListFailed(e.message);
    }
  }

  Future<SupportRequestDetail> detail(int id) async {
    final json = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/admin/support-requests/$id');
    return SupportRequestDetail.fromJson(json);
  }

  /// 상태 전이 후 현재 필터로 재조회한다.
  Future<void> updateStatus(int id, String status, {String? adminNote}) async {
    final current = state;
    final keepStatus = current is SupportListLoaded ? current.status : 'OPEN';
    final keepType = current is SupportListLoaded ? current.type : null;
    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/admin/support-requests/$id/status',
            body: {'status': status, 'adminNote': ?adminNote},
          );
    } on ApiException catch (e) {
      state = SupportListFailed(e.message);
      return;
    }
    await load(status: keepStatus, type: keepType);
  }
}

final supportListProvider =
    NotifierProvider<SupportListController, SupportListState>(
      SupportListController.new,
    );
```

- [ ] **Step 6: 화면 구현**

`apps/admin/lib/src/features/support/presentation/support_page.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/support_controller.dart';
import '../data/support_request.dart';
import '../state/support_state.dart';

/// 오류 신고·문의 처리 화면.
class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  /// (라벨, status). null 은 전체. **명사**다 — 전이 버튼(동사)과 겹치지 않게 한다.
  static const _statusFilters = <(String, String?)>[
    ('접수됨', 'OPEN'),
    ('처리중', 'IN_PROGRESS'),
    ('처리됨', 'RESOLVED'),
    ('보류', 'WONTFIX'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(supportListProvider);
    final n = ref.read(supportListProvider.notifier);
    final current = s is SupportListLoaded ? s.status : 'OPEN';

    return Scaffold(
      appBar: AppBar(title: const Text('오류 신고·문의')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DpSpacing.lg,
              DpSpacing.md,
              DpSpacing.lg,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String?>(
                segments: [
                  for (final (label, value) in _statusFilters)
                    ButtonSegment(value: value, label: Text(label)),
                ],
                selected: {current},
                showSelectedIcon: false,
                onSelectionChanged: (sel) => n.load(status: sel.first),
              ),
            ),
          ),
          Expanded(
            child: switch (s) {
              SupportListLoading() => const DpLoading(),
              SupportListFailed(:final message) => DpError(
                message: message,
                onRetry: () => n.load(status: current),
              ),
              SupportListLoaded(:final rows) when rows.isEmpty =>
                const DpEmpty(icon: DpIcons.empty, title: '해당하는 제보가 없어요'),
              SupportListLoaded(:final rows) => Padding(
                padding: const EdgeInsets.all(DpSpacing.lg),
                child: DpDataTable(
                  minWidth: 900,
                  // dp_design 은 data_table_2 에서 DataColumn2·DataRow2 만 re-export 한다.
                  // ColumnSize 는 export 되지 않으므로 쓰지 않는다(users_page 와 동일).
                  columns: [
                    DataColumn2(label: const Text('번호'), fixedWidth: 72),
                    DataColumn2(label: const Text('유형'), fixedWidth: 72),
                    DataColumn2(label: const Text('제목')),
                    DataColumn2(label: const Text('경로')),
                    DataColumn2(label: const Text('실패'), fixedWidth: 64),
                    DataColumn2(label: const Text('상태'), fixedWidth: 88),
                    DataColumn2(label: const Text('접수 시각')),
                  ],
                  rows: [
                    for (final r in rows)
                      DataRow2(
                        onTap: () => _openDetail(context, ref, r.id),
                        cells: [
                          DataCell(Text('${r.id}')),
                          DataCell(Text(r.typeLabel)),
                          DataCell(Text(r.title, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(r.pagePath ?? '-')),
                          DataCell(Text('${r.failureCount}')),
                          DataCell(Text(r.statusLabel)),
                          DataCell(Text(r.createdAt ?? '-')),
                        ],
                      ),
                  ],
                ),
              ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, WidgetRef ref, int id) async {
    final n = ref.read(supportListProvider.notifier);
    final detail = await n.detail(id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _SupportDetailDialog(detail: detail),
    );
  }
}

class _SupportDetailDialog extends ConsumerStatefulWidget {
  const _SupportDetailDialog({required this.detail});
  final SupportRequestDetail detail;

  @override
  ConsumerState<_SupportDetailDialog> createState() =>
      _SupportDetailDialogState();
}

class _SupportDetailDialogState extends ConsumerState<_SupportDetailDialog> {
  late final TextEditingController _note = TextEditingController(
    text: widget.detail.adminNote ?? '',
  );

  /// **동사** — 상태 필터(명사)와 낱말이 겹치지 않게 한다.
  static const _transitions = <(String, String)>[
    ('처리 시작', 'IN_PROGRESS'),
    ('처리 완료', 'RESOLVED'),
    ('보류로 표시', 'WONTFIX'),
    ('다시 열기', 'OPEN'),
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final c = context.dpColors;

    return AlertDialog(
      title: Text('#${d.id} ${d.title}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.body),
              const SizedBox(height: DpSpacing.md),
              _kv(context, '경로', d.pagePath),
              _kv(context, '빌드', d.appVersion),
              _kv(context, '화면', d.viewport),
              _kv(context, '브라우저', d.userAgent),
              _kv(context, '오류 코드', d.errorCode),
              _kv(context, 'trace', d.traceId),
              _kv(context, '발생 시각', d.occurredAt),
              _kv(context, '접수자', d.reporterId?.toString()),
              const SizedBox(height: DpSpacing.md),
              Text('최근 API 실패', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: DpSpacing.xs),
              if (d.failures.isEmpty)
                Text(
                  '기록 없음',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              for (final f in d.failures)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text('${f.seq}'),
                  title: Text('${f.method} ${f.path}'),
                  subtitle: Text(
                    '${f.statusLabel}'
                    '${f.errorCode == null ? '' : ' · ${f.errorCode}'}'
                    '${f.message == null ? '' : '\n${f.message}'}',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  trailing: Text(
                    f.occurredAt ?? '-',
                    style: TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                ),
              const SizedBox(height: DpSpacing.md),
              TextField(
                key: const ValueKey('support-admin-note'),
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '내부 메모 (덮어쓰기)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        for (final (label, status) in _transitions)
          if (status != d.status)
            FilledButton.tonal(
              onPressed: () => _transition(status),
              child: Text(label),
            ),
      ],
    );
  }

  Future<void> _transition(String status) async {
    final note = _note.text.trim();
    await ref
        .read(supportListProvider.notifier)
        .updateStatus(
          widget.detail.id,
          status,
          adminNote: note.isEmpty ? null : note,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Widget _kv(BuildContext context, String k, String? v) {
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    final c = context.dpColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: 라우트·셸 등록**

`apps/admin/lib/src/app/router.dart` — import 추가:

```dart
import '../features/support/presentation/support_page.dart';
```

`ShellRoute`의 `routes`에 `/reports` 다음 줄로 추가:

```dart
          GoRoute(path: '/support', builder: (_, _) => const SupportPage()),
```

`apps/admin/lib/src/features/shell/presentation/admin_shell.dart`의 `kAdminDestinations`에 `/reports` 다음 줄로 추가:

```dart
  (path: '/support', icon: DpIcons.mentor, label: '문의'),
```

- [ ] **Step 8: 테스트 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/support/support_page_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 9: 모노레포 전체 확인**

```bash
cd D:/workspace/dpa/devpath-frontend
melos run analyze
melos run format
melos run test
```

Expected: 5패키지 전부 녹색. `format`은 CI 게이트다 — 실패하면 `melos run fix` 후 재실행.

- [ ] **Step 10: 커밋·푸시·PR**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/admin
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(admin): add support request console"
git -C D:/workspace/dpa/devpath-frontend push -u origin feat/support-request
gh pr create -R DevPathAi/devpath-frontend --base develop --head feat/support-request \
  --title "feat: ④ 오류 신고·문의 (web 제보 + admin 처리)" \
  --body "dp_core 마스커·링버퍼·인터셉터 / dp_design 보조 액션 / web 다이얼로그·진입점 2곳 / admin 처리 콘솔. 스펙 PR #101."
```

---

## Task 13: API 명세서 §8.1.3

**Files:**
- Modify: `documents/04_API_명세서.md`

**Interfaces:**
- Consumes: Task 3·4의 확정된 계약(경로·요청·응답·에러)

- [ ] **Step 1: 브랜치 생성**

```bash
git -C D:/workspace/dpa/documents checkout develop && git -C D:/workspace/dpa/documents pull
git -C D:/workspace/dpa/documents checkout -b docs/support-request-api
```

- [ ] **Step 2: §8.1.2 위치 확인**

```bash
grep -n "8.1.2\|8.1.3\|8.2" D:/workspace/dpa/documents/04_API_명세서.md | head
```

§8.1.2(커뮤니티 신고)가 끝나는 지점 바로 뒤에 삽입한다.

- [ ] **Step 3: 문서 작성**

`04_API_명세서.md`에 다음을 추가한다. **구현과 다르면 구현이 SSoT다** — 이 문서를 쓰기 전에 Task 3·4의 컨트롤러를 다시 읽어 경로·필드명을 대조한다.

````markdown
### 8.1.3 오류 신고·문의 (Support Request)

소유 서비스: **platform-svc**. 게이트웨이는 `/support/**`와 `/admin/**`를 모두 platform-svc로 라우팅한다.

③ 커뮤니티 신고(`community_reports`)와 **별개 기능**이다 — 대상이 콘텐츠가 아니라 서비스 자체라 스키마를 재사용하지 않는다.

| 항목 | 값 |
|---|---|
| 유형 | `ERROR` · `INQUIRY` |
| 상태 | `OPEN` · `IN_PROGRESS` · `RESOLVED` · `WONTFIX` |
| 인증 | 접수·조회 모두 로그인 필수. 관리자 경로는 `hasRole("ADMIN")` |

#### POST /support/requests — 접수

인증 필요. `reporter_id`는 요청 본문이 아니라 **JWT `sub`**에서 취한다.

```jsonc
// 요청
{
  "type": "ERROR",
  "title": "학습 경로 화면이 빈 채로 멈춰요",   // 1–200자, 공백만이면 400
  "body": "생성 버튼을 누르면 40%에서 멈춥니다.", // 1–5000자, 공백만이면 400
  "context": {
    "pagePath": "/path",          // 쿼리스트링 제거
    "appVersion": "0.1.0+42",
    "userAgent": "Mozilla/5.0 ...",
    "viewport": "1920x1080",
    "traceId": null,              // 서버가 항상 null (분산 트레이싱 미도입)
    "errorCode": "PATH_GENERATION_FAILED",
    "occurredAt": "2026-08-03T10:11:12Z",
    "failures": [                 // 최대 10건. 초과분은 거부가 아니라 앞 10건만 저장
      {
        "method": "POST",
        "path": "/learning-paths",
        "statusCode": 500,        // 네트워크 실패면 null
        "errorCode": "INTERNAL_ERROR",
        "traceId": null,
        "message": "문의: [EMAIL]", // 클라·서버 2중 마스킹 후 500자 절단
        "occurredAt": "2026-08-03T10:11:09Z"
      }
    ]
  }
}

// 201 Created
{ "id": 42 }
```

**검증 정책**: 본문(`title`·`body`·`type`)만 엄격 검증해 400을 낸다. 부가 정보(`failures` 개수·컬럼 길이)는 **거절이 아니라 절단**이다 — 제보는 사용자가 이미 문제를 겪은 뒤의 마지막 행동이라 형식 문제로 잃게 하면 안 된다.

**에러**: 검증 실패 → `VALIDATION_FAILED` 400 · 미인증 → `UNAUTHORIZED` 401

#### GET /admin/support-requests — 목록

`hasRole("ADMIN")`. 쿼리: `status` · `type` · `cursor` · `limit`(기본 20, 최대 100).

keyset 페이지네이션 — **id 내림차순(최신순)**. `cursor`가 있으면 `id < cursor`인 행만. `nextCursor`는 **꽉 찬 페이지일 때만** 마지막 행 id, 아니면 null.

```jsonc
{
  "data": [
    { "id": 42, "type": "ERROR", "title": "...", "status": "OPEN",
      "pagePath": "/path", "reporterId": 7, "failureCount": 3,
      "createdAt": "2026-08-03T10:11:12Z" }
  ],
  "nextCursor": "42",
  "limit": 20
}
```

> `GET /admin/users`는 가입 순이 자연스러워 id **오름차순**이다. 제보 목록만 방향이 반대이고, 봉투 계약(`{data,nextCursor,limit}`)은 동일하다.

#### GET /admin/support-requests/{id} — 상세

목록 필드 전체 + `body` + 수집 컨텍스트 전체 + `failures[]`(seq 오름차순) + `adminNote` · `handledBy` · `handledAt`. 없는 id는 `RESOURCE_NOT_FOUND` 404.

#### POST /admin/support-requests/{id}/status — 상태 전이

```jsonc
// 요청
{ "status": "IN_PROGRESS", "adminNote": "재현 확인함" }
// 200 — 갱신된 상세(위와 동일 형태)
```

- `status`가 4종 밖이면 `VALIDATION_FAILED` 400.
- `adminNote`는 선택. 주어지면 **덮어쓴다**(누적 이력이 아니다).
- `handled_by` = JWT `sub`, `handled_at` = now. **`OPEN`으로 되돌리면 둘 다 NULL로 초기화**한다.

#### 마스킹

응답 `message`·`body`·`page_path`는 클라이언트와 서버가 **같은 규칙·같은 순서**로 2중 마스킹한다(이메일 · 전화 · 주민번호 · 카드 · 토큰/JWT · DSN · 홈 경로 · IP). 규칙 순서와 케이스 표는 `devpath-frontend/docs/superpowers/specs/2026-08-02-support-request-design.md` §6이 SSoT다.
````

- [ ] **Step 4: 교차 문서 정합 확인**

```bash
cd D:/workspace/dpa/documents
grep -rn "문의하기\|고객지원\|오류 신고" 06_화면_기능_정의서.md 15_사용자_메뉴얼.md 33_개인정보_처리방침.md | head
```

기획 3곳(`06:798` · `15 §13` · `33 §15-2`)이 이미 이 기능을 전제하고 있다. 경로·메뉴 위치가 구현과 어긋나면 함께 고친다. 처리방침 §자동수집에 "서비스 이용 기록·접속 로그·IP·디바이스 정보"가 **이미 고지돼 있어** 신규 고지는 필요 없다.

- [ ] **Step 5: 커밋·PR**

```bash
git -C D:/workspace/dpa/documents add 04_API_명세서.md
git -C D:/workspace/dpa/documents commit -m "docs: add support request API spec (8.1.3)"
git -C D:/workspace/dpa/documents push -u origin docs/support-request-api
gh pr create -R DevPathAi/documents --base develop --head docs/support-request-api \
  --title "docs: ④ 오류 신고·문의 API 명세 (§8.1.3)" \
  --body "platform-svc 접수·관리 API 계약. 구현 PR과 대조해 작성."
```

---

## 머지 순서

CI가 녹색인 것만 머지한다.

1. **devpath-shared** → 머지 후 **`gh workflow run publish.yml --ref develop` 필수** (Task 1 Step 6)
2. **devpath-platform-svc** (shared 발행 반영 확인 후)
3. **devpath-gateway** (2와 순서 무관)
4. **devpath-frontend**
5. **documents**

## 통합 검증 (전 Task 완료 후)

- [ ] pg 컨테이너 + platform-svc + gateway 기동
- [ ] 접수 → admin 목록 → 상세 → 상태 전이를 실제 호출로 확인

```bash
# 한글 JSON 은 UTF-8 파일 + --data-binary 로 보낸다(Git Bash 의 -d 는 CP949 로 깨진다)
cat > /tmp/req.json <<'JSON'
{"type":"ERROR","title":"통합 스모크","body":"본문",
 "context":{"pagePath":"/path","failures":[{"method":"GET","path":"/x","statusCode":500,
 "message":"메일 hong@example.com","occurredAt":"2026-08-03T10:00:00Z"}]}}
JSON
curl -s -X POST http://localhost:8080/support/requests \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  --data-binary @/tmp/req.json
```

확인할 것: ① 201과 `id` ② admin 목록에 최신순으로 보임 ③ 상세의 `failures[0].message`가 `메일 [EMAIL]`로 저장됨(서버 재마스킹 실증) ④ 상태 전이 후 `handledBy`·`handledAt` 기록, `OPEN` 복귀 시 NULL

- [ ] 브라우저 스모크: `cd apps/web && flutter run -d chrome` — 앱셸 제보 버튼 → 다이얼로그 → 접이식 미리보기 → 제출. **한글 IME 조합**이 제목·내용 필드에서 끊기지 않는지 직접 타이핑해 확인한다(2026-08-01 서식 에디터 교훈).

## 범위 밖 (스펙 §2 — 후속 백로그)

자동 오류 리포팅(C안) · 관리자 답변을 사용자가 확인하는 흐름 · 스크린샷 첨부 · 비로그인 접수(게이트웨이 미인증 라우트 + IP 레이트리밋 선행 필요)

> **알려진 한계**: 로그인 필수라 **로그인 자체가 실패하는 오류는 이 경로로 제보할 수 없다.** 이메일 안내로 대체한다.
