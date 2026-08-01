# 커뮤니티 검색 1단계(Elasticsearch 키워드 검색) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 커뮤니티 홈에서 한국어 검색어로 글(제목·본문·태그)을 찾고 보드·태그·해결여부로 좁힐 수 있게 한다. 매칭 부분은 하이라이트되고, 새 글은 Kafka 경유로 색인에 반영된다.

**Architecture:** `community-svc`가 Elasticsearch(nori 한국어 분석기)에 글을 색인한다. 색인 트리거는 **기존 Outbox 패턴**(트랜잭션 내 `OutboxEntry` 저장 → 2초 주기 릴레이 → Kafka → `PostIndexConsumer`)을 그대로 따른다. 검색은 ES에서 **매칭 id·하이라이트·총건수만** 받고, 화면에 표시할 `PostSummaryView`는 **DB에서 조립**한다(ES가 stale해도 표시 데이터는 항상 정확). 프론트는 커뮤니티 홈 상단 검색바에서 `?q=`를 URL에 동기해 결과를 기존 `DpListRow`로 렌더한다.

**Tech Stack:** Java 21 · Spring Boot 4 · Gradle Kotlin DSL · **Elasticsearch 9.2.8(+analysis-nori)** · Spring Kafka · JPA + JdbcTemplate · JUnit 5 + AssertJ + MockMvc · Flutter Web · freezed · flutter_riverpod 3 · go_router · melos

> **★Task 1 실측 확정(2026-08-01) — 이후 Task는 이 값을 전제로 한다**
> - 클라이언트: `org.springframework.boot:spring-boot-starter-data-elasticsearch`(Boot 4.0.7 관리) → 저수준 **`co.elastic.clients:elasticsearch-java:9.2.8`**. `ElasticsearchClient` 빈이 자동설정으로 주입된다.
> - 서버 이미지: **`docker.elastic.co/elasticsearch/elasticsearch:9.2.8`** + `analysis-nori`(로컬 태그 `devpath-es:local`)
> - 설정 프로퍼티: **`spring.elasticsearch.uris`**
> - 인덱스 분석기: `nori_analyzer`(`{"type":"nori"}`) — `Analyzer.Builder.nori(...)`로 정의
> - **초안이 가정한 "8.x"는 오류**였다. Spring Boot 4 세대는 Elastic 클라이언트 9.x를 가져온다.

**참조 spec:** `devpath-frontend/docs/superpowers/specs/2026-08-01-community-search-design.md` (커밋 `8e9df80`)

## Global Constraints

- **레포 3곳**: `devpath-community-svc`(백엔드) · `devpath-gitops`(인프라) · `devpath-frontend`(프론트). 각 레포 브랜치명은 **`feat/community-search`**, 각자 `develop`에서 분기해 각자 `develop`으로 PR. **백엔드 먼저 머지**(계약 확정) → 프론트.
- **모든 git 명령은 `git -C <레포 절대경로>`**, gradle은 `cd <레포 절대경로> && ./gradlew ...`, flutter는 `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter ...` 형태로 **한 호출 안에서** 실행한다. 도구 호출 사이 cwd가 리셋된다.
- **TDD 필수**(CLAUDE.md 규칙 2): 실패 테스트 선작성 → 최소 구현 → 통과 확인.
- **추측 금지**(규칙 1): 라이브러리 API·버전을 상상해서 쓰지 않는다. **ES 클라이언트 API는 반드시 실측**(의존 해석 결과·pub/maven 소스·공식 문서)한 뒤 사용한다. 막히면 멈추고 `NEEDS_CONTEXT` 보고.
- **이벤트 발행 = 기존 Outbox 패턴**: 트랜잭션 안에서 `OutboxEntry`(`aggregateType`·`aggregateId`·`eventType`=Kafka 토픽명·`payload` JSON) 저장. 새 프로듀서를 만들지 않는다. 선례 = `CollusionDetector`·`BadgeService`.
- **Kafka 토픽명**: `community.post.changed`
- **ES 인덱스명**: `community_posts`. 문서 `_id` = `community_posts.id`.
- **색인 대상**: `status='PUBLISHED'`인 글만. 제목·본문·태그 + 필터용 메타(`boardType`·`status`·`authorId`·`isSolved`·`createdAt`).
- **검색 API**: `GET /community/search?q=&board=&tag=&solved=&sort=&page=&size=` — `q` 빈 값/공백이면 **400**. `sort`는 `relevance`(기본)·`latest`만. 응답은 `{items:[...], total, page, size}` envelope이며 `items` 원소는 기존 `PostSummaryView` + `highlight` 필드.
- **재색인 API**: `POST /admin/community/reindex`(ADMIN) → `{"indexed": N}`
- **ES 장애 시 검색은 명시적 에러**(빈 결과 아님). 목록·글쓰기는 ES와 무관하게 계속 동작해야 한다.
- **CI 제약**: `community-svc` CI(`.github/workflows/ci.yml`)는 GitHub Actions `services:`로 postgres만 띄운다. **Kafka가 없다.** 그래서 색인 로직을 `PostIndexer`(ES만 필요)와 `PostIndexConsumer`(Kafka 어댑터)로 **분리**한다. Testcontainers는 도입하지 않는다(기존 패턴 유지).
- **shared 발행 불필요**: 검색 관련 record는 community-svc 로컬 타입.
- **비범위**: k3s 실적용·실서버 스모크(AWS 정지), 답변·댓글 색인, 작성자·기간 필터, 추천순 정렬, 자동완성, 의미검색(2단계).
- **게이트**: 백엔드 `./gradlew test`. 프론트 `melos run format`(`--set-exit-if-changed`) → `analyze` → `test`. melos가 PATH에 없으면 `dart pub global run melos <cmd>`.

## File Structure

**devpath-community-svc** (패키지 `ai.devpath.community.search` 신설)
- `build.gradle.kts` (수정) — ES 클라이언트 의존
- `src/main/java/ai/devpath/community/search/SearchIndexProperties.java` (신규) — 인덱스명·호스트 설정
- `src/main/java/ai/devpath/community/search/PostIndexBootstrap.java` (신규) — 기동 시 인덱스·매핑 생성(멱등)
- `src/main/java/ai/devpath/community/search/PostIndexer.java` (신규) — **ES upsert/delete만**. Kafka 비의존
- `src/main/java/ai/devpath/community/search/PostIndexConsumer.java` (신규) — Kafka 리스너 → `PostIndexer` 위임
- `src/main/java/ai/devpath/community/search/PostSearchService.java` (신규) — ES 질의 → id·highlight·total, DB 조립
- `src/main/java/ai/devpath/community/search/SearchController.java` (신규) — `GET /community/search`
- `src/main/java/ai/devpath/community/search/ReindexService.java` (신규) — 전량 재색인
- `src/main/java/ai/devpath/community/search/AdminSearchController.java` (신규) — `POST /admin/community/reindex`
- `src/main/java/ai/devpath/community/search/dto/{SearchHit,SearchResponse,SearchItemView}.java` (신규)
- `src/main/java/ai/devpath/community/post/QuestionService.java` (수정) — 글 생성/수정/삭제 시 Outbox 발행 + id 목록 → `PostSummaryView` 조립 메서드 추출
- `.github/workflows/ci.yml` (수정) — ES service 추가
- `docker/elasticsearch/Dockerfile` (신규) — nori 설치 이미지
- 테스트: `PostIndexerTest`·`PostSearchServiceTest`·`SearchControllerTest`·`PostIndexConsumerTest`·`ReindexServiceTest`

**devpath-gitops**
- `apps/devpath-elasticsearch/` (신규) — StatefulSet·Service·PVC 매니페스트

**devpath-frontend**
- `packages/dp_core/lib/src/models/community_search.dart` (신규) — `CommunitySearchItem`·`CommunitySearchResult`
- `packages/dp_core/lib/dp_core.dart` (수정) — barrel export
- `apps/web/lib/src/features/community/data/community_source.dart` (수정) — `communitySearchProvider`
- `apps/web/lib/src/features/community/presentation/widgets/community_search_bar.dart` (신규)
- `apps/web/lib/src/features/community/presentation/community_home_page.dart` (수정) — 검색바·결과 분기
- `apps/web/lib/src/features/community/presentation/community_controller.dart` (수정 또는 신규 검색 컨트롤러)
- `apps/web/lib/src/app/router.dart` (수정) — `?q=` 파라미터
- `apps/web/lib/src/data/web_mock_fixtures.dart` (수정) — 검색 목
- 테스트: `community_search_bar_test.dart`·`community_search_test.dart`

