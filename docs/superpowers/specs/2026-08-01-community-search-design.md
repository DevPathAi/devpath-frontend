# 커뮤니티 검색 (1단계: Elasticsearch 키워드 검색) — 설계

> 날짜: 2026-08-01 · 범위: 커뮤니티 글 검색 기능 신설(ES 기반 키워드 검색 + 조건 필터 + 프론트 UI) · 성격: 신규 인프라(Elasticsearch) 도입 · 파급 레포: `devpath-community-svc` · `devpath-gitops` · `devpath-frontend`

## 1. 배경 / 목표

커뮤니티에 **검색 기능이 없다**. 사용자가 예전 글을 다시 찾거나 비슷한 주제를 탐색할 방법이 목록 스크롤과 보드/태그 필터뿐이다. `20_커뮤니티_기능_설계서.md` §8.3은 Elasticsearch 기반 검색을 TARGET(미구현)으로 정의해 두었다.

- **완료 정의(1단계)**: 커뮤니티 홈 상단 검색바에 한국어 검색어를 입력하면, 제목·본문·태그에서 매칭된 글이 관련도 순으로 나오고, 보드·태그·해결여부로 좁힐 수 있으며, 매칭 부분이 하이라이트된다. 새로 쓴 글이 검색에 반영된다.

## 2. 현재 상태 (2026-08-01 코드 실측)

- **검색 API 없음**: `CommunityController`(`devpath-community-svc/src/main/java/ai/devpath/community/post/CommunityController.java:84-90`)의 목록은 `GET /community/posts?board=&tag=&sort=` — **검색어 파라미터가 없다**.
- **전문검색 인덱스 전무**: `devpath-shared/src/main/resources/db/migration/V202606251001__community_qna.sql`의 커뮤니티 인덱스는 `board_type/status/created_at`·`author_id/created_at`·`is_solved`·태그 prefix(`text_pattern_ops`)뿐. **GIN/tsvector/pg_trgm 없음**.
- **Elasticsearch 미도입**: `devpath-gitops`에 ES/OpenSearch 매니페스트 없음(배포 앱 13개 = admin·ai·community·gateway·lcs·learning·migration·notification·**ollama**·platform·redis·sandbox·web). `community-svc`에 ES 의존·docker-compose 없음.
- **의미검색 자산은 Q&A에만 존재**: `community_questions.question_embedding`(768차원 pgvector) + `SimilarQuestionMatcher`(`.../seed/SimilarQuestionMatcher.java`, 코사인거리 `<=>`, 임계 0.20). 값은 **ai-svc가 Kafka `CommunitySeedReadyEvent`에 동봉**해 보내고 `CommunitySeedService.updateEmbedding()`이 저장한다. **자유글·피드백 글에는 임베딩이 없다.**
- **community-svc는 임베딩을 스스로 만들 수 있다**: `EmbeddingClient`(`.../seed/EmbeddingClient.java`)가 있고 `/questions/similar`에서 검색어 임베딩을 동기 생성한다. 실패 시 `EmbeddingUnavailableException` → 빈 결과 폴백(`CommunityController:65-77`).
- **Kafka 인프라 사용 중**: `KafkaConfig`(컨슈머 에러 핸들러: 지수백오프 3회)·`CommunitySeedConsumer`·`StreakReachedConsumer` 존재.
- **★이벤트 발행 표준 = Outbox 패턴**: `.../outbox/{OutboxEntry,OutboxRepository,OutboxRelay,OutboxRelayScheduler}.java`. 서비스가 트랜잭션 안에서 `OutboxEntry` 저장 → 스케줄러(`fixedDelay=2000`, `@Profile("!test")`)가 최대 100건씩 Kafka 발행. 실패 시 미발행 유지·다음 주기 재시도. 사용처 = `CollusionDetector`·`BadgeService`.
- **빌드**: Gradle Kotlin DSL(`build.gradle.kts`), **Spring Boot 4**(`spring-boot-starter-webmvc`·`spring-boot-kafka` 등 신규 아티팩트명), JPA + `JdbcTemplate` 혼용, Lombok 사용. ES 관련 의존 **없음**.
- **CI는 GitHub Actions `services:`로 의존 서비스 기동**: `.github/workflows/ci.yml:14-26`이 `pgvector/pgvector:pg17`을 띄운다. **Kafka는 CI에 없다.** Testcontainers 미사용.
- **프론트**: 커뮤니티 홈은 보드 필터(SegmentedButton) + `?board=` URL 동기 + `DpListRow` 목록. `DpCommandPalette`(dp_design)는 **명령·이동 검색** 전용(`commands` 주입)이라 글 검색과 무관. dp_design에 검색 입력 위젯 없음.
- 목록 응답은 **bare 배열**(`GET /community/posts` → `List<PostSummaryView>`, 페이지네이션 없음).

