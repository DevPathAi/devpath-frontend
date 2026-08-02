# 커뮤니티 검색 1단계 — 로컬 통합 스모크 리포트 (2026-08-02)

플랜 `docs/superpowers/plans/2026-08-01-community-search.md` **Task 9**의 실측 기록이다.
대상은 머지된 3개 PR: community-svc **#32**(`8246eb2`) · gitops **#56**(`759259e`) · frontend **#98**(`1a7d3a8`).

## 0. 한눈에

| 검증 항목 | 결과 |
|---|---|
| Outbox → Kafka → 컨슈머 → ES 색인 (실제 경로) | ✅ PASS |
| 한국어 형태소 검색(nori) — 조사 분리 포함 | ✅ PASS |
| 보드 필터 (`QNA`/`FREE`/`ALL`) | ✅ PASS |
| 하이라이트(`<em>`) 응답 | ✅ PASS |
| 재색인 API + ADMIN 권한(403/401/200) | ✅ PASS |
| **ES 장애 시 검색만 실패, 목록·글쓰기 정상** (spec 핵심 요건) | ✅ PASS |
| ES 장애 중 색인 이벤트 유실 → 복구 | ✅ PASS (Kafka 자동 재시도 + 재색인 양쪽) |
| 웹 UI 브라우저 E2E | ⬜ **미실시**(§5 사유) |

발견 사항 3건은 §4에 있다. 그중 **1건은 이번 작업 범위 밖의 기존 결함**이다.

---

## 1. 확정 스택 (실측)

| 항목 | 값 |
|---|---|
| ES 서버 | **9.2.8** + `analysis-nori`(플러그인 목록 실측: `analysis-nori 9.2.8`) |
| ES 클라이언트 | `co.elastic.clients:elasticsearch-java:9.2.8` (Spring Boot 4.0.7이 관리) |
| 설정 키 | `spring.elasticsearch.uris` (환경변수 `ES_URIS`) |
| 인덱스 | 운영 `community_posts` / 테스트 `community_posts_it` |
| Kafka 토픽 | `community.post.changed`, payload `{"postId":N,"deleted":bool}` |
| 이미지 | `docker/elasticsearch/Dockerfile`(공식 이미지 + nori). CI는 **매 실행 직접 빌드**, k3s는 GHCR 이미지 |

> spec/plan 초안의 "ES 8.x"는 오류였다. Spring Boot 4 세대는 Elastic 9.x를 가져온다.

## 2. 로컬 환경 재현 절차

```bash
# 1) Postgres (pgvector)
docker run -d --name dpa-test-pg -e POSTGRES_USER=devpath -e POSTGRES_PASSWORD=localdev \
  -e POSTGRES_DB=devpath -p 5432:5432 pgvector/pgvector:pg16
docker exec dpa-test-pg createdb -U devpath -O devpath devpath_citest

# 2) Elasticsearch + nori
cd D:/workspace/dpa/devpath-community-svc
docker build -t devpath-es:local docker/elasticsearch
docker run -d --name dpa-test-es -p 9200:9200 -e discovery.type=single-node \
  -e xpack.security.enabled=false -e ES_JAVA_OPTS="-Xms512m -Xmx512m" devpath-es:local
curl -s http://localhost:9200/_cat/plugins        # analysis-nori 확인

# 3) Kafka (KRaft 단일 노드) — Outbox 릴레이 경로 검증에 필요
docker run -d --name dpa-test-kafka -p 9092:9092 \
  -e KAFKA_NODE_ID=1 -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 \
  -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
  -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
  -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \
  -e KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0 \
  apache/kafka:3.9.1

# 4) community-svc
#    운영 프로파일은 flyway.enabled=false + ddl-auto=validate 다(스키마는 shared 중앙 마이그레이션 담당).
#    로컬에서는 테스트 프로파일이 이미 마이그레이션해 둔 devpath_citest 를 그대로 쓴다.
DB_URL="jdbc:postgresql://localhost:5432/devpath_citest" ./gradlew bootRun
```

### 스모크용 JWT 생성 (openssl만 사용)

```bash
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
SECRET='test-secret-please-change-min-32-bytes-long-0123456789'   # application.yml 기본값
mktoken() {
  local role="$1" sub="${2:-1}" h p s
  h=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | b64url)
  p=$(printf '%s' "{\"sub\":\"$sub\",\"role\":\"$role\",\"exp\":9999999999}" | b64url)
  s=$(printf '%s' "$h.$p" | openssl dgst -sha256 -hmac "$SECRET" -binary | b64url)
  printf '%s.%s.%s' "$h" "$p" "$s"
}
LEARNER=$(mktoken LEARNER); ADMIN=$(mktoken ADMIN)
```

