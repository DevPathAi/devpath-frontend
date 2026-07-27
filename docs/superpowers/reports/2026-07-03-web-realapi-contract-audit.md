# 웹 골든패스 실API 계약 감사 (2026-07-03)

> 조각 1a Task 2 산출물. 프론트 `apps/web`(브랜치 `docs/web-golden-realapi-spec`) ↔ 백엔드 각 svc `origin/develop`(2026-07-03 ff 정렬: gateway `c8a1282`·platform `56bf8a6`·learning `aaf65a4`·ai `6150a1a`·sandbox `fa67bed`·community `15f0996`·lcs `fffed7f`·shared `ce9fa4f`) 소스 대조. 모든 gap은 file:line 근거. 추측 없음.

## 요약 — 티어 재확정

| 티어 | 화면 | 상태 |
|---|---|---|
| **T1** 정합 성숙 | auth · community · lcs | 경로·요청·직렬화 규약 **전부 일치**. 응답 View DTO 필드 스팟체크만 남음(조각 1b). |
| **T2** HTTP·목검증 | content · dashboard · review | 경로 게이트웨이 일치. 응답 DTO 필드 대조 필요(후속 조각 2). |
| **T3** SSE·라우트 gap | 온보딩 · path · sandbox · mentor | **온보딩 라우트 불일치(확정 gap)** + SSE 와이어 계약 미확정(후속 조각 3). |

**직렬화 규약(전 화면 공통 축)**: 백엔드는 전역 naming strategy가 아니라 **DTO별 명시**다. auth/assessment 계열은 `@JsonProperty("snake_case")`(예: `LoginResponse.java:16` `access_token`, `RefreshRequest.java:10` `refresh_token`, `ClaimRequest.java:5` `guest_assessment_id`), community/lcs 계열은 `@JsonProperty` 없이 **camelCase 기본**. 프론트가 이 규약을 화면별로 정확히 따르고 있어(auth=snake 파싱, community/lcs=camel body) 대량 드리프트는 없음.

## 게이트웨이 라우트 (origin `c8a1282`, `application.yml`)

| route | uri | Path |
|---|---|---|
| platform-auth | :8081 | `/oauth2/**`,`/login/**`,`/auth/**`,`/users/**` |
| learning | :8082 | `/onboarding/assessments/**`,`/learning-paths/**`,`/dashboard/**`,`/contents/**` |
| sandbox | :8085 | `/sandbox/**` |
| ai-review | :8084 | `/reviews/**`,`/ai-mentor/**` |
| community | :8086 | `/community/**` |
| notification | :8088 | `/notifications/**` |
| lcs | :8087 | `/lcs/**` |

## 화면별 gap 매트릭스

### T1-1. 인증 (auth) — ✅ 정합
| 항목 | 프론트 | 백엔드 | 판정 |
|---|---|---|---|
| refresh | `auth_controller.dart:42,63` `POST /auth/refresh`, 파싱 `data['access_token']` | `AuthController.java:63` `POST /refresh`, `LoginResponse.java:16` `@JsonProperty("access_token")` | ✅ |
| 쿠키 | `api_providers.dart:25` `withCredentials=true`; refresh는 body 없이 POST(쿠키) | `AuthController.java:84-86` 웹=HttpOnly 쿠키·`refresh_token=null`(`@JsonInclude(NON_NULL)`) | ✅ |
| 로그인 | `login_page.dart:68-72` 실서버=`login()` OAuth 리다이렉트 | `/oauth2/**`(Spring Security OAuth2, AuthController 밖) | ⚠️ OAuth 리다이렉트 로컬 검증 복잡도(R4) |

### T1-2. 커뮤니티 (community) — ✅ 정합
| 경로(프론트 `community_source.dart`) | 백엔드 `CommunityController.java` | 판정 |
|---|---|---|
| `GET /community/posts?board=&tag=&sort=` (75) | `GET /posts` `@RequestParam board,tag,sort` (79-84) | ✅ |
| `GET /community/questions/{id}` (86) | `GET /questions/{id}` (74) | ✅ |
| `POST /community/questions {title,bodyMd,tags}` (100) | `POST /questions` `CreateQuestionRequest` (41) | ✅ 경로·body camel |
| `POST /community/questions/{id}/answers {bodyMd}` (111) | `POST /questions/{id}/answers` (47) | ✅ |
| `POST /community/answers/{id}/accept` (122) | `POST /answers/{id}/accept` (54) | ✅ |
| `POST /community/{posts\|answers}/{id}/vote {value}` (133) | `POST /posts\|answers/{id}/vote` `VoteRequest.value()` (87,94) | ✅ |
| `GET /community/questions/similar?q=` (143) | `GET /questions/similar` `@RequestParam q` (60) | ✅ |
| `GET /community/tags?q=` (154) | `GET /tags` `@RequestParam q` (101) | ✅ |
- 잔여(조각 1b 스팟): 응답 View 필드(`PostSummaryView`·`QuestionDetailView`·`AnswerView`·`TagView`·`SimilarQuestionView`) fromJson 키 대조.

