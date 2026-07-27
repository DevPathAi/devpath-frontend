# WS-C2a 설계서: admin 실 인증 + 베타 승인 UI

- **작성일**: 2026-07-17
- **워크스트림**: WS-C(베타 게이팅 프론트) 중 **C2a = platform enabler + admin 앱**
- **범위 레포**: `devpath-platform-svc`(admin OAuth enabler), `devpath-frontend/apps/admin`(실 인증 + 승인 UI)
- **후속(별도 사이클)**: **C2b = web 베타 대기 페이지** — `/beta-pending` 라우트 + `BetaProperties.pendingRedirect` 기본값 변경. C2a와 독립.
- **선행**: WS-C1 완료·머지([[devpath-ws-c1-beta-gating]]) — `/admin/**`(ADMIN authz)·`GET /admin/users`·`POST /admin/users/{id}/approve`·`POST /admin/allowlist` 실재.

---

## 1. 목표

admin 앱이 **실 ADMIN JWT로 실 `/admin` API에 붙어** 베타 대기자를 승인하고 이메일을 사전승인한다. 현재 admin 앱은 mock 전용(`POST /admin/auth/login` — 백엔드에 없는 엔드포인트)이라, WS-C1이 만든 ADMIN-role JWT 체계에 실제로 연결되지 않는다. C2a는 그 연결(실 인증)과 승인/사전승인 화면을 완성한다.

### 배경 (실측, 2026-07-17)

- **admin 인증은 완전 mock**: `AdminAuthController.login()`이 `/admin/auth/login`(부재) 호출, 버튼 "관리자 로그인 (목)". `api_providers`의 `AuthInterceptor.refresh`는 `null`(자동 갱신 미배선).
- **admin users 화면**: 상태 필터=모더레이션용(`ACTIVE|WARNED|SUSPENDED|BANNED`), 우측=제재 패널(`/admin/users/{id}/sanction` mock). BETA_PENDING·승인 개념 없음. `adminUsersFetch`는 이미 `GET /admin/users?status=&cursor=` 실계약 배선.
- **admin 라우터 가드**: 미인증→`/login`, 비-ADMIN→`/forbidden`, ADMIN→앱. `User.isAdmin`으로 판정.
- **platform OAuth**: 로그인 성공 시 웹은 `props.getWebUrl() + "/auth/callback"`으로만 복귀. 모바일은 `client_type=mobile&code_challenge`→state `.mobile.` 마커→딥링크. **admin 앱으로 돌아올 경로 없음.**
- **베타 게이트**: `BetaGate.admit`는 allowlist 미포함 사용자를 BETA_PENDING으로 보류. **관리자 이메일이 allowlist에 없으면 관리자도 대기로 빠진다**(승인 불가 교착).

---

## 2. platform enabler (admin OAuth 복귀 + ADMIN 우회)

admin 앱이 web과 동일한 OAuth 왕복으로 ADMIN JWT를 얻도록 최소 배선을 추가한다. 기존 모바일 마커 패턴을 그대로 미러링한다.

### 2.1 admin 마커 (client_type 인식 resolver)

`MobileAwareAuthorizationRequestResolver`를 확장해 `client_type=admin`을 인식한다:
- `client_type=admin`이면 state를 `<csrf>.admin.`로 만든다(마커 `.admin.`, 모바일과 달리 challenge 불요).
- 모바일 분기(`client_type=mobile` + `code_challenge`)는 그대로 유지.
- 기존 `MobileAwareAuthorizationRequestResolver`에 admin 분기를 **확장**한다. 상수 `ADMIN="admin"`, `ADMIN_STATE_MARKER=".admin."` 추가. 클래스명은 유지(최소 변경)하되, 두 client_type을 다룸을 javadoc에 명시. 개명(`ClientTypeAware…`)은 선택(구현 시 최소 변경 우선, §8).

### 2.2 핸들러 admin 분기

`OAuth2LoginSuccessHandler`에서, 게이팅(`admit`) 통과 후:
- **admin 마커 감지** 시: 웹과 동일하게 refresh를 발급해 **HttpOnly refresh 쿠키 설정 + `adminUrl + "/auth/callback"`로 리다이렉트**(모바일 딥링크가 아님). 순서 = 모바일 마커 분기 → admin 마커 분기 → 기본 웹.
- `AuthProperties`에 `adminUrl` 추가(+ `application.yml` `devpath.auth.admin-url`, 기본 `http://localhost:5174` 수준). web-url과 동형.