> ⚠️ **한국어 본문은 반드시 UTF-8 파일로 보낼 것.** Git Bash에서 `-d '{"title":"한글..."}'`로 직접 넘기면
> CP949로 인코딩돼 `JSON parse error: Invalid UTF-8 start byte 0xbd`가 난다(도구 문제, 앱 결함 아님).
> `--data-binary @body.json` 방식을 쓴다.

---

## 3. 실측 결과

### 3.1 색인 → 검색 (실제 Outbox → Kafka 경로)

글 2건 작성(QNA `79`, FREE `80`) 후 검색어 `SMOKE1`로 폴링:

```
색인 반영 확인: 0초 경과, total=3
```

Outbox 릴레이가 2초 주기이므로 **최대 2초 지연**이 계약인데, 실측은 첫 폴링에서 이미 반영됐다.
Kafka 컨슈머가 `community.post.changed-0` 파티션을 할당받아 소비하는 것도 로그로 확인했다.

### 3.2 한국어 검색 (nori) · 필터

| 질의 | 결과 | 판정 |
|---|---|---|
| `q=리액트` | `total=1, id=79` | ✅ |
| `q=자동화` | `total=1, id=80` | ✅ |
| **`q=상태관리는`** (조사 포함) | `total=1, id=79` | ✅ **형태소 분석 실동작 증거** |
| `q=Riverpod` (영문) | `total=1, id=79` | ✅ |
| `q=리액트&board=QNA` | `total=1, id=79` | ✅ |
| `q=리액트&board=FREE` | `total=0` | ✅ 필터 정확 |
| **`q=리액트&board=ALL`** | `total=1, id=79` | ✅ **Task 3 리뷰에서 고친 무필터 처리** |

본문에 `상태관리는`이 아니라 `상태관리는 Riverpod이`로 들어 있는데 조사가 분리돼 매칭됐다 —
표준 애널라이저였다면 실패했을 케이스라 **nori가 실제로 동작함을 보여주는 유일한 결정적 증거**다.

하이라이트 응답 예:
```json
"highlight":"스모크식별자 <em>SMOKE</em><em>1</em>"
```

### 3.3 재색인 API + 권한

경로는 **`POST /community/admin/reindex`**다(`/admin/community/reindex` 아님 — §4.1 참조).

| 요청 | 결과 | 판정 |
|---|---|---|
| LEARNER 토큰 | `403` | ✅ |
| 무토큰 | `401` | ✅ |
| ADMIN 토큰 | `200 {"indexed":63}` | ✅ |
| 구 경로 `/admin/community/reindex` (ADMIN) | `404` | ✅ 이전됨 |

서버 로그(Task 5 리뷰 M-1 반영 확인):
```
ReindexService : 전체 재색인 시작
ReindexService : 재색인 진행 indexed=64 lastId=81
ReindexService : 전체 재색인 완료 indexed=64
```

### 3.4 ★ES 장애 시 동작 (spec 핵심 요건)

`docker stop dpa-test-es` 상태에서:

| 요청 | 결과 | 판정 |
|---|---|---|
| `GET /community/search?q=Riverpod` | **500** (빈 결과 아님) | ✅ 명시적 에러 |
| `GET /community/posts` (목록) | `200` | ✅ |
| `POST /community/posts` (글쓰기) | `201` | ✅ |
| `GET /community/posts/{id}` (상세) | `200` | ✅ |

서버 로그: `Resolved [java.io.UncheckedIOException: ES 검색 실패 q=Riverpod]` — 예외를 삼키지 않고 전파.

### 3.5 ★색인 이벤트 유실 → 복구

ES 중지 중 글 `81`을 작성했다. 그동안 Kafka 컨슈머 로그:

```
Seeking to offset 30 for partition community.post.changed-0
Record in retry and not yet recovered
```

**이벤트가 유실되지 않고 Kafka가 자동 재시도하고 있었다.** `PostIndexer`가 ES 예외를 삼키지 않고
던지도록 설계한 것(호출자가 재시도를 결정)이 실제로 작동한 증거다.

ES 재기동 후 재색인(`indexed:64`)까지 수행한 결과, 글 `81`이 인덱스에 존재하고(`_doc/81` → `found:true`)
검색 결과에도 포함됐다. **재시도와 재색인 두 경로 모두 복구 수단으로 유효**하다.

---

## 4. 발견 사항

### 4.1 (해소됨) 재색인 엔드포인트가 게이트웨이를 통과하지 못했다