---

## Task 1: ES 기반 구축 — nori 이미지 · 의존 · 인덱스 부트스트랩 · CI

**Repo:** `devpath-community-svc`

**Files:**
- Create: `docker/elasticsearch/Dockerfile`
- Modify: `build.gradle.kts`
- Create: `src/main/java/ai/devpath/community/search/SearchIndexProperties.java`
- Create: `src/main/java/ai/devpath/community/search/PostIndexBootstrap.java`
- Modify: `src/main/resources/application.yml` (또는 동등 설정 파일 — 실제 파일명 확인)
- Modify: `.github/workflows/ci.yml`
- Test: `src/test/java/ai/devpath/community/search/PostIndexBootstrapTest.java`

**Interfaces:**
- Produces: `SearchIndexProperties`(`getIndexName()` → `String`, 기본 `community_posts`), `PostIndexBootstrap.ensureIndex()` — 인덱스가 없으면 nori 매핑으로 생성, 있으면 no-op(멱등). Task 2·3·5가 이 인덱스를 사용한다.

- [ ] **Step 1: 브랜치 생성**

```bash
git -C D:/workspace/dpa/devpath-community-svc fetch origin
git -C D:/workspace/dpa/devpath-community-svc checkout develop
git -C D:/workspace/dpa/devpath-community-svc pull origin develop
git -C D:/workspace/dpa/devpath-community-svc checkout -b feat/community-search
git -C D:/workspace/dpa/devpath-community-svc status --short
```
Expected: clean, 브랜치 `feat/community-search`

- [ ] **Step 2: ES 클라이언트 의존을 실측으로 확정**

**추측 금지 단계다.** Spring Boot 4에서 사용 가능한 ES 클라이언트를 확인한다.

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew dependencies --configuration compileClasspath 2>&1 | head -40
```

그다음 아래 후보를 순서대로 시도해 **실제로 해석되는 것**을 채택한다:

1순위 — Spring Boot 스타터(자동설정·헬스체크 포함):
```kotlin
implementation("org.springframework.boot:spring-boot-starter-data-elasticsearch")
```
2순위 — 공식 Java 클라이언트(직접 제어, 이 레포의 `JdbcTemplate` 직접 사용 스타일과 정합):
```kotlin
implementation("co.elastic.clients:elasticsearch-java:8.15.0")
```

각각에 대해 `./gradlew dependencies --configuration compileClasspath` 또는 `./gradlew build -x test`로 해석 여부를 확인하라. **해석된 ES 클라이언트 버전을 기록**하고, 그 버전과 호환되는 **ES 서버 8.x 패치 버전**을 Step 3 이미지 태그로 고정한다.

둘 다 실패하면 멈추고 `NEEDS_CONTEXT`로 보고하라(어떤 오류였는지 전문 포함).

- [ ] **Step 3: nori 플러그인 이미지 작성**

Create `docker/elasticsearch/Dockerfile` — Step 2에서 확정한 서버 버전으로 `<VER>`를 채운다:

```dockerfile
# 커뮤니티 검색용 Elasticsearch + 한국어 형태소 분석기(nori).
# 공식 이미지에 nori 가 없고 GitHub Actions services: 는 컨테이너 내부에서
# 임의 명령을 실행할 수 없어, 플러그인을 미리 설치한 이미지를 CI 와 배포가 공유한다.
FROM docker.elastic.co/elasticsearch/elasticsearch:<VER>
RUN elasticsearch-plugin install --batch analysis-nori
```

로컬 빌드·기동 확인:

```bash
cd D:/workspace/dpa/devpath-community-svc && docker build -t devpath-es:local docker/elasticsearch
docker run -d --name dpa-test-es -p 9200:9200 -e discovery.type=single-node -e xpack.security.enabled=false -e ES_JAVA_OPTS="-Xms512m -Xmx512m" devpath-es:local
```

기동 확인(수 초 대기 후):
```bash
curl -s http://localhost:9200 | head -20
curl -s http://localhost:9200/_cat/plugins
```
Expected: 버전 JSON 출력 + plugins 목록에 `analysis-nori`

**이 절차를 리포트에 기록하라** — 다른 개발자가 로컬 환경을 재현해야 한다.

- [ ] **Step 4: 실패 테스트 작성 — 인덱스 부트스트랩**

Create `src/test/java/ai/devpath/community/search/PostIndexBootstrapTest.java`.

이 레포의 기존 통합 테스트 스타일을 먼저 확인하고 맞춰라:
```bash
cd D:/workspace/dpa/devpath-community-svc && ls src/test/java/ai/devpath/community/post/
```
(예: `@SpringBootTest` + 실제 postgres 사용 패턴)

테스트 요건 — **실제 ES 대상**:
1. `ensureIndex()` 호출 후 인덱스 `community_posts`가 존재한다
2. 매핑에 `title`·`bodyMd`가 nori 분석기로 설정돼 있다
3. **두 번 호출해도 예외 없이 통과**한다(멱등)

ES 클라이언트 API가 확정되지 않은 상태이므로, **Step 2에서 채택한 클라이언트의 실제 API**로 작성하라. 인덱스 존재 확인·매핑 조회 메서드명을 상상하지 말고 해당 클라이언트 문서/소스로 확인할 것.

- [ ] **Step 5: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*PostIndexBootstrapTest*"
```
Expected: FAIL — `PostIndexBootstrap` 클래스 없음(컴파일 에러)

- [ ] **Step 6: `SearchIndexProperties` + `PostIndexBootstrap` 구현**

`SearchIndexProperties` — 인덱스명을 설정으로 뺀다(테스트가 별도 인덱스를 쓸 수 있게):

```java
package ai.devpath.community.search;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** 검색 인덱스 설정. 테스트는 별도 인덱스명을 주입해 운영 인덱스와 격리한다. */
@ConfigurationProperties(prefix = "devpath.search")
public class SearchIndexProperties {
  private String indexName = "community_posts";

  public String getIndexName() {
    return indexName;
  }

  public void setIndexName(String indexName) {
    this.indexName = indexName;
  }
}
```

`PostIndexBootstrap` — 기동 시 인덱스를 만든다. 매핑은 §4.3 그대로:
- `title`: text + nori
- `bodyMd`: text + nori
- `tags`: keyword
- `boardType`·`status`·`authorId`: keyword
- `isSolved`: boolean
- `createdAt`: date

멱등이어야 한다(존재하면 no-op). 애플리케이션 기동 시 자동 실행되도록 `ApplicationRunner` 또는 `@EventListener(ApplicationReadyEvent.class)`를 쓰되, **ES가 죽어 있어도 앱 기동이 실패하면 안 된다** — 실패는 `log.warn`으로 남기고 계속 진행한다(검색만 불가, 나머지 기능은 정상). 이는 Global Constraints의 "목록·글쓰기는 ES와 무관하게 동작" 요건이다.

`@ConfigurationProperties`를 쓰려면 `@EnableConfigurationProperties(SearchIndexProperties.class)` 등록이 필요하다 — 이 레포의 기존 설정 클래스 패턴을 따르라.