## 3. 범위 / 비범위

이 기능은 **2단계로 분해**한다. 각 단계는 그 자체로 동작하는 소프트웨어를 만든다.

**1단계 = 이 spec의 범위** — ES 키워드 검색 전체
- ES 인프라(gitops 매니페스트 + nori 커스텀 이미지 + 로컬 개발 절차)
- ES 인덱스 스키마 + Kafka 경유 색인 동기화 + **재색인 배치**
- `GET /community/search` (BM25 + 필터 + 페이징 + 하이라이트)
- 커뮤니티 홈 상단 검색바(프론트)

**2단계 = 후속 spec** — 의미검색 결합
- pgvector 임베딩을 **모든 글로 확대**(자유·피드백 포함, 생성 타이밍 결정 + 기존 글 백필)
- 키워드(ES) + 의미(pgvector) 결과를 앱에서 **RRF 융합**

**비범위(1·2단계 공통)**
- **k3s 실제 적용·실서버 스모크** — AWS EC2·RDS 정지 상태라 이번에 검증 불가. 매니페스트는 작성하되 **적용은 AWS 재가동 시로 이월**.
- 답변·댓글 색인(글의 제목·본문·태그만)
- 작성자 필터·기간 필터(UI 진입점 부재, YAGNI)
- 추천순 정렬(목록 화면의 역할)
- 검색어 자동완성·오타 교정·연관검색어
- admin 검색(요구 없음 → 검색바를 dp_design으로 승격하지 않고 `apps/web`에 둔다)

## 4. 아키텍처

> **★2026-08-01 실측 정정 — 글 수정·삭제 기능은 이 코드베이스에 없다.** `QuestionService`·`PostService`·`CommunityController` 어디에도 삭제/수정 메서드·`@DeleteMapping`·`@PatchMapping`·`@PutMapping`이 없다(grep 확인). 따라서 색인 이벤트를 발행하는 지점은 **글 생성 2곳**(`QuestionService.create()` = QNA, `PostService.createPost()` = FREE/FEEDBACK)뿐이다. payload의 `deleted` 플래그와 컨슈머의 삭제 분기는 **향후 삭제 기능이 생길 때를 대비해 구현·테스트해 두는 것**이며, 지금은 발행되지 않는다. 아래 다이어그램의 "수정/삭제"는 미래 경로다.

```
글 작성 (community-svc — 생성 2경로: QNA / FREE·FEEDBACK)
        │  ① 같은 트랜잭션에 DB 저장 + OutboxEntry 저장
        ▼
   community_outbox  ── ② OutboxRelayScheduler(2초 주기)가 Kafka 발행
        │
        ▼
   Kafka: community.post.changed
        │
        ▼
  PostIndexConsumer → PostIndexer  ── ③ ES upsert / delete
        │
        ▼
   Elasticsearch (nori)
        ▲
        │  ④ BM25 + 필터 질의
   GET /community/search  ◄────── 프론트 검색바
```

### 4.1 핵심 결정과 근거