### T1-3. LCS — ✅ 정합
| 경로(프론트 `lcs_source.dart`) | 백엔드 `LcsController.java` | 판정 |
|---|---|---|
| `POST /lcs/snapshots/draft {purpose,contentId?,requestedFields}` (33) | `POST /snapshots/draft` `DraftRequest` (26) | ✅ |
| `POST /lcs/snapshots/{draftId}/commit {attachedToType,attachedToId,visibility}` (52) | `POST /snapshots/{draftId}/commit` `CommitRequest` (32) | ✅ |
| `GET /lcs/snapshots/by-question/{questionId}` (68), 404→null (73) | `GET /snapshots/by-question/{questionId}` (44) | ✅ 404 처리 확인(조각 1b) |
- 잔여: `DraftResponse`·`CommitResponse`(`snapshotId`)·`SnapshotView` 필드 대조.

### T2-4. 콘텐츠 (content)
| 항목 | 프론트 | 게이트웨이 | 판정 |
|---|---|---|---|
| 조회 | `content_controller.dart:18` `GET /contents/{idOrSlug}` | learning `/contents/**` | ✅ 경로 / DTO 대조 필요 |
| 진척 | `content_controller.dart:34` `POST /contents/{id}/progress` | learning `/contents/**` | ✅ 경로 / 응답 대조 필요 |

### T2-5. 대시보드 (dashboard)
| 항목 | 프론트 | 게이트웨이 | 판정 |
|---|---|---|---|
| 요약 | `dashboard_controller.dart:16` `GET /dashboard` | learning `/dashboard/**` | ✅ 경로 / `DashboardSummary` DTO 대조 필요 |

### T2-6. AI 리뷰 (review) — ✅ 조각 2 정합 완료
| 항목 | 프론트 | 실서버(ai-svc `ReviewController`) | 판정 |
|---|---|---|---|
| 폴링 | `GET /reviews?sandboxSessionId={id}` → `pollForSession`(자동: `RunDone.sandboxSessionId` 트리거) | `@GetMapping(params="sandboxSessionId")` | ✅ 경로·query·DTO(`CodeReview{id,status,confidence,strengths,improvements,security}`)·`status`(PENDING/DONE/FAILED) 일치 |
| 조회 | (웹 미사용) | `GET /reviews/{id}` | — |
| 피드백 | `ReviewPanel` thumbUp/Down 버튼 **미배선**(onPressed no-op) | `POST /reviews/{id}/feedback` {UP\|DOWN} | ⚠️ 프론트 배선 후속(golden path 밖) |
- **해소 2건(조각 2)**:
  1. **동기 생성 없음**: 실 ai-svc엔 `POST /reviews`(동기 생성)가 없다 — 리뷰는 샌드박스 실행 시 Kafka로 비동기 생성되고 웹은 세션으로 폴링. deprecated `request()`/`POST /reviews` 배선(및 목 픽스처)을 제거하고, 수동 요청/재시도는 실행이 만든 `sandboxSessionId` **재폴링**(세션 없으면 "먼저 코드를 실행하세요" 안내)으로 정합.
  2. **미생성 시 맨 404**: 실 `ReviewNotFoundException`은 Spring 기본 404(중첩 `error.code` 없음)를 반환 → 프론트 폴링이 `resourceNotFound` 코드뿐 아니라 **`status==404`도 미생성 신호**로 취급하도록 정합(비동기 생성 지연 중 폴링 지속, 소진 시에만 타임아웃 실패). mock의 `{error:{code:RESOURCE_NOT_FOUND}}` 중첩 envelope가 이 gap을 가리고 있었음.
- **후속(별도 슬라이스)**: ai-svc `GlobalExceptionHandler`가 내는 에러 body가 프론트 `ApiException` envelope(`{error:{code,message}}`)와 계통적으로 불일치(예: killswitch `{errorCode}` 최상위, forbidden/notfound는 문자열/기본형). learning/community-svc도 동일 패턴 — **에러 envelope 표준화는 review 스코프 밖의 크로스레포 과제**(R-err).