플랜이 지정한 `POST /admin/community/reindex`는 **호출할 수단이 없는 경로**였다.
게이트웨이 `platform-auth` 라우트가 `/admin/**`를 선점해 platform-svc(8081)로 보내고,
community-svc에는 Ingress도 없다.

→ community-svc #32 리뷰에서 발견해 **`/community/admin/reindex`로 이전**했다(`c238103`).
기존 `/community/**` 라우트에 얹히므로 게이트웨이 변경도, 라우트 선언 순서 의존도 없다.
**로컬 테스트(MockMvc)와 CI로는 절대 드러나지 않는 종류의 결함**이었다 — 게이트웨이를 거치지 않기 때문이다.

### 4.2 (범위 밖·기존 결함) 잘못된 요청 본문이 400이 아니라 500으로 나간다

깨진 인코딩으로 JSON을 보냈을 때:

```
Resolved [org.springframework.http.converter.HttpMessageNotReadableException: JSON parse error: ...]
→ HTTP 500 {"error":{"code":"INTERNAL_ERROR",...}}
```

클라이언트 잘못(400)인데 서버 오류(500)로 응답한다. `devpath-shared`의 `ApiExceptionHandler`가
framework 예외를 개별 매핑하지 않고 500으로 흡수하기 때문이다.

**이번 검색 작업이 만든 결함이 아니다** — 메모리에 기록된 "shared 하드닝(ResponseStatusException/
framework 예외 500 삼킴)" 백로그의 실제 사례다. 영향: ① 클라이언트가 재시도 여부를 잘못 판단
② 500 알람이 오염돼 진짜 서버 장애와 구분되지 않는다. **shared 후속 작업으로 이월.**

### 4.3 (관찰) nori가 영숫자 혼합 토큰을 쪼개 무관한 글이 매칭된다

`SMOKE1` 검색 시 하이라이트가 `<em>SMOKE</em><em>1</em>`로 분리됐고, 본문에 `1`이 들어간
무관한 글(`JPA N+1`)이 결과에 섞였다(`total=3`).

nori가 `SMOKE1`을 `SMOKE` + `1`로 분해하기 때문이다. 한국어 형태소 분석기의 정상 동작이지만,
**식별자·버전 문자열(`v1.2`, `ES9`, 에러코드) 검색 품질에는 불리**하다.

베타 규모에서는 수용 가능하나, 개선하려면 `nori_tokenizer`의 `decompound_mode` 조정 또는
`title`/`bodyMd`에 `keyword` 서브필드를 두고 `multi_match`에 얹는 방법이 있다. **백로그.**

---

## 5. 검증하지 못한 것

| 항목 | 사유 |
|---|---|
| **웹 UI 브라우저 E2E** | 실API 모드로 검색 화면을 보려면 게이트웨이 + platform-svc(로그인) + web까지 전체 기동이 필요하다. 이번에는 백엔드 계약을 직접 실측하고, 프론트는 **위젯 테스트 15건**(디바운스·결과·빈결과·에러·더보기·`?q=` 딥링크·XSS 렌더)으로 대체했다. **목 모드 UI 흐름은 확인되지만 실제 검색 경로는 이 리포트의 API 실측으로만 검증됐다.** |
| **k3s 실적용** | AWS(EC2·RDS) 정지 상태. gitops #56은 매니페스트만 머지했고 ApplicationSet `targetRevision: main`이라 develop 머지로는 배포되지 않는다. 재가동 후 `develop → main` 릴리스 시 ArgoCD가 동기화한다. |
| **다중 노드 ES** | 단일 노드 전제(인덱스 yellow, `PostIndexBootstrap` TOCTOU). 운영 규모 확대 시 재검토. |
| **글 수정·삭제 색인** | 이 레포에 수정·삭제 기능 자체가 없다. 발행 지점은 생성 2곳뿐이며 `deleted` 플래그·컨슈머 삭제 분기는 미래 대비다. |

## 6. 후속 백로그

- **shared 에러 핸들러 하드닝** — framework 예외(400류)가 500으로 나가는 문제(§4.2)
- **고아 문서 정리** — 재색인은 단방향 upsert라 ES에만 남은 문서를 지우지 못한다. 모더레이션·신고로 글을 내리는 기능이 붙으면 alias 스왑 재색인으로 전환 필요
- **비동기 재색인** — 현재 동기 응답. 규모가 커져 LB 타임아웃을 넘기면 202 + 잡 상태로
- **검색 품질** — 영숫자 토큰 분리(§4.3), 정렬 파라미터 오타 시 조용한 relevance 폴백
- **2단계(의미검색)** — 전 글 임베딩 확대 + RRF 하이브리드 융합(별도 spec)
