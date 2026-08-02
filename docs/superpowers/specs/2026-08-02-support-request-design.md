# ④ 오류 신고·문의 (Support Request) — 설계

> 작성 2026-08-02 · brainstorming 결과 · 후속 = writing-plans

사용자가 어느 페이지에서든 서비스 오류나 문의를 접수하고, 관리자가 admin 콘솔에서 처리 상태를 관리한다.

## 1. 배경과 위치

이 기능은 신규 발명이 아니라 **기획에 있으나 미구현인 항목**이다.

- `documents/06_화면_기능_정의서:798` — 서버 500 시 `[다시 시도] [문의하기]` + trace_id 클립보드 복사
- `documents/15_사용자_메뉴얼 §13` — "문의: 대시보드 → 지원"
- `documents/33_개인정보_처리방침 §15-2` — "서비스 내: 설정 > 고객지원"

③ 커뮤니티 신고(`community_reports`)와는 **별개 기능이다.** 대상이 콘텐츠가 아니라 서비스 자체이므로 그 스키마를 재사용할 수 없다:

| `community_reports` 요소 | ④에서 맞지 않는 이유 |
|---|---|
| `target_type CHECK IN ('POST','ANSWER','COMMENT')` | 오류 제보에 대상 콘텐츠가 없다 |
| `UNIQUE (reporter_id, target_type, target_id)` | 같은 사용자가 서로 다른 오류를 여러 번 낸다 |
| `category CHECK IN ('SPAM','ABUSE',...)` | 콘텐츠 위반 유형이라 오류와 무관하다 |

## 2. 확정된 요구사항

| 항목 | 결정 |
|---|---|
| 성격 | 오류 제보 + 일반 문의 **통합 창구**(유형으로 구분) |
| 소유 서비스 | **platform-svc** — 서비스 전역 관심사, `/admin/**`가 이미 여기로 라우팅됨 |
| 진입점 | ① 앱셸 상시 버튼 ② 오류 화면의 `[문의하기]` |
| 자동 수집 | 경로·환경·발생 시각 + **최근 API 실패 (응답 본문 일부 포함)** |
| 관리자 | 목록 + 상세 + 상태 전이 + 내부 메모 (사용자 답변은 제외) |
| 인증 | **로그인 필수** |
| 저장 구조 | 클라 링버퍼 수집 + 서버 **정규화 자식 테이블** |

### 범위 밖 (후속 백로그)

- 자동 오류 리포팅(사용자 개입 없이 전송) — 볼륨·노이즈·레이트리밋 설비가 선행되어야 한다
- 관리자 답변을 사용자가 확인하는 흐름(notification-svc 연동)
- 스크린샷 첨부
- 비로그인 접수 — 게이트웨이 미인증 라우트 + IP 레이트리밋이 필요하다(현재 레이트리밋 설비 없음)

> **알려진 한계**: 로그인 필수이므로 **로그인 자체가 실패하는 오류는 이 경로로 제보할 수 없다.** 이메일 안내로 대체한다.

## 3. 데이터 모델

**devpath-shared 마이그레이션 1개.** platform-svc는 `flyway.enabled: false`이고 마이그레이션은 shared 중앙 관리다.

> ⚠️ **임계 경로**: shared PR 머지 후 `gh workflow run publish.yml --ref develop -R DevPathAi/devpath-shared`로 **수동 발행**하기 전에는 platform-svc 테스트가 돌지 않는다. 발행 후 `flyway_schema_history`에 새 버전이 `success=t`로 찍히는지 확인할 것.