### T3-7. 온보딩 (onboarding) — ⚠️ 라우트 gap 확정
| 항목 | 프론트 | 게이트웨이 | 판정 |
|---|---|---|---|
| 제출 | `onboarding_controller.dart:19` `POST /onboarding` | learning 라우트는 `/onboarding/assessments/**`만 — **단독 `/onboarding` 미매칭** | ❌ **gap** |
- 목 픽스처엔 `POST /onboarding`(`web_mock_fixtures.dart:26`)과 `POST /onboarding/assessments/*`(:225~267) **둘 다** 존재 → 두 온보딩 플로우 혼재. 실서버 정합 시: (a) 게이트웨이에 `/onboarding/**` 추가 or (b) learning-svc 실제 엔드포인트에 맞춰 프론트 경로 변경 — **learning-svc 온보딩 컨트롤러 실측 후 결정(조각 3)**.

### T3-8. 학습경로 (path, SSE)
| 항목 | 프론트 | 게이트웨이 | 판정 |
|---|---|---|---|
| 생성 | `path_sse_source.dart:31` `sse GET /learning-paths/me/generate` | learning `/learning-paths/**` | ✅ 경로 / **SSE 이벤트 와이어 미확정** |

### T3-9. Sandbox (SSE)
| 항목 | 프론트 | 게이트웨이 | 판정 |
|---|---|---|---|
| 실행 | `sandbox_run_source.dart:34` `sse /sandbox/run {code,language}` | sandbox `/sandbox/**` | ✅ 경로 / **SSE 와이어 미확정** |

### T3-10. AI 멘토 (SSE)
| 항목 | 프론트 | 게이트웨이 | 판정 |
|---|---|---|---|
| 세션 | `mentor_sse_source.dart:58` `sse /ai-mentor/sessions` | ai-review `/ai-mentor/**` | ✅ 경로 / **SSE 와이어 미확정**(HANDOFF P4e "백엔드 미합의") |

## 핵심 gap 3종

1. **온보딩 라우트(❌ 확정)**: 프론트 `POST /onboarding` ↔ 게이트웨이 `/onboarding/assessments/**`. 조각 3에서 learning-svc 실 엔드포인트 확인 후 게이트웨이 라우트 추가 또는 프론트 경로 정정.
2. **SSE 와이어(⚠️ 미확정)**: path·sandbox·mentor 경로는 게이트웨이 통과하나, 이벤트명·`DONE` 마커·payload 계약이 프론트 `SseClient` 소비 형식과 맞는지 백엔드 SSE 엔드포인트 실측 필요(조각 3). R1.
3. **auth OAuth 리다이렉트(⚠️ R4)**: 웹 로그인은 `/oauth2/**` Spring Security OAuth2 리다이렉트. 로컬 GitHub OAuth 앱·콜백 설정 비용. 조각 1b는 **토큰 경로(`/auth/refresh`)·계약 대조까지**로 한정하고 OAuth 실 리다이렉트 e2e는 조각 경계 재조정(사용자 확인).

## 서비스 의존 그래프 (스모크 조합)

| 화면 | 필요 최소 서비스(+인프라) |
|---|---|
| auth(refresh) | gateway + platform-svc |
| community | gateway + platform-svc(JWT 발급) + community-svc(+ai-svc 임베딩은 similar만) |
| lcs | gateway + platform-svc(JWT) + lcs-svc |
| content·dashboard | gateway + platform-svc(JWT) + learning-svc |
| review | gateway + platform-svc(JWT) + ai-svc |
| path·mentor·sandbox(SSE) | 각 gateway + platform-svc(JWT) + learning/ai/sandbox-svc |

- 공통: 모든 mutation·인증 경로는 platform-svc가 JWT를 발급해야 게이트웨이 JWT 검증(`GatewaySecurityConfig`)을 통과. community `similar`는 ai-svc 임베딩 필요(없으면 빈 결과 폴백 — `CommunityController.java:68`).

## 부분 bootRun 스모크 절차

전-스택 상시 구동 없이 화면별로 필요한 서비스만 띄워 실 게이트웨이(`:8080`) 경유로 검증한다.