- **이벤트 발행은 기존 Outbox 패턴을 그대로 쓴다**(2026-08-01 실측 정정 — 초안의 `AFTER_COMMIT` 직접 발행보다 견고하고, 이미 이 서비스의 표준이다).
  - 구조: 서비스가 **트랜잭션 안에서** `OutboxEntry`(`aggregateType`·`aggregateId`·`eventType`=Kafka 토픽명·`payload` JSON) 저장 → `OutboxRelayScheduler`(`@Scheduled(fixedDelay=2000)`, `@Profile("!test")`)가 `OutboxRelay.relayOnce()`로 최대 100건씩 발행 후 `publishedAt` 기록. 발행 실패 시 미발행으로 남아 **다음 주기 자동 재시도**.
  - 선례: `CollusionDetector`·`BadgeService`가 동일 방식 사용.
  - 결과: DB 저장과 이벤트가 **원자적**이라 "DB에 없는 글이 색인되는" 역전이 구조적으로 불가능하고, Kafka 장애가 **글쓰기를 막지 않는다**.
  - **대가: 색인 반영이 최대 2초 지연**된다(즉시 아님). 글 작성 직후 곧바로 검색하는 시나리오는 드물어 수용한다.
  - **테스트 함의**: 스케줄러가 `@Profile("!test")`로 꺼져 있어 통합 테스트에서 outbox→Kafka 경로가 자동으로 돌지 않는다. 이는 아래 `PostIndexer` 분리 결정과 맞물려 **의도된 구조**다.
- **ES 장애 시 검색 API는 명시적 에러**를 반환한다(빈 결과 아님). 0건과 장애를 구분하지 않으면 "검색해도 안 나온다"로 오인된다. 커뮤니티 **목록·글쓰기는 ES와 무관하게 계속 동작**한다.
- **재색인 배치를 1단계에 포함**한다. 이벤트 유실·ES 재구축·기존 글 백필이 모두 이 하나로 해결된다. 없으면 한 번 어긋난 색인을 되돌릴 수단이 없다.
  - **트리거 = 관리자 전용 엔드포인트** `POST /admin/community/reindex`(ADMIN 권한). 스케줄러·CLI가 아니라 API인 이유: 운영 중 임의 시점에 필요하고, 기존 admin 경로(`platform-svc`의 `/admin/**` 패턴)와 인증 방식이 같아 추가 인프라가 없다.
  - 동작: `community_posts` 중 `status='PUBLISHED'`를 전량 조회해 ES에 bulk upsert. **처리 건수를 응답**한다. 대량 데이터를 대비한 청크 처리(예: 500건 단위)로 구현하되, 베타 규모에서는 단순 순회로 충분하다.
- **Kafka에서 색인 로직을 분리**한다(§7 검증 참조):
  - `PostIndexer` — ES upsert/delete만 하는 순수 서비스. **ES만 있으면 테스트 가능**
  - `PostIndexConsumer` — Kafka 리스너가 `PostIndexer`를 호출하는 얇은 어댑터
  CI에 Kafka가 없으므로(§2) 이 분리가 없으면 색인 로직을 CI에서 검증할 수 없다.

### 4.2 Elasticsearch 구성

- **8.x self-host**, `analysis-nori`(한국어 형태소) 플러그인. **구체 패치 버전은 구현 시 실측 확정**한다(Spring Boot 4의 ES 클라이언트 호환 버전을 `gradle dependencies`로 확인 후 이미지 태그를 고정). 버전을 추측해 매니페스트에 박지 않는다.
- 공식 이미지에 nori가 없고 GitHub Actions `services:`는 컨테이너 내부에서 임의 명령을 실행할 수 없다 → **nori를 설치한 커스텀 이미지를 GHCR에 발행**하고 **CI와 gitops 배포가 같은 이미지를 사용**한다. 테스트와 운영의 분석기가 동일해진다.
- 라이선스: Elastic License 2.0 basic. 자사 서비스 내부 사용은 허용(관리형 재판매만 금지) → 문제없음.

### 4.3 인덱스 매핑 (`community_posts`)

문서 1건 = 글 1건. `_id` = `community_posts.id`.