### 2.3 ADMIN 게이트 우회

`BetaGate.admit(User)` 최상단에 `if ("ADMIN".equals(user.getRole())) return true;` 추가. 관리자 이메일이 `beta_allowlist`에 없어도 대기로 빠지지 않는다(관리자가 로그인해 승인해야 하므로 필수). 신규 관리자 계정은 `registerOrFind`가 이미 `admin-emails`→role ADMIN·status ACTIVE로 생성하므로 상태 변경 부수효과 없음.

> 참고: 대기 리다이렉트 경로(`pendingRedirect`) 기본값 변경(`/login?beta=pending`→`/beta-pending`)은 **C2b 소관**(web 페이지와 함께 착지). C2a는 admin 인증 배선만.

---

## 3. admin 앱 — 실 인증 (mock 대체)

`AdminAuthController`의 mock 로그인을 web 패턴(OAuth 왕복 + `/auth/refresh`)으로 대체한다.

### 3.1 OAuth 개시

- 로그인 버튼 → OAuth 런처가 브라우저를 `{apiBase}/oauth2/authorization/github?client_type=admin`으로 리다이렉트. web `apps/web`의 `oauth_launcher.dart`/`oauth_launcher_web.dart`(조건부 임포트, `window.location.href`) 패턴을 admin에 도입(동일 구현 복제 또는 공용 패키지화는 YAGNI로 복제).
- Google 버튼도 동형(`/oauth2/authorization/google?client_type=admin`).

### 3.2 콜백 + 세션 부트스트랩

- admin 라우터에 **`/auth/callback` 라우트 + `AdminAuthCallbackPage`** 추가(가드 통과 허용). 마운트 시 `bootstrapFromCallback()` 호출.
- `AdminAuthController`에 `bootstrapFromCallback()`: `POST /auth/refresh`(공유 refresh 쿠키) → `{access_token, user}` 수령 → `tokenStore.save(access, refresh?)` → `state = AdminAuthed(User)`. 실패 시 `AdminUnauthed(error)`.
- `api_providers`의 `AuthInterceptor.refresh`를 실 배선(`POST /auth/refresh`로 access 재발급) — 현재 `null`. web의 `AuthInterceptor` 사용법과 동일.
- `useMock=false`(실 게이트웨이). 비-ADMIN 로그인 시 `/auth/refresh` user.role≠ADMIN → 라우터 가드가 `/forbidden`.

### 3.3 로그인 페이지

`AdminLoginPage`: "(목)" 제거, `useMock` 분기(mock 시 기존 즉시 인증 유지, 실 시 OAuth 런치). GitHub/Google 버튼.

---

## 4. admin 앱 — 승인/사전승인 UI

### 4.1 대기자 목록

- `AdminUsersPage` 상태 필터 칩에 **`BETA_PENDING` 추가**(기존 모더레이션 상태와 나란히). `GET /admin/users?status=BETA_PENDING`(배선됨)로 대기자 조회.

### 4.2 승인

- 우측 상세 패널: 선택 행이 `BETA_PENDING`이면 **"승인" 버튼** 노출 → `POST /admin/users/{id}/approve`(204) → 성공 시 `load()` 재호출로 목록 갱신(승인된 사용자는 BETA_PENDING 필터에서 사라짐). 기존 제재 버튼은 status가 모더레이션 상태일 때만 노출(상태별 액션 분기).
- `UsersController`에 `approve(String userId)` 추가(실 엔드포인트).

### 4.3 사전승인 폼

- users 화면 상단(또는 별도 카드): **이메일 입력 + "허용리스트 추가" 버튼** → `POST /admin/allowlist {"email": "..."}`(204). 로그인 전 리드폼 승인자 사전 등록. 성공/실패 스낵바.
- `UsersController`에 `preApprove(String email)` 추가.

### 4.4 데이터 배선