- [ ] **Step 7: 테스트 실행 — 통과 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*PostIndexBootstrapTest*"
```
Expected: PASS

- [ ] **Step 8: CI에 ES service 추가**

`.github/workflows/ci.yml`의 `services:` 블록에 ES를 추가한다. 기존 postgres 항목과 같은 형식이며, **이미지는 Step 3에서 만든 nori 포함 이미지**여야 한다.

GitHub Actions `services:`는 레지스트리 이미지만 쓸 수 있으므로 **GHCR에 발행**한다. 이 레포의 기존 이미지 발행 워크플로(`Dockerfile` → GHCR)를 확인해 같은 방식으로 ES 이미지 발행 job을 추가하거나, 별도 워크플로로 분리하라:

```bash
cd D:/workspace/dpa/devpath-community-svc && ls .github/workflows/ && grep -n "ghcr.io\|docker/build-push-action" .github/workflows/*.yml | head
```

ES service 예시(태그는 실제 발행한 이미지로):
```yaml
      elasticsearch:
        image: ghcr.io/devpathai/devpath-elasticsearch:<VER>
        env:
          discovery.type: single-node
          xpack.security.enabled: "false"
          ES_JAVA_OPTS: -Xms512m -Xmx512m
        ports:
          - 9200:9200
        options: >-
          --health-cmd "curl -sf http://localhost:9200 || exit 1"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 10
```

**GHCR 발행 권한·경로가 막히면** 멈추고 `NEEDS_CONTEXT`로 보고하라(대안: CI에서 `docker build` 후 `--network` 연결하는 step 방식으로 전환 가능하나, 이는 별도 결정이 필요하다).

- [ ] **Step 9: 커밋**

```bash
git -C D:/workspace/dpa/devpath-community-svc add build.gradle.kts docker/elasticsearch/Dockerfile src/main/java/ai/devpath/community/search src/test/java/ai/devpath/community/search .github/workflows
git -C D:/workspace/dpa/devpath-community-svc commit -m "feat(search): ES 기반 구축 — nori 이미지·클라이언트 의존·인덱스 부트스트랩"
```

application 설정 파일도 변경했다면 함께 add하라. `git status --short`로 실제 변경 파일을 확인할 것.

**보고 항목**: 채택한 ES 클라이언트와 버전, 확정한 ES 서버 버전, 로컬 ES 실행 절차, GHCR 이미지 경로.

---

## Task 2: `PostIndexer` — ES 색인 upsert/delete

**Repo:** `devpath-community-svc`

**Files:**
- Create: `src/main/java/ai/devpath/community/search/PostIndexer.java`
- Test: `src/test/java/ai/devpath/community/search/PostIndexerTest.java`

**Interfaces:**
- Consumes: `SearchIndexProperties.getIndexName()`, Task 1이 만든 인덱스.
- Produces:
  - `void PostIndexer.index(long postId)` — DB에서 글을 읽어 ES에 upsert. `status != 'PUBLISHED'`이거나 글이 없으면 **delete로 처리**(비공개 전환·삭제를 한 경로로 흡수).
  - `void PostIndexer.delete(long postId)` — ES 문서 삭제. 없어도 예외 없음(멱등).
  Task 4(Consumer)·Task 5(재색인)가 호출한다.

- [ ] **Step 1: 실패 테스트 작성**

Create `src/test/java/ai/devpath/community/search/PostIndexerTest.java`.

검증 항목:
1. `index(postId)` 후 ES에서 해당 문서를 조회하면 `title`·`bodyMd`·`boardType`·`tags`가 DB 값과 일치한다
2. **한국어 검색이 실제로 매칭된다** — 예: 본문이 `"리액트에서 useEffect가 두 번 실행됩니다"`인 글을 색인한 뒤 `useEffect`로 질의하면 걸린다(nori 분석기 동작 확인)
3. `delete(postId)` 후 문서가 없다
4. **없는 문서를 delete해도 예외가 나지 않는다**(멱등)
5. `status`가 `PUBLISHED`가 아닌 글을 `index()`하면 **ES에 남지 않는다**

테스트 데이터는 이 레포 기존 통합 테스트가 쓰는 방식(실제 postgres에 글 저장)을 따르라. 색인 직후 검색이 보이지 않을 수 있으므로 **refresh 처리**가 필요하다 — ES 클라이언트의 refresh 옵션 또는 명시적 refresh 호출을 쓰되, **API는 실측 확인**할 것.

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*PostIndexerTest*"
```
Expected: FAIL — `PostIndexer` 없음

- [ ] **Step 3: `PostIndexer` 구현**

요건:
- 생성자 주입: ES 클라이언트, `SearchIndexProperties`, 글 조회 리포지토리(`CommunityPostRepository` 등 실제 이름 확인), 태그 조회(`QuestionService.tagNamesFor` 같은 기존 메서드가 private이면 리포지토리에서 직접 조회)
- `index(long postId)`:
  1. DB에서 글 조회 → 없거나 `status != "PUBLISHED"` → `delete(postId)` 후 반환
  2. 문서 필드 구성: `title`·`bodyMd`·`tags`·`boardType`·`status`·`authorId`·`isSolved`·`createdAt`
     - `isSolved`: Q&A만 실제 값, 그 외 `false`(기존 `QuestionService.list()` 로직과 동일 규칙)
  3. ES upsert(문서 `_id` = postId)
- `delete(long postId)`: ES delete. 문서 부재는 정상 처리
- **Kafka·Outbox를 import하지 않는다.** 이 클래스는 ES만 안다(CI에 Kafka가 없어도 테스트 가능해야 하는 이유).
- ES 장애 시 예외를 삼키지 말고 던진다 — 호출자(Consumer)가 재시도를 결정한다.

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*PostIndexerTest*"
```
Expected: PASS (5개 케이스)

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-community-svc add src/main/java/ai/devpath/community/search/PostIndexer.java src/test/java/ai/devpath/community/search/PostIndexerTest.java
git -C D:/workspace/dpa/devpath-community-svc commit -m "feat(search): PostIndexer — ES 색인 upsert/delete(멱등)"
```

---

## Task 3: 검색 서비스 + `GET /community/search`

**Repo:** `devpath-community-svc`

**Files:**
- Create: `src/main/java/ai/devpath/community/search/dto/SearchItemView.java`
- Create: `src/main/java/ai/devpath/community/search/dto/SearchResponse.java`
- Create: `src/main/java/ai/devpath/community/search/PostSearchService.java`
- Create: `src/main/java/ai/devpath/community/search/SearchController.java`
- Modify: `src/main/java/ai/devpath/community/post/QuestionService.java` — id 목록 → `PostSummaryView` 조립 메서드 추출
- Test: `src/test/java/ai/devpath/community/search/PostSearchServiceTest.java`
- Test: `src/test/java/ai/devpath/community/search/SearchControllerTest.java`

**Interfaces:**
- Consumes: `PostIndexer`(테스트에서 색인용), Task 1 인덱스.
- Produces:
  - `record SearchItemView(long id, String boardType, String title, Long authorId, boolean solved, int upvoteCount, int replyCount, String excerpt, String highlight)`
  - `record SearchResponse(List<SearchItemView> items, long total, int page, int size)`
  - `SearchResponse PostSearchService.search(String q, String board, String tag, Boolean solved, String sort, int page, int size)`
  - `QuestionService.summariesByIds(List<Long> ids)` → `List<PostSummaryView>` (**입력 id 순서를 보존**한다 — ES 관련도 순서가 유지되어야 한다)

- [ ] **Step 1: `QuestionService`에서 조립 로직 추출 (리팩터, 동작 불변)**

현재 `QuestionService.list(board, tag, sort)`(`:89-107`)는 조회와 조립이 한 메서드에 섞여 있다. 조립부를 재사용 가능한 메서드로 뺀다:

```java
  /** 글 목록을 표시용 요약으로 조립한다. QNA 는 답변 수·해결 여부, 그 외는 댓글 수를 센다. */
  private PostSummaryView toSummary(CommunityPost p) {
    boolean isQna = "QNA".equals(p.getBoardType());
    int replyCount = isQna
        ? (int) answers.countByQuestionId(p.getId())
        : (int) comments.countByPostId(p.getId());
    boolean solved = isQna
        ? questions.findById(p.getId()).map(CommunityQuestion::isSolved).orElse(false)
        : false;
    return new PostSummaryView(p.getId(), p.getBoardType(), p.getTitle(),
        p.getAuthorId(), solved, p.getUpvoteCount(), replyCount,
        Excerpts.from(p.getBodyMd(), 140));
  }

  /** 검색 결과 조립용 — 입력 id 순서(관련도 순)를 그대로 보존한다. */
  public List<PostSummaryView> summariesByIds(List<Long> ids) {
    if (ids.isEmpty()) {
      return List.of();
    }
    Map<Long, CommunityPost> byId = posts.findAllById(ids).stream()
        .collect(Collectors.toMap(CommunityPost::getId, p -> p));
    return ids.stream()
        .map(byId::get)
        .filter(Objects::nonNull)
        .map(this::toSummary)
        .collect(Collectors.toList());
  }
```

`list()`는 `toSummary`를 쓰도록 바꾼다(동작 동일). **기존 `list()` 테스트가 그대로 통과해야 한다.**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*QuestionService*"
```
Expected: 기존 테스트 전부 PASS (리팩터라 동작 불변)