| 필드 | 타입 | 비고 |
|---|---|---|
| `title` | `text` (nori) | 가중치 상향 |
| `bodyMd` | `text` (nori) | 하이라이트 대상 |
| `tags` | `keyword[]` | 필터·정확 일치 |
| `boardType` | `keyword` | `FREE`/`FEEDBACK`/`QNA` |
| `status` | `keyword` | `PUBLISHED`만 검색 대상 |
| `authorId` | `keyword` | 색인만(1단계 필터 미노출) |
| `isSolved` | `boolean` | Q&A 해결 여부 |
| `createdAt` | `date` | `latest` 정렬 |

## 5. API 계약

### `GET /community/search`

| 파라미터 | 필수 | 설명 |
|---|---|---|
| `q` | ✅ | 검색어. 빈 값/공백이면 **400** |
| `board` | | `FREE`·`FEEDBACK`·`QNA` |
| `tag` | | 태그명 |
| `solved` | | `true`/`false` |
| `sort` | | `relevance`(기본)·`latest` |
| `page` | | 0부터, 기본 0 |
| `size` | | 기본 20 |

**응답** — 목록 API와 달리 **총 건수가 필요**하므로 envelope:

```json
{
  "items": [
    { "...PostSummaryView 기존 필드...", "highlight": "…<em>Riverpod</em> 상태관리…" }
  ],
  "total": 42,
  "page": 0,
  "size": 20
}
```

- `items` 원소는 **기존 `PostSummaryView`를 재사용**하고 `highlight` 한 필드만 추가한다. 프론트가 이미 `CommunityPostSummary`로 목록을 그리므로 결과 카드를 그대로 쓸 수 있다.
- `highlight`: ES 하이라이트 결과(`<em>` 태그). 본문 매칭이 없으면 기존 `excerpt`를 폴백으로 사용한다.
- **ES 장애 시**: 프로젝트 표준 에러 envelope(스펙 §3.4)로 5xx. 프론트가 이를 에러 카드로 표시한다.
- `PostSummaryView`·검색 응답 record는 community-svc **로컬 타입** → `devpath-shared` 발행 불필요(작업 B 선례).

### `POST /admin/community/reindex` (ADMIN)

전체 재색인(§4.1). 응답: `{ "indexed": 128 }`. 관리자 UI 진입점은 이번 범위 밖이며, 운영자가 직접 호출한다.

## 6. 프론트 (devpath-frontend / apps/web)

- 커뮤니티 홈 상단에 검색바. **`?q=`를 URL에 동기**해 기존 `?board=`와 통일 → 딥링크·뒤로가기 자연 동작.
- 검색어가 있으면 검색 결과, 비우면 기존 목록으로 복귀.
- **결과 카드는 기존 `DpListRow` 재사용**, `highlight`만 다르게 렌더.
- 입력 디바운스 **400ms**(작성 화면 유사질문과 동일 값).
- 페이징 = **"더 보기" 버튼**(무한 스크롤은 스크롤 감지·복원 비용 대비 이득이 적다).
- **ES 장애 → 명시적 에러 카드 + 재시도 버튼**. 빈 결과("검색 결과 없음")와 **시각적으로 구분**한다.
- 검색바 위치 = **`apps/web`**. admin에 검색 요구가 없어 dp_design Layer2 승격은 YAGNI.

## 7. 검증 / 테스트 전략 (TDD, CLAUDE.md 규칙 2)

- **`PostIndexer` + 검색 서비스**: 실제 ES 대상 통합 테스트 — 색인 → 한국어 검색 → 필터(board/tag/solved) → 페이징 → 하이라이트. CI `services:`에 **nori 커스텀 이미지**를 추가한다.
- **`PostIndexConsumer`**: `PostIndexer` 위임 호출만 단위 테스트(Kafka 불필요).
- **재색인 배치**: 전체 재구축 후 건수·내용이 DB와 일치.
- **검색 API**: MockMvc — 빈 `q` → 400, 필터 파라미터 전달, **ES 장애 시 에러 응답**.
- **프론트**: 검색바 입력·디바운스·결과 렌더·**빈 결과와 에러 카드 구분**·더 보기 위젯 테스트 + 목 픽스처.
- **게이트**: 백엔드 `./gradlew test`(CI = postgres + ES services). 프론트 `melos run format` → `analyze` → `test`.
- **로컬 개발**: ES 컨테이너 실행 절차를 리포트/README에 남긴다(pgvector 컨테이너 선례와 동일 방식).