- `adminUsersFetchProvider`(GET, 배선됨) 유지. 신규 `approve`/`preApprove`는 `apiClientProvider.post`로 직접 호출(별도 소스 프로바이더 불요, YAGNI).

---

## 5. 컴포넌트 경계 (단위)

| 단위 | 책임 | 의존 |
|------|------|------|
| `ClientTypeAwareAuthorizationRequestResolver` (platform) | mobile/admin client_type→state 마커 | delegate resolver |
| `OAuth2LoginSuccessHandler` (platform, 수정) | admin 마커→adminUrl 복귀 | AuthProperties.adminUrl |
| `BetaGate.admit` (platform, 수정) | ADMIN role 우회 | — |
| admin `oauth_launcher(_web/_stub)` | 브라우저 OAuth 리다이렉트 | dart web |
| admin `AdminAuthCallbackPage` + `AdminAuthController.bootstrapFromCallback` | /auth/refresh 세션 복원 | ApiClient, tokenStore |
| admin `UsersController.approve/preApprove` | 승인·사전승인 호출 | ApiClient |
| admin `AdminUsersPage`(수정) | BETA_PENDING 필터·승인 버튼·사전승인 폼 | UsersController |

---

## 6. 테스트

### platform-svc (JUnit)
- resolver: `client_type=admin`→state `.admin.` 마커; mobile 분기 회귀 없음.
- 핸들러: admin 마커 로그인 → refresh 쿠키 + `adminUrl/auth/callback` 리다이렉트(웹/모바일과 구분).
- `BetaGate`: role=ADMIN 사용자 → `admit`=true(allowlist 무관, 이벤트 없음).

### admin 앱 (flutter_test + ProviderContainer)
- `AdminAuthController.bootstrapFromCallback`: `/auth/refresh` 성공→AdminAuthed(user), 실패→AdminUnauthed. (ApiClient mock)
- 승인: BETA_PENDING 행 선택→"승인" 버튼→`POST /admin/users/{id}/approve` 호출·목록 재로딩(mock adapter로 검증).
- 사전승인 폼: 이메일 입력→`POST /admin/allowlist` 호출.
- 필터: BETA_PENDING 칩 존재·선택 시 status 파라미터 전달.

### 검증 명령
- platform: `./gradlew test`.
- admin: 모노레포 루트에서 `melos run analyze` + `melos run test`(또는 `cd apps/admin && flutter test`).

---

## 7. 명시적 비범위 (C2a에서 제외)

- **C2b**: web `/beta-pending` 라우트·페이지 + `BetaProperties.pendingRedirect` 기본값 변경(`/beta-pending`). 별도 사이클.
- 실 배포·도메인/쿠키 구성(admin-url·cookie-domain `.leva.ai.kr` 실값) — WS-D 소관. C2a는 로컬 기본값·환경변수 배선까지.
- admin 앱의 기존 제재(sanction)·리포트·대시보드 실 API 전환 — 베타 승인과 무관(별도).
- 모바일 앱 admin 기능 — 비범위.

---

## 8. 리스크 / 오픈 포인트

- **공유 refresh 쿠키 도메인**: admin(`admin.leva.ai.kr`)과 api(`api.leva.ai.kr`)가 `.leva.ai.kr` 쿠키를 공유해야 `/auth/refresh`가 동작. 로컬은 동일 호스트/포트 차이라 쿠키 SameSite/도메인 확인 필요. 실값은 WS-D; C2a는 로컬에서 OAuth 왕복이 도는지까지 검증(mock-oauth2-server 또는 런북).
- **admin OAuth e2e**: mock-oauth2-server OIDC(google) 비대칭 이슈([[devpath-mvp-remaining]] 교훈) — google admin e2e는 런북 전환 가능, github 위주 검증.
- **resolver 개명**: `MobileAwareAuthorizationRequestResolver`→`ClientTypeAwareAuthorizationRequestResolver`는 SecurityConfig 빈 등록·기존 테스트 참조를 갱신해야 함(개명 대신 확장만 하고 이름 유지도 가능 — 구현 시 최소 변경 우선).
- **AuthInterceptor refresh 배선**: 현재 `null`(401→재로그인). 실 refresh 배선 시 web과 동일 패턴 준수(무한 루프 방지: refresh 자체 401은 store.clear).