```sql
-- V202608021002__support_requests.sql
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
  trace_id     VARCHAR(64),               -- 에러 화면에서 진입한 경우
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

CREATE INDEX idx_support_requests_status_created
  ON support_requests (status, created_at DESC);

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

### 설계 근거

- **1인 1회 UNIQUE 없음** — ③에서는 "몇 명이 신고했는가"가 심각도 신호였지만, 여기서는 각 제보가 독립 사건이다.
- **실제 FK + ON DELETE CASCADE** — ③은 다형 참조라 FK를 걸 수 없었으나 여기는 단일 부모다.
- **`WONTFIX`를 `RESOLVED`와 분리** — ③에서 `REJECTED`를 분리한 것과 같은 이유. "고쳤다"와 "안 고치기로 했다"는 이력으로서 값이 다르다.
- **`status_code` NULL 허용** — 네트워크 단절·타임아웃은 상태코드가 없다. 이 구분 자체가 진단 정보다.
- **`seq` UNIQUE** — 실패 목록의 순서가 데이터로 보존되어야 재현 순서를 읽을 수 있다.

## 4. API 계약

접수 경로는 신규이므로 **게이트웨이 `predicates`에 `/support/**` 추가가 필요**하다(`devpath-gateway/src/main/resources/application.yml:12`, `platform-auth` 라우트). 관리자 경로는 `/admin/**`가 이미 platform-svc로 가므로 추가 작업이 없다.

> ③에서 `/admin/community/reindex`가 게이트웨이 선점 때문에 호출 불가였던 문제가 여기서는 반대로 유리하게 작용한다.

권한은 `platform-svc/config/SecurityConfig.java`가 이미 갖춘 배선을 그대로 쓴다: `/admin/**` = `hasRole("ADMIN")`, 그 외 = `authenticated()`. `adminRoleConverter`(`role` 클레임 → `ROLE_*`)도 이미 존재한다(community-svc엔 없어서 ③에서 별도 작업이 필요했다).

### 4.1 `POST /support/requests` — 접수

인증 필요. 201 Created.

```jsonc
// 요청
{
  "type": "ERROR",                    // ERROR | INQUIRY
  "title": "학습 경로 화면이 빈 채로 멈춰요",
  "body": "생성 버튼을 누르면 진행률이 40%에서 멈춥니다.",
  "context": {
    "pagePath": "/path",
    "appVersion": "0.1.0+42",
    "userAgent": "Mozilla/5.0 ...",
    "viewport": "1920x1080",
    "traceId": null,
    "errorCode": "PATH_GENERATION_FAILED",
    "occurredAt": "2026-08-02T10:11:12Z",
    "failures": [
      {
        "method": "POST",
        "path": "/learning-paths",
        "statusCode": 500,
        "errorCode": "INTERNAL_ERROR",
        "traceId": null,
        "message": "일시적 오류 — 잠시 후 다시 시도해 주세요",
        "occurredAt": "2026-08-02T10:11:09Z"
      }
    ]
  }
}

// 응답 201
{ "id": 42 }
```

**검증**

| 필드 | 규칙 | 위반 시 |
|---|---|---|
| `type` | `ERROR` \| `INQUIRY` | 400 `INVALID_ARGUMENT` |
| `title` | 1–200자, 공백만이면 거부 | 400 |
| `body` | 1–5000자, 공백만이면 거부 | 400 |
| `context.failures` | 최대 10건. 초과분은 **거부하지 않고 앞 10건만 저장** | — |
| 그 외 `context` 필드 | 전부 선택. 컬럼 길이 초과 시 **절단** | — |

> `failures` 초과와 길이 초과를 400이 아니라 절단으로 처리하는 이유: 제보는 사용자가 이미 문제를 겪은 뒤의 마지막 행동이다. 부가 정보의 형식 문제로 제보 자체를 거절하면 안 된다. **본문(`title`·`body`)만 엄격 검증**한다.

`reporter_id`는 요청 본문이 아니라 **JWT `sub`에서 취한다.**

### 4.2 `GET /admin/support-requests` — 목록

`hasRole("ADMIN")`. 쿼리: `status` · `type` · `cursor` · `limit`(기본 20, 최대 100).

응답은 dp_core `Page` 계약(`AdminUserController`와 동일):

```jsonc
{
  "data": [
    { "id": 42, "type": "ERROR", "title": "...", "status": "OPEN",
      "pagePath": "/path", "reporterId": 7, "failureCount": 3,
      "createdAt": "2026-08-02T10:11:12Z" }
  ],
  "nextCursor": "42",
  "limit": 20
}
```

keyset 페이지네이션. `nextCursor`는 꽉 찬 페이지일 때만 마지막 행 id, 아니면 null.

### 4.3 `GET /admin/support-requests/{id}` — 상세

목록 필드 전체 + `body` · 수집 컨텍스트 전체 + `failures[]`(seq 오름차순) + `adminNote` · `handledBy` · `handledAt`. 없는 id는 404.

### 4.4 `POST /admin/support-requests/{id}/status` — 상태 전이

③의 `POST /community/admin/reports/{id}/resolve`와 형태를 맞춘다.

```jsonc
// 요청
{ "status": "IN_PROGRESS", "adminNote": "재현 확인함" }
// 응답 200 — 갱신된 상세
```

- `status`는 4종 중 하나. 그 외는 400.
- `adminNote`는 선택. 주어지면 **덮어쓴다**(누적 이력이 아니다 — 이력이 필요해지면 별도 테이블이 맞다).
- `handled_by` = JWT `sub`, `handled_at` = now(). 상태를 `OPEN`으로 되돌리면 둘 다 NULL로 초기화한다.

## 5. 클라이언트 수집

### 5.1 인터셉터 위치 — 배선 순서가 정확도를 좌우한다

`apps/web/lib/src/providers/api_providers.dart`의 현재 체인은 `[OnboardingGate, Auth, ErrorNormalizer]`다(각각 `insert(0, ...)`로 쌓임).

**`ApiFailureRecorder`를 index 0에 넣으면 안 된다.** `AuthInterceptor`가 refresh로 자동 복구하는 일시적 401까지 기록되어, 사용자가 겪지도 않은 실패가 제보에 섞인다.

**`Auth` 뒤 · `ErrorNormalizer` 앞**에 삽입한다:

```dart
client.dio.interceptors.insert(client.dio.interceptors.length - 1, recorder);
```

근거 — `ApiClient.create`는 에러 정규화 인터셉터를 **마지막에** 추가하고 `handler.reject()`로 끝낸다(`dp_core/lib/src/api/api_client.dart:28-39`). dio 5.9.2에서 `reject`는 `InterceptorResultType.reject`로 체인을 종료하므로(`interceptor.dart:180`), 그 **뒤에 등록된 인터셉터는 에러를 볼 수 없다.**

recorder는 `handler.next(e)`로 반드시 통과시켜 기존 에러 흐름을 바꾸지 않는다.

> ⚠️ `length - 1`은 "정규화 인터셉터가 마지막"이라는 불변식에 의존한다. 이 불변식을 깨는 변경이 조용히 통과하지 않도록, **정규화 인터셉터가 체인의 마지막임을 단언하는 테스트**를 dp_core에 둔다.

### 5.2 링버퍼

`dp_core`에 `ApiFailureLog` — `ListQueue`, 최대 10건, 메모리 전용, 앱 재시작 시 소멸.

**기록 시점에 이미 마스킹된 값만 담는다.** 버퍼에 원문을 두지 않으면 이후 어떤 경로로도 원문이 새지 않는다.

건당: `method` · `path`(쿼리스트링 제거) · `statusCode` · `errorCode` · `traceId` · `message`(마스킹 후 500자 절단) · `occurredAt`.

**recorder는 절대 예외를 던지지 않는다.** 기록 중 어떤 오류가 나도 삼키고 원래 에러를 통과시킨다 — 진단 기능이 진단 대상을 망가뜨리면 안 된다.

### 5.3 환경 정보 수집 위치

`dp_core`는 순수 Dart라 브라우저 API를 쓸 수 없다. 수집기는 `apps/web`에 둔다(`SupportContextCollector`) — 이 레포에 이미 있는 `*_web.dart` 조건부 임포트 패턴(`oauth_launcher_web.dart` 등)을 따른다.

| 항목 | 출처 |
|---|---|
| `pagePath` | `GoRouterState.of(context).uri.path` — `.path`를 쓰므로 쿼리스트링이 구조적으로 빠진다 |
| `viewport` | `MediaQuery.sizeOf(context)` |
| `userAgent` | `package:web`의 `window.navigator.userAgent` (web 전용 파일) |
| `appVersion` | **`AppConfig`에 `APP_VERSION` dart-define 신규 추가** (현재 없음, 기본값 `"dev"`) |
| `traceId`·`errorCode` | 에러 화면에서 진입한 경우 `ApiException`에서 전달 |

> `traceId`는 현재 서버가 항상 null을 보낸다(`devpath-shared/.../ApiExceptionHandler.java:84` — 분산 트레이싱 미도입). **배관은 만들되 값은 대개 비어 있다.** 트레이싱 도입 시 코드 변경 없이 채워진다.

### 5.4 목 모드

`apps/web`의 기본값은 `USE_MOCK=true`다. `web_mock_fixtures`에 `POST /support/requests` 픽스처를 추가하지 않으면 목 모드에서 제보가 실패한다. **픽스처 추가는 범위에 포함한다.**

## 6. 마스킹 (Sanitize)

### 6.1 위치 — 클라 + 서버 2중

- **클라**: `dp_core`의 `SensitiveTextMasker`(순수 Dart) — 링버퍼 기록 시점에 적용
- **서버**: platform-svc의 동일 규칙 Java 구현 — 수신 시 `message`·`body`·`page_path`에 재적용

서버 단독이면 원문이 네트워크와 서버 접근 로그를 지나고, 클라 단독이면 조작된 클라이언트가 원문을 밀어넣을 수 있다.

**이 설계의 약점은 두 구현이 어긋날 수 있다는 것이다.** 완화책으로 §6.3 케이스 표를 스펙에 못박고 **양쪽 테스트가 같은 표를 그대로 쓴다**(같은 입력 → 같은 기대 출력).

### 6.2 규칙 — PIA §"민감 패턴"을 따름

`documents/23_개인정보_영향평가_PIA.md`가 이미 목록을 정해뒀다: 이메일 · 전화번호 · 주민등록번호 · 카드번호 · API 키/인증 토큰 · 비밀번호 · IP 주소 · 홈 디렉토리 경로 · DB 접속 문자열.

**적용 순서를 고정한다**(결과가 결정적이어야 양쪽 구현이 일치한다):

| # | 패턴 | 정규식 | 치환 |
|---|---|---|---|
| 1 | 키=값 형태 비밀 | `(api[_-]?key\|authorization\|password\|secret\|token)\s*[:=]\s*(Bearer\s+)?[^\s,;]+` | `<키>=[REDACTED]` |
| 2 | JWT (키 없이 노출된 것) | `eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*` | `[TOKEN]` |
| 3 | DB 접속 문자열 | `(jdbc:\|postgresql://\|postgres://\|mysql://\|redis://)\S+` | `[DSN]` |
| 4 | 이메일 | `[\w.+-]+@[\w-]+\.[\w.-]+` | `[EMAIL]` |
| 5 | 카드번호 | `\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}` | `[CARD]` |
| 6 | 주민등록번호 | `\d{6}-?[1-4]\d{6}` | `[RRN]` |
| 7 | 휴대전화 | `01[016789]-?\d{3,4}-?\d{4}` | `[PHONE]` |
| 8 | 윈도 홈 경로 | `[A-Za-z]:\\Users\\[^\\\s]+` | `[PATH]` |
| 9 | POSIX 홈 경로 | `/(home\|Users)/[^/\s]+` | `[PATH]` |
| 10 | IPv4 | `\b\d{1,3}(\.\d{1,3}){3}\b` | `[IP]` |

**순서 근거 — 이 순서가 아니면 결과가 틀린다:**

- **규칙 1이 규칙 2보다 먼저다.** 반대로 두면 `Authorization: Bearer eyJ...`에서 JWT가 먼저 `[TOKEN]`으로 바뀌고, 이어서 규칙 1이 `Authorization: Bearer`만 잡아 **`Authorization=[REDACTED] [TOKEN]`**이라는 어중간한 결과가 남는다. 규칙 1의 값 패턴에 `(Bearer\s+)?`를 넣은 것도 같은 이유다 — 헤더 값은 `Bearer <토큰>` 두 토큰이라 `\S+` 하나로는 토큰 본체가 남는다.
- **규칙 3(DSN)이 이메일·IP보다 먼저다.** 접속 문자열을 통째로 지워야 그 안의 호스트·계정이 부분 치환 흔적을 남기지 않는다.
- **카드(16자리)가 주민등록번호(13자리)보다 먼저다.** 구분자 없는 16자리 숫자에 RRN 패턴을 먼저 적용하면 중간 13자리가 매칭되어 카드번호를 조각내 버린다(예: `1234567890123456` → 5번째 자리부터 `5678901234567`이 RRN으로 잡힌다). 반대 순서에는 이 충돌이 없다 — 13자리·구분자 포함 RRN은 카드 패턴에 매칭되지 않는다.
- **IPv4가 마지막이다.** 앞 규칙들이 치환을 끝낸 뒤에 남은 것만 보게 해 오탐을 줄인다.

임의의 숫자열에서 카드·RRN·전화 패턴이 겹칠 여지는 남아 있다. 이 순서를 고정하는 목적은 **오탐을 0으로 만드는 것이 아니라 두 언어 구현이 같은 결과를 내게 하는 것**이다.

> ⚠️ **크로스 언어 함정**: Dart `RegExp`는 **인라인 플래그 `(?i)`를 지원하지 않는다.** 규칙 2의 대소문자 무시는 정규식 안이 아니라 각 언어 API로 준다 — Dart는 `RegExp(pattern, caseSensitive: false)`, Java는 `Pattern.CASE_INSENSITIVE`. **패턴 문자열에 `(?i)`를 쓰지 않는다.** lookbehind도 쓰지 않는다.

마스킹 후 `message`는 **500자로 절단**한다(절단이 마스킹보다 뒤여야 잘린 토큰 조각이 남지 않는다).

### 6.3 공유 케이스 표 — 양쪽 테스트가 이 표를 그대로 쓴다

| # | 입력 | 기대 출력 |
|---|---|---|
| 1 | `연락처는 hong@example.com 입니다` | `연락처는 [EMAIL] 입니다` |
| 2 | `Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc` | `Authorization=[REDACTED]` |
| 3 | `token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc 만료` | `token [TOKEN] 만료` |
| 4 | `연결 실패 jdbc:postgresql://db:5432/devpath?user=x` | `연결 실패 [DSN]` |
| 5 | `주민번호 900101-1234567 조회` | `주민번호 [RRN] 조회` |
| 6 | `카드 1234-5678-9012-3456 승인` | `카드 [CARD] 승인` |
| 7 | `전화 010-1234-5678 로 연락` | `전화 [PHONE] 로 연락` |
| 8 | `파일 C:\Users\deepe\project\a.txt 없음` | `파일 [PATH]\project\a.txt 없음` |
| 9 | `경로 /home/ubuntu/app/x.log 실패` | `경로 [PATH]/app/x.log 실패` |
| 10 | `서버 10.0.1.23 응답 없음` | `서버 [IP] 응답 없음` |
| 11 | `정상 메시지입니다` | `정상 메시지입니다` (무변경) |
| 12 | `` (빈 문자열) | `` (무변경) |

> 케이스 8·9는 **홈 디렉토리까지만** 지우고 그 아래 경로는 남긴다 — 사용자명이 개인정보이고, 하위 경로는 진단에 필요하다.

> ✅ **이 표는 실측으로 검증했다.** §6.2의 규칙과 순서를 그대로 구현해 12케이스를 돌려 **12/12 통과**를 확인했다(2026-08-02, 스펙 작성 중 PROBE). 첫 초안은 규칙 1·2의 순서가 반대여서 케이스 2가 `Authorization=[REDACTED] [TOKEN]`으로 깨졌고, 그 실측이 순서를 뒤집었다.
>
> 단, 검증은 PCRE 계열로 했다. **Dart `RegExp`·Java `Pattern`에서 같은 결과가 나오는지는 각 언어 테스트가 다시 확인해야 한다** — 그것이 §9의 케이스 표 파라미터화 테스트가 존재하는 이유다.

**케이스 2와 3의 차이가 규칙 1·2의 경계를 정의한다.** 케이스 2는 `Authorization:` 뒤에 값이 오므로 규칙 1이 `Bearer` 포함 전체를 지운다. 케이스 3은 `token` 뒤에 `:`·`=`가 없어 규칙 1이 매칭되지 않고, 규칙 2가 JWT 본체만 지운다. 두 케이스를 모두 테스트에 넣어야 이 경계가 구현에서 지켜진다.

## 7. UI

### 7.1 진입점 ① — 앱셸 상시 버튼

`apps/web/lib/src/features/shell/presentation/app_shell.dart:70`의 `trailing` 슬롯은 **이미 명령 팔레트 버튼이 점유**하고 있고 `DpAppShell.trailing`은 단일 위젯이다. 두 버튼을 `Row(mainAxisSize: MainAxisSize.min, ...)`으로 묶어 전달한다 — **`DpAppShell` 자체는 손대지 않는다.**

툴팁 "오류 신고·문의". 셸 안의 모든 라우트에 자동으로 따라붙는다.

### 7.2 진입점 ② — 오류 화면의 `[문의하기]`

`DpStateScaffold`는 주석부터 "단일 1차 행동"으로 못박혀 있어(`packages/dp_design/lib/src/states/dp_state_scaffold.dart:6`) 보조 버튼 자리가 없다.

`secondaryActionLabel` · `onSecondaryAction`을 **선택 파라미터(기본 null)로 추가**하고 `DpError`가 `onReport`를 노출한다. 기본값이 null이라 기존 호출부(`DpEmpty` · `DpQuota` · `DpSandboxUnavailable` 등)는 전부 무변경이다.

이렇게 하면 `DpError`를 쓰는 모든 화면이 한 번에 `[문의하기]`를 얻는다 — `06_화면_기능_정의서:798`이 요구한 조합이 성립한다.

### 7.3 제보 다이얼로그

③의 `report_dialog.dart` 패턴을 따르되 내용이 다르다.

구성: 유형 선택(오류/문의) → 제목 → 내용 → **"함께 보낼 정보" 접이식 미리보기**.

미리보기는 선택이 아니라 **고지**다. 무엇이 전송되는지 사용자가 열어 볼 수 있어야 한다(PIA가 LCS에서 요구한 투명성과 같은 기준). **마스킹된 값을 그대로** 보여주므로 사용자가 "여기 이메일이 남아 있다"를 발견할 수 있다.

**조용한 비활성 버튼을 만들지 않는다**(2026-07-27 동의화면 사고의 교훈) — 제목·내용이 비면 버튼을 죽이는 대신 검증 메시지를 띄운다.

제출 성공 시 스낵바로 접수 번호를 알린다.

### 7.4 admin 화면

`apps/admin/lib/src/features/reports/`의 구조(`application`/`data`/`presentation`/`state`)를 그대로 복제해 `support/`를 만든다.

- 목록: `DpDataTable` + 상태·유형 필터
- 상세: 수집 컨텍스트 전체 + 실패 목록 표(seq 순) + 상태 전이 + 내부 메모

**낱말 충돌을 미리 피한다**(③에서 "처리완료"가 필터와 버튼에 겹쳐 두 뜻으로 쓰였다):

| 위치 | 표현 |
|---|---|
| 상태 필터(명사) | 접수됨 · 처리중 · 처리됨 · 보류 |
| 전이 버튼(동사) | 처리 시작 · 처리 완료 · 보류로 표시 · 다시 열기 |

## 8. 에러 처리

- **접수 실패를 삼키지 않는다** — 다이얼로그 안에서 에러를 보여주고 **사용자가 쓴 내용을 유지한 채** 재시도할 수 있게 한다. 제보 기능이 실패했을 때 사용자가 쓴 글을 날리면 그게 두 번째 사고다.
- recorder는 예외를 던지지 않는다(§5.2).
- 서버 검증 실패는 shared 표준 envelope 400(`IllegalArgumentException` → `INVALID_ARGUMENT`).
- 목록/상세 조회 실패는 admin에서 `DpError` + 재시도.

## 9. 테스트 전략

### 백엔드 (platform-svc)

- **권한 테스트는 `jwt()` 후처리기가 아니라 nimbus로 실제 HS256 서명 JWT를 만들어 검증한다.** (③ 교훈: 후처리기는 authority를 직접 주입해 `adminRoleConverter`를 우회하므로 권한 검증이 무의미해진다.) `role` 클레임 없는 토큰 → 403, `role=ADMIN` → 200을 각각 단언한다.
- 접수 API: 유효 요청 201 + 저장 검증 / `type` 이상값 400 / `title`·`body` 공백 400 / `failures` 11건 → 10건만 저장 / `reporter_id`가 JWT `sub`에서 오는지(본문의 다른 값이 무시되는지).
- 상태 전이: 4종 전이 + 이상값 400 + `handled_by`·`handled_at` 기록 + `OPEN` 복귀 시 NULL 초기화.
- 마스킹: §6.3 케이스 표 파라미터화 테스트.
- **건수 단언은 델타로**(③ 교훈: 롤백 없는 테스트에서 `before = count()` 스냅샷 후 `before + N`).
- platform-svc는 `hikari.maximum-pool-size: 4`가 이미 걸려 있다(`src/test/resources/application-test.yml`) — ③에서 겪은 `too many clients` 붕괴는 여기서 재발하지 않는다.

### 프론트

- `ApiFailureRecorder` 단위: 실패가 버퍼에 쌓이는지 / 11건째에 가장 오래된 것이 밀려나는지 / **refresh로 복구된 401이 기록되지 않는지**(체인 순서 회귀 방지 — 이 테스트가 §5.1의 핵심 근거를 지킨다) / 기록 중 예외가 원래 에러 흐름을 바꾸지 않는지.
- **정규화 인터셉터가 체인의 마지막임을 단언하는 테스트**(§5.1 불변식 보호).
- `SensitiveTextMasker`: §6.3 케이스 표 — 백엔드와 **동일 입력·동일 기대**.
- 다이얼로그 위젯: 유형 전환 / 빈 입력 시 검증 메시지 노출(비활성 아님) / 미리보기 펼침 / 접수 실패 시 입력 보존.
- `DpError` 위젯: `onReport` 없으면 보조 버튼 미노출(기존 호출부 무회귀), 있으면 노출.
- admin: 목록 필터 / 상세 실패 표 / 상태 전이 호출.

### 계약 문서

`documents/04_API_명세서`에 **§8.1.3 오류 신고·문의**로 추가한다(§8.1.2가 ③ 커뮤니티 신고).

## 10. 작업 순서 (레포 의존)

```
devpath-shared (마이그레이션)
      └─→ [수동 발행: gh workflow run publish.yml --ref develop]
            └─→ devpath-platform-svc (API)
                  ├─→ devpath-gateway (/support/** 라우트)
                  └─→ devpath-frontend (dp_core → dp_design → web → admin)
                        └─→ documents (§8.1.3)
```

shared 발행이 임계 경로다 — ③과 동일한 구조이므로 첫 Task로 배치한다.

## 11. 검증 방법

- 각 레포 테스트 스위트 통과(`./gradlew test` · `melos run test`)
- 로컬 통합 스모크: pg 컨테이너 + platform-svc + gateway 기동 후 접수 → admin 목록 → 상태 전이 실측
- ⚠️ Git Bash에서 한글 JSON을 `-d`로 넘기면 CP949로 깨진다 — UTF-8 파일 + `--data-binary @file`을 쓸 것