### 공통 기동
```bash
# 1. 인프라 (postgres·pgvector·redis·es·kafka)
docker compose -f devpath-shared/docker-compose.yml up -d
# 2. 필요한 서비스만 (각 레포 루트에서)
cd devpath-gateway && ./gradlew bootRun          # :8080 (항상)
cd devpath-platform-svc && ./gradlew bootRun     # :8081 (JWT 발급 — 인증 필요 화면 전부)
cd <대상 svc> && ./gradlew bootRun               # 아래 조합표 참조
# 3. web 실API 프로파일
cp apps/web/.env.local.example apps/web/.env.local
cd apps/web && flutter run -d chrome --dart-define-from-file=.env.local
```

### T1 화면별 최소 스모크 조합
| 화면 | 서비스 조합(+인프라) | 확인 동작 |
|---|---|---|
| auth | gateway + platform(:8081) | 로그인 → `/auth/refresh`로 access 재발급·세션 유지 (OAuth 실 리다이렉트는 R4 — 조각 1b에서 범위 결정) |
| community | gateway + platform(:8081) + community(:8086) | 로그인 → `/community` 목록 로드 → 상세 → 작성/투표 (similar는 ai-svc 없으면 빈 결과 폴백) |
| lcs | gateway + platform(:8081) + lcs(:8087) | 질문 작성 폼 맥락 카드 draft → commit → 상세 답변자 패널(by-question) |

포트는 §게이트웨이 라우트·스펙 §2.4와 일치. 실제 기동·관측은 실행 조각(1b) 스모크에서 수행한다(이 절은 절차 정의).

## 미결정 / 리스크

- **R1 SSE 와이어**: 백엔드 SSE 엔드포인트(learning `/learning-paths/me/generate`, sandbox `/sandbox/run`, ai `/ai-mentor/sessions`) 실측 미완 — 조각 3 선행. 미구현/미합의면 프론트 단독 완결 불가.
- **R2 응답 View DTO**: T1/T2 응답 필드 단위 대조는 화면별 정합(조각 1b/2)에서. 규약 축은 정합 확인됨.
- **R4 auth OAuth**: 위 핵심 gap 3.
- **온보딩 이중 플로우**: 목 픽스처의 `/onboarding` vs `/onboarding/assessments/*` 혼재 원인은 learning-svc 실측으로 확정(조각 3).

## 조각 1b — T1 응답 View DTO 대조 (2026-07-03, 완료)

T1 잔여였던 응답 View DTO 필드 대조를 완료했다. **전부 정합 — 수정 불필요.**

| 백엔드 View DTO (origin/develop) | 프론트 dp_core 모델 | 결과 |
|---|---|---|
| `PostSummaryView(id,title,authorId,solved,upvoteCount,answerCount)` | `CommunityPostSummary` | ✅ 필드명·타입 일치 |
| `QuestionDetailView(id,title,bodyMd,solved,acceptedAnswerId,upvoteCount,downvoteCount,tags,answers)` | `CommunityQuestionDetail` | ✅ |
| `AnswerView(id,authorId,bodyMd,aiGenerated,accepted,upvoteCount)` | `CommunityAnswer` | ✅ |
| `TagView(id,name,postCount)` | `CommunityTag` | ✅ |
| `SimilarQuestionView(questionId,title)` | `SimilarQuestion` | ✅ |
| `DraftResponse(draftId,expiresAt,content,fieldsAvailable,fieldsUnavailable)` | `LcsDraft` | ✅ (`content`=Map 그대로, `expiresAt` Instant→DateTime ISO) |
| `CommitResponse(snapshotId,status,immutable)` | lcs_source가 `snapshotId` 직접 파싱 | ✅ |
| `SnapshotView(id,createdAt,content,renderedFor)` | `LcsSnapshotView` | ✅ |
| `UserSummary(id,email,nickname,role,onboardingStatus)` | `User` | ✅ (`role`/`onboardingStatus` String→enum `unknownEnumValue` fallback) |

**결론: T1(auth·커뮤니티·LCS)은 실API 계약이 응답 DTO까지 완전 정합.** slice8·slice9·web-auth-realapi PR의 정합 결과. **R2(T1) 해소.**

**회귀 커버:** 기존 화면별 위젯·컨트롤러 테스트(`community_home_page_test`·`qna_detail_*_test`·`lcs_source_test` 등)가 T1 UI/흐름 회귀를 커버. 추가로 `apps/web/test/golden_path_t1_realapi_test.dart`(DONE 유저→대시보드→커뮤니티 목록) 골든패스 통합 스모크 1건(`flutter test` green). **단, 이들은 목 레벨이라 실API 계약 회귀는 잡지 못한다 — 실 계약 회귀 검증은 위 "부분 bootRun 스모크"(실서버) 경로가 담당한다.**