## 8. 결정 기록 (Forks)

- **Fork 1 — 검색 엔진 = Elasticsearch**(사용자 선택). Postgres 하이브리드(pg_trgm+pgvector, 새 인프라 0) 대안을 제시했으나 설계서 §8.3 방향과 한국어 품질(nori)을 우선해 ES 채택. 대가 = 새 인프라 운영·색인 동기화 복잡도.
- **Fork 2 — 도입 범위 = 로컬 구현·검증 + 매니페스트 작성**. AWS 정지 상태라 k3s 적용·실서버 스모크는 이월(비용 미발생).
- **Fork 3 — 벡터 위치 = pgvector 유지**(ES `dense_vector` 미사용). ES에 통합하면 RRF를 ES가 공식 지원하지만 기존 유사질문 자산과 벡터가 중복 저장된다. 대신 **2단계에서 앱이 RRF 융합**을 구현한다.
- **Fork 4 — 색인 동기화 = Kafka 경유, 발행은 기존 Outbox 패턴**(사용자 선택 + 2026-08-01 실측 정정). 동기 색인 대비 재시도·원자성이 낫다. 대가 = 토픽·컨슈머 추가 + **색인 반영 최대 2초 지연**, 로컬 개발에 Kafka 필요 → **§4.1의 `PostIndexer` 분리로 CI 검증 가능성을 확보**.
- **Fork 5 — 색인 대상 = 글만**(답변·댓글 제외). 결과를 글 단위로 묶는 처리와 동기화 대상 증가를 피한다.
- **Fork 6 — 하이라이팅 1단계 포함**. ES 기본 제공이고 "왜 검색됐는지"가 검색 신뢰의 핵심.
- **Fork 7 — ES 장애 = 명시적 에러**(빈 결과 아님). 0건과 장애의 혼동 방지.

## 9. 작업 분해 / 레포 / 브랜치

- **`devpath-community-svc`**: ES 클라이언트 의존·인덱스 매핑·`PostIndexer`·`PostIndexConsumer`·Kafka 토픽 발행·검색 서비스·`GET /community/search`·재색인 배치·CI `services:` ES 추가.
- **`devpath-gitops`**: ES 배포 매니페스트(StatefulSet/PVC/Service) + nori 커스텀 이미지 빌드 정의. **적용은 AWS 재가동 시**.
- **`devpath-frontend`**: dp_core 검색 모델·데이터 소스·검색바·결과/빈결과/에러 UI·`?q=` 라우팅·목 픽스처.
- **브랜치**: 각 레포 `feat/community-search` → 각자 `develop` PR. **백엔드 먼저 머지**(계약 확정) → 프론트.
- 문서(spec/plan)는 `devpath-frontend/docs/superpowers/`에 둔다(작업 A·B·C·D 선례).

## 10. 참조

- 커뮤니티 설계서 §8.3(검색 인덱스, TARGET): `documents/20_커뮤니티_기능_설계서.md`
- API 명세서: `documents/04_API_명세서.md` — 커뮤니티 **글 검색 API는 미정의**(`/community/tags?q=` 태그 자동완성, `/contents/search`는 콘텐츠용). 구현 후 명세서 갱신 필요.
- 기존 의미검색 자산: `devpath-community-svc/src/main/java/ai/devpath/community/seed/{SimilarQuestionMatcher,EmbeddingClient}.java`
- 선행 작업 선례(계약확장 A~D): `docs/superpowers/specs/2026-07-31-*`·`2026-07-31-rich-text-editor-design.md`
