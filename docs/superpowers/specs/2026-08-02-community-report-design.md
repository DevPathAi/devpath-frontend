# 커뮤니티 신고 기능 설계 (2026-08-02)

사용자 신규 요구 4건(②검색 → ③신고 페이지 → ④오류신고 메뉴 → ①디자인) 중 **③게시판 문제/신고 페이지**.
②검색은 2026-08-02 완결([[2026-08-01-community-search-design]]).

## 1. 현황 (실측)

| 위치 | 상태 |
|---|---|
| 웹(학습자) 신고 UI | **없음** |
| admin 신고 처리 화면 | **존재하나 백엔드가 없다** — `GET /admin/reports`·`POST /admin/reports/{id}/resolve` 를 호출하는데 4개 서비스 전부 구현 0건. 목 픽스처로만 도는 껍데기다 |
| community-svc `moderation` 패키지 | **없음**(`abuse` = 투표 담합 탐지만) |
| 마이그레이션 | community-svc 에 `db/migration` **없음** — 전부 `devpath-shared` 중앙 관리 |

설계서 [20_커뮤니티_기능_설계서](https://github.com/DevPathAi/documents/blob/main/20_커뮤니티_기능_설계서.md)는 3-Layer 모더레이션(AI 자동 → 신뢰 사용자 → 관리자)·제재·이의제기까지 그리지만 전부 TARGET이며, **MVP 범위를 "기본 신고 · AI 모더레이션"으로 명시**한다. 이 스펙은 그중 "기본 신고"에 해당한다.

## 2. 범위

**포함**
- 사용자가 **글·답변·댓글**을 신고(카테고리 + 선택 사유)
- 관리자가 신고 목록을 보고 **기각 / 처리완료**로 판정
- 같은 대상 1인 1회 제한, 자기 콘텐츠 신고 금지

**제외(후속)**
- **제재**(경고·쓰기 정지·영구 정지) — platform-svc 계정 상태 연동과 글쓰기 경로 게이팅이 필요해 범위가 배로 커진다
- **콘텐츠 조치**(글 숨김·삭제) — 이번엔 판정 기록만 남긴다. §7 참조
- AI 자동 모더레이션 · 신뢰 사용자 위임 · 이의제기

## 3. 데이터 모델

`devpath-shared` 에 `src/main/resources/db/migration/V202608021001__community_reports.sql` 을 추가한다
(직전 파일이 `V202607291001__community_feedback_and_comments.sql` 이므로 이 번호가 다음이다).

```sql
CREATE TABLE community_reports (
  id            bigserial    PRIMARY KEY,
  reporter_id   bigint       NOT NULL,
  target_type   varchar(16)  NOT NULL,   -- POST | ANSWER | COMMENT
  target_id     bigint       NOT NULL,
  category      varchar(16)  NOT NULL,   -- SPAM|ABUSE|AD|DUPLICATE|INAPPROPRIATE|ETC
  reason        text,                    -- 선택 입력
  status        varchar(16)  NOT NULL DEFAULT 'OPEN',  -- OPEN | RESOLVED | REJECTED
  reviewed_by   bigint,
  reviewed_at   timestamptz,
  created_at    timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT uq_report_once UNIQUE (reporter_id, target_type, target_id)
);
CREATE INDEX idx_reports_status_created ON community_reports (status, created_at DESC);
```

**결정 근거**

- `reporter_id`는 **논리 참조**다. 교차 서비스 FK를 두지 않는 이 프로젝트의 기존 관례를 따른다(`community_posts.author_id`와 동일).
- `UNIQUE (reporter_id, target_type, target_id)` — 1인 1회. 이 제약이 있어야 **"몇 명이 신고했는가"가 심각도 신호**가 된다. 무제한 허용이면 신고 건수가 의미를 잃는다.
- **`REJECTED`를 `RESOLVED`와 분리**한다. 이번 범위가 "판정 기록"뿐이므로, 관리자가 내린 두 갈래 판단이 구분돼 남아야 나중에 조치·제재를 붙일 때 이력이 쓸모를 가진다. 단일 `RESOLVED`로 뭉치면 그 정보가 영원히 사라진다.
- 인덱스는 관리자 목록의 기본 질의(`status='OPEN'` + 최신순)에 맞춘다.

## 4. 백엔드 — `ai.devpath.community.report` (community-svc)

| 클래스 | 역할 |
|---|---|
| `CommunityReport`(엔티티) · `CommunityReportRepository` | 영속 |
| `ReportService` | 접수(검증 포함) · 관리자 조회 · 판정 |
| `ReportController` | `POST /community/reports` |
| `AdminReportController` | `GET /community/admin/reports` · `POST /community/admin/reports/{id}/resolve` |
| dto: `ReportRequest`·`ReportCreatedView`·`AdminReportView`·`AdminReportResponse`·`ResolveRequest` | |

### 4.1 ★관리자 경로가 `/community/admin/**` 인 이유

게이트웨이(`devpath-gateway/src/main/resources/application.yml`)의 `platform-auth` 라우트가 `Path=…,/admin/**,…`로 **`/admin/**`를 선점**해 platform-svc(8081)로 보낸다. community-svc 에는 Ingress도 없다. 따라서 `/admin/reports`로 두면 **어떤 클라이언트도 도달할 수 없다**.

같은 함정을 검색 작업에서 겪었고(재색인 API가 호출 불가 상태로 CI green이었다), `/community/admin/reindex`로 옮겨 해결했다. 이 스펙도 같은 패턴을 따른다 — 게이트웨이 무변경, 라우트 선언 순서 비의존.

> **되돌리지 말 것.** "일관성" 명목으로 `/admin/reports`로 옮기면 조용히 404가 된다.

### 4.2 접수 검증은 요청 시점에 한다

`target_type`에 따라 `community_posts` / `community_answers` / `community_comments`를 조회해:

1. 대상이 없으면 **404**
2. 대상 작성자 == 신고자면 **400**
3. `targetType`·`category`가 enum 밖이면 **400**
4. UNIQUE 위반이면 **409**

미루면 관리자 목록에 유령 신고(삭제된 대상, 자기 신고)가 쌓여 목록 자체를 신뢰할 수 없게 된다.

> **주의**: 이 레포는 `DataIntegrityViolationException`을 트랜잭션 경계 **바깥**에서 흡수해야 한다(rollback-only 트랩 — 광고 기능에서 겪은 이력). 409 처리 시 이 패턴을 따를 것.

### 4.3 관리자 목록은 단일 쿼리로 조립한다

신고와 대상 콘텐츠가 같은 DB에 있으므로 `target_type`별 조회로 제목·발췌·작성자를 붙인다. 이것이 백엔드를 community-svc 에 둔 이유의 실현이다 — platform-svc 에 뒀다면 목록 1페이지마다 교차 서비스 호출이 필요하고, community 장애가 신고 목록까지 끌고 내려간다.

`reportCount`(같은 대상 총 신고 수)를 함께 집계한다.

## 5. API 계약

### 5.1 `POST /community/reports` (LEARNER)

```json
{ "targetType": "POST", "targetId": 1, "category": "SPAM", "reason": "광고글입니다" }
→ 201 { "id": 5, "status": "OPEN" }
```

`reason`은 선택(null 허용), **최대 500자**(초과 시 400). 오류는 §4.2 표대로이며 프로젝트 표준 에러 envelope(스펙 §3.4 중첩 구조)를 따른다.

**카테고리 enum ↔ UI 라벨** (설계서 §신고의 6종)

| enum | 라벨 |
|---|---|
| `SPAM` | 스팸 |
| `ABUSE` | 욕설 |
| `AD` | 광고 |
| `DUPLICATE` | 중복 |
| `INAPPROPRIATE` | 부적절 |
| `ETC` | 기타 |

### 5.2 `GET /community/admin/reports?status=OPEN&page=0&size=20` (ADMIN)

`status` 생략 시 전체. 검색 API와 같은 envelope 형태를 쓴다.

```json
{
  "items": [{
    "id": 5,
    "targetType": "POST", "targetId": 1,
    "targetTitle": "async/await가 헷갈려요",
    "targetExcerpt": "async/await에서 예외는 …",
    "targetAuthorId": 7,
    "targetPath": "/community/1",
    "reporterId": 3,
    "category": "SPAM", "reason": "광고글입니다",
    "reportCount": 3,
    "status": "OPEN",
    "createdAt": "2026-08-02T10:00:00Z"
  }],
  "total": 12, "page": 0, "size": 20
}
```

- `targetPath` — 프론트가 경로 조립 규칙을 중복 구현하지 않도록 **서버가 준다**. QNA 글은 `/community/{id}`, FREE·FEEDBACK 글은 `/community/post/{id}`. 답변은 `CommunityAnswer.questionId`, 댓글은 `CommunityComment.postId` 로 부모를 찾아 그 경로를 준다(두 컬럼 모두 실재 확인).
- `reportCount` 는 **status 와 무관한 해당 대상의 총 신고 수**다. 이미 처리된 신고도 포함해야 "이 글이 그동안 몇 번 신고됐는가"를 볼 수 있다.
- 대상이 이미 사라진 신고는 `targetTitle`·`targetPath` 가 null 이 될 수 있다(접수 시 검증하지만 이후 삭제될 수 있다). 프론트는 "삭제된 콘텐츠"로 표시하고 이동 링크를 비활성화한다.
- `size` 상한 **100 클램프**(검색 API와 동일 규칙).

### 5.3 `POST /community/admin/reports/{id}/resolve` (ADMIN)

```json
{ "action": "RESOLVE" }   // RESOLVE | REJECT
→ 200 { "id": 5, "status": "RESOLVED" }
```

`reviewed_by`(JWT sub)·`reviewed_at`을 기록한다. 이미 처리된 신고를 다시 처리하면 **409**.

## 6. 프론트

### 6.1 web — 신고 다이얼로그

`apps/web/lib/src/features/community/presentation/widgets/report_dialog.dart`.
`dp_design`이 아니라 web 에 둔다 — 커뮤니티 도메인 위젯이다(`DpRichEditor`와 같은 판단).

- 글 상세(`qna_detail_page`·`post_detail_page`)의 제목 옆, 답변·댓글 각 항목에 `⋮` 메뉴(`MenuAnchor`, admin 행 메뉴와 동일 관용구)
- 메뉴 → 다이얼로그: 카테고리 라디오 6종 + 상세 설명(선택, `TextField`) + [취소] [신고]
- 결과: 201 → 스낵바 "신고가 접수됐어요" / 409 → "이미 신고한 글이에요" / **400(자기 콘텐츠) → "본인 글은 신고할 수 없어요"** / 그 외 → 표준 에러 메시지
- **목록에는 달지 않는다** — 신고하려면 내용을 봐야 한다

#### ★자기 콘텐츠 판별 — QNA 질문만 예외다 (실측)

| 대상 | 상세 응답에 작성자 id | 처리 |
|---|---|---|
| 일반글(FREE·FEEDBACK) | `CommunityPostDetail.authorId` **있음** | 자기 글이면 **메뉴 미노출** |
| 답변 | `CommunityAnswer.authorId` **있음** | 자기 답변이면 **메뉴 미노출** |
| 댓글 | `CommunityComment.authorId` **있음** | 자기 댓글이면 **메뉴 미노출** |
| **QNA 질문** | `CommunityQuestionDetail` 에 **없다** | **메뉴를 노출**하고 400 을 "본인 글은 신고할 수 없어요"로 안내 |

`QuestionDetailView`에 작성자 id 가 없는 것은 기존 계약이다(모델 주석에 명시돼 있다). 이번 범위에서 계약을 넓히지 않고, 그 한 경우만 서버 응답으로 처리한다. 서버 검증(§4.2)이 최종 방어선이므로 UI 미노출은 어디까지나 편의다.

> 비교 시 타입에 주의한다. `User.id` 는 **`String`**, 백엔드 `authorId` 는 **정수**다. 문자열로 맞춰 비교할 것.

`dp_core`에 `CommunityReportCategory` enum과 요청·응답 모델을 둔다(mobile 컴파일 안전을 위해 freezed `@Default` 관용구 유지).

### 6.2 admin — 기존 화면 개편

현재 `apps/admin/lib/src/features/reports/`는 **경로도 모델도 실제 계약과 맞지 않는다**(`Report.id`가 `String`, 필드 5개, body 없는 resolve). 개편 범위:

- `data/report.dart` — `AdminReport`로 필드 확장(§5.2 전 필드), `id`는 `int`
- `application/reports_controller.dart` — 경로를 `/community/admin/reports`로, `resolve(id, action)` 시그니처
- `presentation/reports_page.dart` — 대상 제목·카테고리·**신고 수 배지**·이동 링크, **[기각] [처리완료]** 두 버튼, `status` 필터(SegmentedButton), 페이징
- 목 픽스처 갱신

## 7. 이번 범위가 남기는 것 — 조치 수단 부재

관리자는 판정만 할 수 있고 **문제 글을 내릴 수단이 없다**. community-svc 에 글 수정·삭제 기능 자체가 없기 때문이다(검색 작업에서 grep 확인).

완화책으로 목록에 **대상 이동 링크**를 둬 수동 대응 경로를 남긴다. 근본 해결은 후속이며, 그때 **`status`를 비-PUBLISHED로 바꾸는 방식**을 권한다 — 검색의 `PostIndexer`가 비-PUBLISHED 글을 색인에서 자동 제거하므로 숨김과 검색 정합성이 함께 해결된다(단, 숨김 경로에서 색인 이벤트 발행을 추가해야 한다. 현재 발행 지점은 생성 2곳뿐).

## 8. 테스트

**백엔드**(실제 postgres)
- 접수 5: 정상 201 · 중복 409 · 자기 콘텐츠 400 · 대상 없음 404 · enum 밖 400
- 목록 4: 대상 정보 조립 · `reportCount` 집계 · `status` 필터 · 페이징(`size` 클램프)
- 판정 4: RESOLVE · REJECT(`reviewed_by`/`reviewed_at` 기록 확인) · 재처리 409 · 권한 403/401

> 권한 테스트는 **nimbus 실제 서명 JWT**로 쓴다. 이 레포 컨트롤러 테스트의 `.with(jwt())` 후처리기는 authority 를 직접 주입해 `SecurityConfig`의 `role` → `ROLE_*` 변환기를 **우회**하므로 권한을 검증하지 못한다(검색 작업 실측).
>
> 건수 단언은 **생성 전 스냅샷 + 델타**(`before + N`)로 쓴다. 이 레포 테스트는 트랜잭션 롤백 없이 실 데이터를 적재해 절대 건수가 성립하지 않는다.

**web**: 다이얼로그 렌더·카테고리 선택·제출 페이로드·409 안내·자기 콘텐츠 메뉴 미노출
**admin**: 목록 렌더·신고 수 표시·기각/처리 호출·status 필터·빈 상태

## 9. 실행 순서와 의존

| # | 레포 | 작업 |
|---|---|---|
| 1 | **devpath-shared** | 마이그레이션 → PR → 머지 → **수동 발행** |
| 2 | community-svc | 엔티티·리포지토리·접수 API |
| 3 | community-svc | 관리자 목록·판정 API |
| 4 | devpath-frontend | dp_core 모델 + web 신고 다이얼로그·⋮ 메뉴 |
| 5 | devpath-frontend | admin 화면 개편 |
| 6 | documents | `04_API_명세서` 갱신 |

### ⚠️ shared 가 임계 경로다

**1이 끝나기 전에는 community-svc 테스트조차 돌지 않는다** — 테이블이 없기 때문이다. community-svc 는 `flyway.enabled=false`(운영)·`ddl-auto=validate`이고, 테스트 프로파일의 flyway 는 **shared jar 안의** `db/migration`을 읽는다.

발행은 자동이 아니다. main push 에만 워크플로가 도므로 develop 머지 후 **수동 발행**해야 한다:

```bash
gh workflow run publish.yml --ref develop -R DevPathAi/devpath-shared
```

발행 후 community-svc 에서 의존을 새로 받아 테이블 생성을 확인한 뒤 2를 시작한다.

## 10. 비범위

- 제재·이의제기·AI 모더레이션·신뢰 사용자 위임(설계서 §7)
- 신고자에게 처리 결과 알림(notification-svc 연동)
- 신고 통계·대시보드
- ④ 각 페이지 오류 신고 메뉴 — **별개 기능**이다. 이쪽은 서비스 오류 제보라 대상이 콘텐츠가 아니며 저장소·화면이 다르다. 다음 순서로 별도 스펙을 쓴다.