- [ ] **Step 2: 실패 테스트 작성 — 검색 서비스**

Create `src/test/java/ai/devpath/community/search/PostSearchServiceTest.java`.

검증 항목(실제 ES + 실제 postgres):
1. **한국어 키워드 매칭**: 본문에 `"리액트 상태관리는 Riverpod이 편합니다"`가 있는 글을 색인 후 `Riverpod`으로 검색하면 걸린다
2. **제목 가중치**: 제목에 검색어가 있는 글이 본문에만 있는 글보다 앞선다
3. **board 필터**: `board=QNA`면 자유글이 제외된다
4. **tag 필터**: 해당 태그가 붙은 글만 나온다
5. **solved 필터**: `solved=true`면 해결된 Q&A만
6. **페이징**: `size=2`일 때 `items` 2건, `total`은 전체 매칭 수
7. **`sort=latest`**: `createdAt` 내림차순
8. **하이라이트**: 매칭된 글의 `highlight`에 `<em>`으로 감싼 검색어가 포함된다
9. **본문 매칭이 없으면 `highlight`는 기존 `excerpt` 폴백**
10. **결과 순서 보존**: ES 관련도 순서가 최종 `items` 순서와 같다(`summariesByIds` 계약)
11. **비공개 글 제외**: `status != 'PUBLISHED'`인 글은 결과에 없다

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*PostSearchServiceTest*"
```
Expected: FAIL — `PostSearchService` 없음

- [ ] **Step 4: `PostSearchService` 구현**

동작:
1. ES 질의 구성
   - `multi_match`로 `title`(가중치 상향, 예 `title^2`)·`bodyMd` 대상
   - 필터(`filter` 절): `status=PUBLISHED` 고정 + `boardType`/`tags`/`isSolved`(파라미터가 있을 때만)
   - `sort`: `relevance`면 스코어순(기본), `latest`면 `createdAt` desc
   - `from = page * size`, `size = size`
   - highlight: `bodyMd` 대상, pre/post 태그 `<em>`/`</em>`
2. 응답에서 **id 목록·highlight 맵·total** 추출
3. `questionService.summariesByIds(ids)`로 표시 데이터 조립(**순서 보존**)
4. `PostSummaryView` + `highlight`(없으면 `excerpt`)로 `SearchItemView` 매핑
5. `SearchResponse(items, total, page, size)` 반환

**ES 클라이언트 질의 DSL은 Task 1에서 채택한 클라이언트의 실제 API로 작성한다.** 메서드명을 상상하지 말 것.

- [ ] **Step 5: 테스트 실행 — 통과 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*PostSearchServiceTest*"
```
Expected: PASS (11개 케이스)

- [ ] **Step 6: 실패 테스트 작성 — 컨트롤러**

Create `src/test/java/ai/devpath/community/search/SearchControllerTest.java` — 이 레포의 기존 MockMvc 테스트 스타일을 따르라.

검증 항목:
1. `GET /community/search?q=Riverpod` → 200, 응답에 `items`·`total`·`page`·`size` 키 존재
2. **`q` 누락 → 400**
3. **`q`가 공백만(`q=%20%20`) → 400**
4. 필터 파라미터(`board`·`tag`·`solved`·`sort`·`page`·`size`)가 서비스에 그대로 전달된다
5. **ES 장애(서비스가 예외를 던짐) → 5xx 에러 응답**(빈 결과 아님). 이 프로젝트의 표준 에러 envelope(스펙 §3.4 중첩 구조)를 따르는지 확인 — 기존 `GlobalExceptionHandler`가 있으면 그 경로로 처리된다

- [ ] **Step 7: `SearchController` 구현 + 테스트 통과**

```java
@GetMapping("/search")
public ResponseEntity<SearchResponse> search(
    @RequestParam String q,
    @RequestParam(required = false) String board,
    @RequestParam(required = false) String tag,
    @RequestParam(required = false) Boolean solved,
    @RequestParam(required = false, defaultValue = "relevance") String sort,
    @RequestParam(required = false, defaultValue = "0") int page,
    @RequestParam(required = false, defaultValue = "20") int size) {
  if (q == null || q.isBlank()) {
    throw new IllegalArgumentException("검색어(q)는 필수입니다.");
  }
  return ResponseEntity.ok(searchService.search(q, board, tag, solved, sort, page, size));
}
```

`IllegalArgumentException` → 400 매핑이 이 레포에 이미 있는지 확인하라(에러 envelope 표준화 작업에서 `shared`가 `IllegalArgumentException` 핸들러를 발행했다). 없으면 `@ResponseStatus` 또는 핸들러를 추가한다.

`SearchController`를 `CommunityController`에 합치지 말고 **별도 클래스**로 둔다(파일이 이미 크고, 검색은 독립 관심사다). 매핑 경로는 `@RequestMapping("/community")`.

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*SearchControllerTest*"
```
Expected: PASS

- [ ] **Step 8: 커밋**

```bash
git -C D:/workspace/dpa/devpath-community-svc add src/main/java/ai/devpath/community/search src/main/java/ai/devpath/community/post/QuestionService.java src/test/java/ai/devpath/community/search
git -C D:/workspace/dpa/devpath-community-svc commit -m "feat(search): 검색 서비스 + GET /community/search(BM25·필터·페이징·하이라이트)"
```

---

## Task 4: Outbox 발행 + `PostIndexConsumer`

**Repo:** `devpath-community-svc`

**Files:**
- Modify: `src/main/java/ai/devpath/community/post/QuestionService.java` — 글 생성/수정/삭제 시 Outbox 발행
- Create: `src/main/java/ai/devpath/community/search/PostIndexConsumer.java`
- Test: `src/test/java/ai/devpath/community/search/PostIndexConsumerTest.java`
- Test: `src/test/java/ai/devpath/community/post/QuestionServiceOutboxTest.java`

**Interfaces:**
- Consumes: `PostIndexer.index(long)`·`PostIndexer.delete(long)` (Task 2)
- Produces: Kafka 토픽 `community.post.changed` 메시지. payload = `{"postId": 123, "deleted": false}` JSON. 소비자는 `deleted=true`면 `delete`, 아니면 `index`를 호출한다.

**배경**: 이 레포의 이벤트 발행 표준은 **Outbox**다(`CollusionDetector`·`BadgeService` 선례). 트랜잭션 안에서 `OutboxEntry`를 저장하면 `OutboxRelayScheduler`(2초 주기)가 Kafka로 발행한다. **새 `KafkaTemplate` 프로듀서를 만들지 말 것.**

- [ ] **Step 1: 기존 Outbox 발행 선례 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && sed -n '30,50p' src/main/java/ai/devpath/community/abuse/CollusionDetector.java
```

`OutboxEntry`의 필드 설정 방식(`aggregateType`·`aggregateId`·`eventType`·`payload`·`createdAt`)과 JSON 직렬화에 쓰는 컴포넌트(`JsonMapper` 등)를 그대로 따른다.

- [ ] **Step 2: 실패 테스트 작성 — Outbox 발행**

Create `src/test/java/ai/devpath/community/post/QuestionServiceOutboxTest.java`.

검증 항목:
1. 글을 생성하면 `community_outbox`에 `eventType="community.post.changed"`, `aggregateId=<postId>` 엔트리가 **1건** 쌓인다
2. payload JSON에 `postId`가 들어 있고 `deleted`가 `false`다
3. 글을 삭제하면 `deleted=true` 엔트리가 쌓인다

**주의**: 스케줄러는 `@Profile("!test")`라 테스트에서 발행이 일어나지 않는다. **outbox 테이블에 쌓이는 것까지만** 검증한다(그 이후는 검증된 기존 인프라).

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*QuestionServiceOutboxTest*"
```
Expected: FAIL — outbox 엔트리 0건

- [ ] **Step 4: `QuestionService`에 Outbox 발행 추가**

글 생성·수정·삭제 경로에서 **같은 트랜잭션 안에** 엔트리를 저장한다. 헬퍼를 하나 만들어 중복을 없앤다:

```java
  /** 검색 색인 갱신 이벤트. Outbox 에 쌓아 두면 릴레이가 Kafka 로 발행한다(2초 주기). */
  private void enqueueIndexEvent(long postId, boolean deleted) {
    OutboxEntry entry = new OutboxEntry();
    entry.setAggregateType("community_post");
    entry.setAggregateId(String.valueOf(postId));
    entry.setEventType("community.post.changed");
    entry.setPayload(jsonMapper.write(Map.of("postId", postId, "deleted", deleted)));
    entry.setCreatedAt(Instant.now());
    outbox.save(entry);
  }
```

`jsonMapper.write(...)`의 실제 메서드명은 **Step 1에서 확인한 선례 그대로** 쓸 것(다를 수 있다).

호출 지점: 질문 생성·일반글 생성·글 삭제(있다면 수정도). **어느 메서드가 글을 만들고 지우는지 실제 코드로 확인**한 뒤 붙여라.

- [ ] **Step 5: 테스트 통과 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*QuestionServiceOutboxTest*"
```
Expected: PASS

- [ ] **Step 6: 실패 테스트 작성 — Consumer**

Create `src/test/java/ai/devpath/community/search/PostIndexConsumerTest.java`.

**Kafka 없이** 순수 단위 테스트(Mockito로 `PostIndexer` mock):
1. `deleted=false` payload → `indexer.index(postId)` 호출, `delete` 미호출
2. `deleted=true` payload → `indexer.delete(postId)` 호출, `index` 미호출
3. 잘못된 JSON payload → 예외를 던진다(에러 핸들러가 재시도/스킵을 결정)

- [ ] **Step 7: `PostIndexConsumer` 구현**

이 레포의 기존 컨슈머(`CommunitySeedConsumer`)의 `@KafkaListener` 설정 방식을 그대로 따른다:

```bash
cd D:/workspace/dpa/devpath-community-svc && cat src/main/java/ai/devpath/community/seed/CommunitySeedConsumer.java
```

구현은 **얇게** — payload 파싱 후 `PostIndexer`에 위임만 한다. ES 로직을 여기 넣지 말 것(Task 2의 분리 결정).

- [ ] **Step 8: 테스트 통과 + 커밋**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*PostIndexConsumerTest*"
git -C D:/workspace/dpa/devpath-community-svc add src/main/java/ai/devpath/community src/test/java/ai/devpath/community
git -C D:/workspace/dpa/devpath-community-svc commit -m "feat(search): 글 변경 시 Outbox 이벤트 발행 + 색인 컨슈머"
```

---

## Task 5: 재색인 배치 + `POST /admin/community/reindex`

**Repo:** `devpath-community-svc`

**Files:**
- Create: `src/main/java/ai/devpath/community/search/ReindexService.java`
- Create: `src/main/java/ai/devpath/community/search/AdminSearchController.java`
- Test: `src/test/java/ai/devpath/community/search/ReindexServiceTest.java`

**Interfaces:**
- Consumes: `PostIndexer.index(long)` (Task 2)
- Produces: `int ReindexService.reindexAll()` — 색인한 건수 반환. `POST /admin/community/reindex` → `{"indexed": N}`

- [ ] **Step 1: 실패 테스트 작성**

Create `src/test/java/ai/devpath/community/search/ReindexServiceTest.java`.

검증 항목:
1. `PUBLISHED` 글 3건이 DB에 있을 때 `reindexAll()`이 **3을 반환**하고 ES에서 3건 모두 검색된다
2. **비공개 글은 색인되지 않는다**(반환 건수에서도 제외)
3. **ES를 비운 뒤 재색인하면 완전히 복구**된다(색인 유실 복구 시나리오)

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*ReindexServiceTest*"
```
Expected: FAIL — `ReindexService` 없음

- [ ] **Step 3: `ReindexService` 구현**

```java
package ai.devpath.community.search;

/** 전체 재색인. 이벤트 유실·ES 재구축·기존 글 백필을 한 경로로 해결한다. */
@Service
public class ReindexService {

  private static final int CHUNK = 500;

  // 생성자 주입: CommunityPostRepository(실제 타입명 확인), PostIndexer

  public int reindexAll() {
    int indexed = 0;
    // status='PUBLISHED' 인 글의 id 를 CHUNK 단위로 조회해 indexer.index(id) 호출
    // 건수를 누적해 반환
    return indexed;
  }
}
```

청크 조회는 리포지토리에 메서드를 추가하거나 `JdbcTemplate`로 `select id from community_posts where status='PUBLISHED' order by id` 후 순회한다 — **이 레포에서 이미 쓰는 방식**(JPA/JdbcTemplate 혼용)을 따르라. 베타 규모에서는 단순 순회로 충분하지만, 청크 구조는 유지한다.

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test --tests "*ReindexServiceTest*"
```
Expected: PASS (3개 케이스)

- [ ] **Step 5: `AdminSearchController` 추가**

```java
@RestController
@RequestMapping("/admin/community")
public class AdminSearchController {

  private final ReindexService reindexService;

  public AdminSearchController(ReindexService reindexService) {
    this.reindexService = reindexService;
  }

  @PostMapping("/reindex")
  public ResponseEntity<Map<String, Integer>> reindex() {
    return ResponseEntity.ok(Map.of("indexed", reindexService.reindexAll()));
  }
}
```

**ADMIN 권한 적용이 필요하다.** 이 레포의 SecurityConfig에서 `/admin/**` 경로 규칙이 이미 있는지 확인하고, 없으면 기존 admin 보호 패턴(다른 서비스의 `@PreAuthorize("hasRole('ADMIN')")` 등)을 따라 추가하라:

```bash
cd D:/workspace/dpa/devpath-community-svc && grep -rn "admin\|ADMIN" src/main/java/ai/devpath/community/config/*.java | head
```

권한 설정 방식이 불명확하면 멈추고 `NEEDS_CONTEXT`로 보고하라 — **인증 없이 열어두지 말 것.**

- [ ] **Step 6: 전체 백엔드 테스트 + 커밋**

```bash
cd D:/workspace/dpa/devpath-community-svc && ./gradlew test
```
Expected: 전체 PASS. 기존 테스트 회귀가 있으면 원인을 규명해 수정한다(임시방편 금지).

```bash
git -C D:/workspace/dpa/devpath-community-svc add src/main/java/ai/devpath/community src/test/java/ai/devpath/community
git -C D:/workspace/dpa/devpath-community-svc commit -m "feat(search): 전체 재색인 배치 + POST /admin/community/reindex"
git -C D:/workspace/dpa/devpath-community-svc push -u origin feat/community-search
```

PR 생성(base `develop`)까지 하되 **머지는 하지 말 것** — 컨트롤러가 CI 확인 후 사용자 승인을 받는다.

---

## Task 6: gitops — ES 배포 매니페스트

**Repo:** `devpath-gitops`

**Files:**
- Create: `apps/devpath-elasticsearch/` 매니페스트 일습

**Interfaces:**
- Consumes: Task 1에서 GHCR에 발행한 nori 이미지
- Produces: k3s에 ES를 띄우는 매니페스트. **이번에는 적용하지 않는다**(AWS 정지).

- [ ] **Step 1: 기존 self-host 앱 매니페스트 구조 확인**

Redis·Ollama가 이미 self-host로 배포돼 있다. 그 구조를 그대로 따른다:

```bash
git -C D:/workspace/dpa/devpath-gitops checkout develop
git -C D:/workspace/dpa/devpath-gitops pull origin develop
git -C D:/workspace/dpa/devpath-gitops checkout -b feat/community-search
ls D:/workspace/dpa/devpath-gitops/apps/devpath-redis/
cat D:/workspace/dpa/devpath-gitops/apps/devpath-redis/*.yaml | head -60
```

- [ ] **Step 2: ES 매니페스트 작성**

`devpath-redis`/`devpath-ollama`와 **동일한 파일 구성·네이밍·라벨 규칙**으로 작성한다. 포함할 것:
- StatefulSet(또는 기존 패턴이 Deployment면 그것) — 이미지 = Task 1의 GHCR nori 이미지, `discovery.type=single-node`, `xpack.security.enabled=false`(내부 전용), `ES_JAVA_OPTS` 힙 제한
- PersistentVolumeClaim — 인덱스 영속
- Service — 클러스터 내부 접근용(`9200`)
- ArgoCD Application 등록이 필요한 구조라면 그것도(기존 앱이 어떻게 등록돼 있는지 확인)

**메모리 주의**: 현재 EC2에 12개 앱이 이미 떠 있다. ES 힙을 512m~1g로 제한하고, 이 값이 인스턴스 여유와 맞는지 **기존 앱들의 리소스 설정을 확인**해 결정하라. 판단이 어려우면 리포트에 남기고 보수적인 값(512m)을 쓴다.

- [ ] **Step 3: community-svc 연결 설정**

`devpath-community-svc` 배포 매니페스트에 ES 접속 주소 환경변수를 추가한다(예: `DEVPATH_SEARCH_ES_URI=http://devpath-elasticsearch:9200`). 실제 설정 키는 **Task 1에서 정한 프로퍼티 이름과 일치**해야 한다.

- [ ] **Step 4: 커밋 + PR (적용 금지)**

```bash
git -C D:/workspace/dpa/devpath-gitops add apps/
git -C D:/workspace/dpa/devpath-gitops commit -m "feat(search): Elasticsearch(nori) 배포 매니페스트 — 적용은 AWS 재가동 시"
git -C D:/workspace/dpa/devpath-gitops push -u origin feat/community-search
```

PR 본문에 **"AWS 정지 상태라 이번에는 적용하지 않음. 재가동 시 ArgoCD 동기화 필요"** 를 명시하라.

---

## Task 7: 프론트 — dp_core 모델 + 데이터 소스 + 목 픽스처

**Repo:** `devpath-frontend`

**Files:**
- Create: `packages/dp_core/lib/src/models/community_search.dart`
- Modify: `packages/dp_core/lib/dp_core.dart`
- Modify: `apps/web/lib/src/features/community/data/community_source.dart`
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart`
- Test: `apps/web/test/features/community/community_search_source_test.dart`

**Interfaces:**
- Consumes: 백엔드 `GET /community/search` 계약(Task 3)
- Produces:
  - `CommunitySearchItem`(freezed) — `CommunityPostSummary`의 필드 + `@Default('') String highlight`
  - `CommunitySearchResult`(freezed) — `items`·`total`·`page`·`size`
  - `communitySearchProvider` — `Future<CommunitySearchResult> Function({required String q, String? board, String? tag, bool? solved, String? sort, int page, int size})`
  Task 8이 소비한다.

- [ ] **Step 1: 브랜치 확인**

`devpath-frontend`는 이미 `feat/community-search` 브랜치에 spec이 커밋돼 있다. 새로 만들지 말고 확인만:

```bash
git -C D:/workspace/dpa/devpath-frontend checkout feat/community-search
git -C D:/workspace/dpa/devpath-frontend status --short
git -C D:/workspace/dpa/devpath-frontend log --oneline -2
```

- [ ] **Step 2: 실패 테스트 작성**

Create `apps/web/test/features/community/community_search_source_test.dart` — 이 레포의 기존 데이터 소스 테스트(`community_source_posts_test.dart`) 스타일을 따르라(dio `HttpClientAdapter` 스텁 방식).

검증 항목:
1. `communitySearchProvider`가 `GET /community/search`를 호출하고 `q`·`board`·`page`·`size` 쿼리를 전달한다
2. 응답 JSON → `CommunitySearchResult`로 파싱된다(`items` 길이·`total`·`page`·`size`)
3. `items[0].highlight`가 파싱된다
4. `highlight`가 응답에 없으면 빈 문자열이 된다(mobile 컴파일 안전 위해 `@Default('')`)

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_search_source_test.dart
```
Expected: FAIL — 모델·provider 없음

- [ ] **Step 4: dp_core 모델 생성**

Create `packages/dp_core/lib/src/models/community_search.dart` — 기존 `community_post.dart`의 freezed 관용구를 그대로 따른다:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'community_search.freezed.dart';
part 'community_search.g.dart';

/// 검색 결과 1건. 목록의 [CommunityPostSummary] 필드에 매칭 하이라이트가 더해진다.
@freezed
abstract class CommunitySearchItem with _$CommunitySearchItem {
  const factory CommunitySearchItem({
    required int id,
    required String title,
    @Default('QNA') String boardType,
    int? authorId,
    @Default(false) bool solved,
    @Default(0) int upvoteCount,
    @Default(0) int replyCount,
    @Default('') String excerpt,
    @Default('') String highlight,
  }) = _CommunitySearchItem;

  factory CommunitySearchItem.fromJson(Map<String, dynamic> json) =>
      _$CommunitySearchItemFromJson(json);
}

/// 검색 응답 envelope. 목록 API 와 달리 총건수·페이지가 있다.
@freezed
abstract class CommunitySearchResult with _$CommunitySearchResult {
  const factory CommunitySearchResult({
    @Default(<CommunitySearchItem>[]) List<CommunitySearchItem> items,
    @Default(0) int total,
    @Default(0) int page,
    @Default(20) int size,
  }) = _CommunitySearchResult;

  factory CommunitySearchResult.fromJson(Map<String, dynamic> json) =>
      _$CommunitySearchResultFromJson(json);
}
```

barrel export 추가 후 코드 생성:

```bash
cd D:/workspace/dpa/devpath-frontend/packages/dp_core && dart run build_runner build --delete-conflicting-outputs
```

생성 파일(`.freezed.dart`·`.g.dart`)은 tracked이므로 **커밋 대상**이다.

- [ ] **Step 5: 데이터 소스 provider 추가**

`community_source.dart`에 기존 `communityListProvider` 바로 아래에 추가한다(같은 관용구):

```dart
typedef CommunitySearchFetch =
    Future<CommunitySearchResult> Function({
      required String q,
      String? board,
      String? tag,
      bool? solved,
      String? sort,
      int page,
      int size,
    });

/// 커뮤니티 검색 `GET /community/search?q=&board=&tag=&solved=&sort=&page=&size=`.
final communitySearchProvider = Provider<CommunitySearchFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required String q,
    String? board,
    String? tag,
    bool? solved,
    String? sort,
    int page = 0,
    int size = 20,
  }) async {
    final json = await client.get<Map<String, dynamic>>(
      '/community/search',
      query: <String, dynamic>{
        'q': q,
        'board': ?board,
        'tag': ?tag,
        'solved': ?solved,
        'sort': ?sort,
        'page': page,
        'size': size,
      },
    );
    return CommunitySearchResult.fromJson(json);
  };
});
```

`?board` 널-어웨어 요소는 이 파일의 기존 관용구다(Dart 3.x). 유지하라.

- [ ] **Step 6: 목 픽스처 추가**

`web_mock_fixtures.dart`에 `GET /community/search` 항목을 추가한다. `MockHttpAdapter`는 쿼리가 있으면 정렬 키를 먼저 찾고 없으면 **base 키로 폴백**하므로 `'GET /community/search'` 하나면 충분하다:

```dart
  // 검색(폴백 키 — q 무관). 하이라이트 포함 2건.
  'GET /community/search': (
    200,
    {
      'items': [
        {
          'id': 1,
          'title': 'async/await가 헷갈려요',
          'boardType': 'QNA',
          'solved': false,
          'upvoteCount': 3,
          'replyCount': 2,
          'excerpt': 'async/await에서 예외는 어디서 잡나요?',
          'highlight': 'async/await에서 <em>예외</em>는 어디서 잡나요?',
        },
        {
          'id': 10,
          'title': '배포 자동화 팁 공유',
          'boardType': 'FREE',
          'solved': false,
          'upvoteCount': 5,
          'replyCount': 1,
          'excerpt': 'GitHub Actions로 배포를 자동화했습니다.',
          'highlight': '',
        },
      ],
      'total': 2,
      'page': 0,
      'size': 20,
    },
  ),
```

- [ ] **Step 7: 테스트 통과 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_search_source_test.dart
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run format
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run analyze
git -C D:/workspace/dpa/devpath-frontend add packages/dp_core apps/web/lib/src/features/community/data apps/web/lib/src/data apps/web/test/features/community
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): 커뮤니티 검색 모델·데이터 소스·목 픽스처"
```

---

## Task 8: 프론트 — 검색바 UI + 결과/빈결과/에러 + `?q=` 라우팅

**Repo:** `devpath-frontend`

**Files:**
- Create: `apps/web/lib/src/features/community/presentation/widgets/community_search_bar.dart`
- Modify: `apps/web/lib/src/features/community/presentation/community_home_page.dart`
- Modify: `apps/web/lib/src/app/router.dart`
- Test: `apps/web/test/features/community/community_search_test.dart`

**Interfaces:**
- Consumes: `communitySearchProvider`·`CommunitySearchResult`·`CommunitySearchItem` (Task 7), 기존 `DpListRow`
- Produces: 커뮤니티 홈의 검색 경험(입력·결과·빈결과·에러·더보기·URL 동기)

- [ ] **Step 1: 현재 커뮤니티 홈 구조 확인**

```bash
cd D:/workspace/dpa/devpath-frontend && sed -n '1,80p' apps/web/lib/src/features/community/presentation/community_home_page.dart
grep -n "community" apps/web/lib/src/app/router.dart
```

기존 `?board=` 동기 방식(`CommunityHomePage(initialBoard:)` + router 쿼리)을 그대로 확장해 `?q=`를 더한다.

- [ ] **Step 2: 실패 테스트 작성**

Create `apps/web/test/features/community/community_search_test.dart`.

검증 항목:
1. **검색어 입력 → 디바운스(400ms) 후 검색 호출** — `communitySearchProvider`를 override해 호출 인자(`q`)를 캡처
2. **결과가 `DpListRow`로 렌더**된다(건수 일치)
3. **검색어를 비우면 기존 목록으로 복귀**한다(검색 provider 미호출, 목록 렌더)
4. **결과 0건이면 "검색 결과 없음" 안내**가 뜬다
5. **검색 실패(예외) 시 에러 카드 + 재시도 버튼**이 뜨고, 빈 결과 문구와 **다른 위젯**이다(key로 구분)
6. **"더 보기" 버튼**: `total`이 `items.length`보다 크면 노출되고, 누르면 `page=1`로 다시 호출한다
7. `total`과 `items.length`가 같으면 더보기 버튼이 **없다**

기존 커뮤니티 테스트(`community_home_page_test.dart` 등)의 host 구성·override 방식을 따르라.

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_search_test.dart
```
Expected: FAIL — 검색바 위젯 없음

- [ ] **Step 4: `CommunitySearchBar` 위젯 구현**

Create `apps/web/lib/src/features/community/presentation/widgets/community_search_bar.dart`:

```dart
import 'dart:async';

import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 커뮤니티 글 검색 입력. 입력이 멎으면(400ms) [onSubmitted] 를 호출한다.
/// 명령 팔레트(Ctrl+K)는 화면 이동용이라 이 위젯과 역할이 다르다.
class CommunitySearchBar extends StatefulWidget {
  const CommunitySearchBar({
    super.key,
    required this.onChangedDebounced,
    this.initialQuery = '',
  });

  final ValueChanged<String> onChangedDebounced;
  final String initialQuery;

  @override
  State<CommunitySearchBar> createState() => _CommunitySearchBarState();
}

class _CommunitySearchBarState extends State<CommunitySearchBar> {
  static const _debounceDelay = Duration(milliseconds: 400);

  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => widget.onChangedDebounced(value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('community-search-field'),
      controller: _controller,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: '글 검색 (제목·본문·태그)',
        prefixIcon: const Icon(DpIcons.search, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _controller.clear();
                  _debounce?.cancel();
                  widget.onChangedDebounced('');
                },
              ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
```

`DpIcons.search`는 **2026-08-01 실측 확인됨**(`packages/dp_design/lib/src/theme/dp_icons.dart:51` = `Symbols.search_rounded`). 그대로 쓴다.

`suffixIcon`이 `_controller.text`에 반응하려면 `setState`가 필요하다 — `_onChanged` 안에서 `setState(() {})`를 호출하거나 `ValueListenableBuilder`로 감싸라. 구현 시 실제 동작을 테스트로 확인할 것.

- [ ] **Step 5: 커뮤니티 홈에 검색 상태 통합**

`community_home_page.dart`에 다음을 더한다:
- 상단에 `CommunitySearchBar` 배치(기존 보드 필터 위)
- 검색어 상태 보유. 비어 있으면 **기존 목록 렌더 경로 그대로**, 값이 있으면 검색 결과 경로
- 검색 결과는 `AsyncValue` 계열로 로딩/데이터/에러를 구분해 렌더:
  - 로딩: 기존 스켈레톤 관용구가 있으면 재사용
  - 데이터 0건: `key: const ValueKey('search-empty')` 안내 위젯
  - 에러: `key: const ValueKey('search-error')` 에러 카드 + 재시도 버튼
  - 데이터: `DpListRow` 목록(기존 `_postRow` 재사용 — `CommunitySearchItem`을 받도록 어댑터 함수 추가)
- `total > items.length`면 목록 하단에 **"더 보기"** 버튼(`key: const ValueKey('search-more')`). 누르면 다음 페이지를 받아 **기존 목록 뒤에 이어붙인다**
- 검색어 변경 시 `?q=`를 URL에 반영(기존 `?board=` 갱신 방식과 동일한 `context.go`/`replace` 관용구 사용)

`_postRow`가 `CommunityPostSummary`를 받는다면, `CommunitySearchItem` → 표시용 변환 함수를 만들어 재사용하라. **`DpListRow`를 새로 만들지 말 것.**

### ⚠️ `highlight` 렌더링 — 보안 계약 (Task 3 리뷰에서 도출, 2026-08-01)

`highlight`는 `<em>` 태그를 포함하므로 그대로 텍스트로 출력하면 태그가 노출된다. 그런데 **더 중요한 제약이 있다**:

**ES 하이라이터는 매칭 토큰만 `<em>`으로 감쌀 뿐, 사용자가 쓴 본문의 `<`·`>`·`&`를 이스케이프하지 않는다.** 즉 어떤 글의 본문에 `<img src=x onerror=alert(1)>`가 들어 있고 그 글이 검색에 걸리면, **그 마크업이 `highlight` 필드에 그대로 담겨 응답으로 온다.**

따라서 **`highlight`를 HTML로 해석해 렌더하는 방식(웹의 `dangerouslySetInnerHTML` 상당)은 금지**한다. 다음 중 하나로 구현하라:

1. **권장 — 태그를 파싱해 `RichText`/`TextSpan`으로 분해**: `<em>`·`</em>`만 화이트리스트로 인식해 강조 스팬을 만들고, **그 사이의 텍스트는 평문으로 취급**한다. 다른 태그 문자열(`<img ...>` 등)은 강조 대상이 아니라 **문자 그대로 표시**된다.
2. **최소 — 모든 태그를 제거하고 평문으로**: `<em>`도 함께 지워 강조 없이 보여준다. 안전하지만 "왜 검색됐는지"가 드러나지 않는다.

**테스트로 고정하라**: `highlight`에 `<img src=x onerror=alert(1)>` 같은 문자열이 섞여 와도 **위젯 트리에 이미지·스크립트가 생기지 않고 문자 그대로 렌더**되는지 검증하는 케이스를 반드시 넣는다. 태그 문자열이 화면에 그대로 나오는 것도 결함이지만, **태그가 실제로 해석되는 것은 취약점**이다.

> Flutter는 HTML을 자동 해석하지 않으므로 웹 브라우저 수준의 XSS로 직결되지는 않는다. 다만 `flutter_html` 같은 패키지를 쓰거나 향후 렌더 방식을 바꿀 때 위험이 현실화되므로, **화이트리스트 파싱을 계약으로 못박는다.**

- [ ] **Step 6: 라우터에 `?q=` 추가**

`router.dart`의 커뮤니티 라우트에서 `state.uri.queryParameters['q']`를 읽어 `CommunityHomePage(initialQuery:)`로 전달한다. 기존 `board` 처리와 같은 자리에 더한다.

- [ ] **Step 7: 테스트 통과 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_search_test.dart
```
Expected: PASS (7개 케이스)

- [ ] **Step 8: 전체 게이트 + 커밋 + PR**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run format
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run analyze
cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run test
```
Expected: 전부 PASS. 기존 커뮤니티 테스트에 회귀가 있으면 원인을 규명해 수정한다.

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): 커뮤니티 검색바·결과·빈결과·에러·더보기 + ?q= 라우팅"
git -C D:/workspace/dpa/devpath-frontend push -u origin feat/community-search
```

PR 생성(base `develop`)까지. **머지 금지** — 백엔드 PR이 먼저 머지되어야 한다.

---

## Task 9: 로컬 통합 스모크 + 문서 갱신

**Repo:** `devpath-community-svc` · `devpath-frontend` · `documents`

**Files:**
- Create: `devpath-frontend/docs/superpowers/reports/2026-08-01-community-search-smoke.md`
- Modify: `documents/04_API_명세서.md` — 검색 API 명세 추가

**Interfaces:**
- Consumes: Task 1~8 전부

- [ ] **Step 1: 로컬 풀스택 기동**

pgvector·ES·Kafka를 띄우고 community-svc를 실행한다. 기존 로컬 레시피를 따른다:

```bash
docker run -d --name dpa-test-pg -e POSTGRES_USER=devpath -e POSTGRES_PASSWORD=localdev -e POSTGRES_DB=devpath -p 5432:5432 pgvector/pgvector:pg16
docker run -d --name dpa-test-es -p 9200:9200 -e discovery.type=single-node -e xpack.security.enabled=false -e ES_JAVA_OPTS="-Xms512m -Xmx512m" devpath-es:local
```

Kafka는 Outbox 릴레이 경로 검증에 필요하다. 로컬 Kafka 기동 방법이 이 레포에 문서화돼 있는지 확인하고, 없으면 단일 노드 Kafka 컨테이너를 띄운다. **Kafka 없이 검증할 경우 재색인 API로 대체**하고 그 사실을 리포트에 명시하라.

- [ ] **Step 2: 색인 → 검색 경로 실측**

1. 글을 몇 건 작성(API 직접 호출 또는 웹 UI)
2. **2초 이상 대기**(Outbox 릴레이 주기) 후 `GET /community/search?q=<키워드>` 호출
3. 결과에 방금 쓴 글이 나오는지 확인
4. 한국어 검색어로도 확인(nori 동작)
5. `POST /admin/community/reindex` 호출 → `{"indexed": N}` 확인
6. **ES를 중지**한 뒤 검색 호출 → **에러 응답**이 오는지, 그리고 **커뮤니티 목록·글쓰기는 여전히 되는지** 확인(핵심 요건)

- [ ] **Step 3: 웹에서 검색 UI 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter run -d chrome --dart-define-from-file=.env.local
```

확인 항목: 한국어 입력·디바운스·결과 렌더·하이라이트 표시(태그 노출 없음)·빈 결과·에러 카드·더보기·URL `?q=` 동기·뒤로가기.

**주의**: 실API 모드로 띄우려면 게이트웨이(`:8080`)와 community-svc가 떠 있어야 한다. 목 모드로 UI만 확인해도 되지만, 그 경우 **실제 검색 경로는 검증되지 않는다**는 점을 리포트에 명시하라.

- [ ] **Step 4: 리포트 작성**

Create `devpath-frontend/docs/superpowers/reports/2026-08-01-community-search-smoke.md`.

포함할 것:
- 채택한 ES 클라이언트·버전, ES 서버 버전, GHCR 이미지 경로
- 로컬 환경 재현 절차(컨테이너 실행 명령 전문)
- Step 2·3의 실측 결과(각 항목 PASS/FAIL + 증거)
- ES 중지 시 동작(검색 에러 / 목록·글쓰기 정상) 확인 결과
- 검증하지 못한 항목과 그 이유(예: k3s 적용, Kafka 미기동 시 대체 검증)

- [ ] **Step 5: API 명세서 갱신**

`documents/04_API_명세서.md`의 커뮤니티 섹션에 두 엔드포인트를 추가한다. 기존 표 형식을 그대로 따르라:

| GET | `/community/search?q=...&board=&tag=&solved=&sort=&page=&size=` | 커뮤니티 글 검색 (ES BM25 + 필터) | LEARNER |
| POST | `/admin/community/reindex` | 커뮤니티 검색 전체 재색인 | ADMIN |

`documents` 레포도 `develop`에서 `docs/community-search-api` 브랜치를 만들어 커밋·PR한다(main 직접 금지).

- [ ] **Step 6: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add docs/superpowers/reports
git -C D:/workspace/dpa/devpath-frontend commit -m "docs(report): 커뮤니티 검색 로컬 스모크 리포트"
git -C D:/workspace/dpa/devpath-frontend push origin feat/community-search
```

---

## Self-Review

**1. spec 커버리지**

| spec 항목 | 담당 Task |
|---|---|
| §3 범위: ES 인프라(매니페스트·nori 이미지·로컬 절차) | Task 1(이미지·로컬) · Task 6(매니페스트) |
| §4 인덱스 스키마 + 부트스트랩 | Task 1 |
| §4.1 Outbox 경유 색인 동기화 | Task 4 |
| §4.1 `PostIndexer`/`PostIndexConsumer` 분리 | Task 2 · Task 4 |
| §4.1 재색인 배치 | Task 5 |
| §4.2 nori 커스텀 이미지를 CI·배포가 공유 | Task 1 Step 3·8 · Task 6 |
| §4.3 인덱스 매핑 | Task 1 Step 6 |
| §5 `GET /community/search` 계약 | Task 3 |
| §5 `POST /admin/community/reindex` | Task 5 |
| §5 ES 장애 → 명시적 에러 | Task 3 Step 6(테스트) · Task 9 Step 2(실측) |
| §6 검색바·`?q=` 동기·DpListRow 재사용·더보기·에러/빈결과 구분 | Task 8 |
| §6 디바운스 400ms | Task 8 Step 4 |
| §7 CI에 ES services | Task 1 Step 8 |
| §7 테스트 범위 전부 | Task 2·3·4·5·7·8 |
| §7 로컬 개발 절차 문서화 | Task 1 Step 3 · Task 9 Step 4 |
| API 명세서 갱신(§10 참조에서 "구현 후 갱신 필요") | Task 9 Step 5 |

누락 없음.

**2. 플레이스홀더 점검**

의도적으로 실측에 맡긴 지점은 다음뿐이며, 모두 **실측 절차와 실패 시 행동(`NEEDS_CONTEXT`)이 명시**돼 있다:
- ES 클라이언트 선택·버전(Task 1 Step 2) — 두 후보와 검증 명령 제시
- ES 클라이언트 질의/인덱스 API 세부(Task 1 Step 4·6, Task 2·3) — "상상 금지, 소스·문서 확인" 명시
- GHCR 발행 경로(Task 1 Step 8) — 기존 워크플로 확인 명령 제시
- `jsonMapper` 실제 메서드명(Task 4 Step 4) — 선례 확인 명령 제시
- ADMIN 권한 적용 방식(Task 5 Step 5) — 확인 명령 + "인증 없이 열지 말 것" 명시
- gitops 리소스 값(Task 6 Step 2) — 기존 앱 확인 + 보수적 기본값 제시

이는 이 프로젝트의 **추측 금지 규칙**의 귀결이며, "TBD"와 달리 다음 행동이 결정돼 있다.

**3. 타입 일관성**

- `PostIndexer.index(long)`·`delete(long)` — Task 2 정의, Task 4·5에서 동일 시그니처 호출
- `QuestionService.summariesByIds(List<Long>)` → `List<PostSummaryView>` — Task 3 Step 1 정의, 같은 Task Step 4에서 사용
- `SearchItemView`/`SearchResponse` 필드 = 프론트 `CommunitySearchItem`/`CommunitySearchResult` 필드와 이름·타입 일치(`items`·`total`·`page`·`size`·`highlight`)
- Kafka 토픽명 `community.post.changed` — Global Constraints·Task 4에서 동일
- 인덱스명 `community_posts` — Global Constraints·Task 1에서 동일
- payload 키 `postId`·`deleted` — Task 4 Step 2(테스트)·Step 4(발행)·Step 6(소비) 전부 동일

**4. 알려진 리스크**

- **ES 클라이언트 API 불확실성**이 Task 1~3에 걸쳐 있다. Task 1 Step 2에서 클라이언트를 확정하지 못하면 이후 Task가 전부 막히므로, **Task 1을 가장 먼저·신중히** 수행해야 한다.
- **GHCR 이미지 발행**이 막히면 CI에서 ES 테스트를 돌릴 수 없다(Task 1 Step 8). 대안(빌드 step 방식)은 별도 결정이 필요하다고 명시했다.
- **k3s 실적용·실서버 검증은 이번 범위 밖**(AWS 정지). Task 6의 매니페스트는 리뷰만 받고 적용하지 않는다.
