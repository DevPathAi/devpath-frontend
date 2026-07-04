# 축 B 설계: mock OAuth2 provider 웹 로그인 e2e

- 날짜: 2026-07-04
- 로드맵: Tier-2 이후 A→C→B 중 **B(OAuth 실 리다이렉트 e2e, R4)**([[devpath-web-posttier2-roadmap]]). A·C 완료 후 마지막 축.
- 구현 레포: **devpath-platform-svc**(OAuth 흐름이 여기 있음). 이 spec/plan/런북 문서는 로드맵 연속성을 위해 devpath-frontend `docs/superpowers/`에 둔다.

## 배경 / R4의 실제 gap

웹 로그인 흐름: 프론트 `login()` → `{gateway}/oauth2/authorization/github` → GitHub authorize → platform 콜백 `/login/oauth2/code/github` → `OAuth2LoginSuccessHandler`(user 등록 + refresh HttpOnly 쿠키) → `{web-url}/auth/callback` → 프론트 `bootstrapFromCallback()` → `POST /auth/refresh` → `AuthAuthenticated`.

**현 테스트 상태**: platform은 `OAuth2LoginSuccessHandlerTest`·`OAuth2LoginSuccessHandlerMobileTest`·`MobileAwareAuthorizationRequestResolverTest`로 핸들러·resolver **단위**는 커버하나, **실 Spring Security 필터체인으로 authorize→callback→쿠키→refresh 전 흐름을 도는 e2e는 없다**(mock-oauth2-server/WireMock 미도입). 프론트 `auth_callback_page`·`oauth_launcher`·`auth_controller`(login/bootstrapFromCallback)는 이미 단위 테스트됨. ⇒ **R4 = 흐름 배선이 e2e로 검증된 적 없음**.

실 GitHub e2e의 friction: 실 OAuth 앱(client-id/secret) + **브라우저 GitHub authorize**(헤드리스 자동화 불가).

## 목표 / 비목표

**목표**: platform 실 필터체인으로 웹 OAuth 로그인 전 흐름을 **로컬 mock OAuth2 provider**로 자동·반복 검증. 실 GitHub은 config 스왑 런북으로 남김.

**비목표**:
- 모바일 PKCE 플로우(`/auth/oauth/token`) — 이미 `OAuth2LoginSuccessHandlerMobileTest`로 커버.
- 프론트 위젯(콜백 페이지·launcher·컨트롤러) — 이미 단위 테스트됨.
- 실 GitHub 브라우저 authorize 자동화 — 불가, 런북으로.

## 핵심 사실 (실측)

- platform `application.yml`은 `registration.github.{client-id,client-secret,scope}`만 설정 → **provider uri는 Spring 내장 `github` 기본값(github.com)**. mock 전환 시 **provider uri**(authorization/token/user-info)를 오버라이드해야 함.
- `devpath.auth.web-url` 기본 `http://localhost:5173`(APP_WEB_URL). SuccessHandler가 `{web-url}/auth/callback`로 리다이렉트.
- github provider는 **비-OIDC**(id_token 아닌 userinfo 기반). SuccessHandler는 attrs `{id, login, name, email}`을 읽음.
- JWT=HS256 대칭(dev 시크릿). `/auth/refresh`·`/auth/logout`·`/auth/oauth/token`·`/oauth2/**`·`/login/**`은 permitAll.
- platform 테스트 의존에 mock-oauth2-server/WireMock 없음 → 추가 필요. 기존 @SpringBootTest는 로컬 postgres 사용.

## 컴포넌트

### 1. mock-oauth2-server 테스트 의존 (platform-svc)
`testImplementation("no.nav.security:mock-oauth2-server:<호환버전>")` 추가(embedded, 랜덤 포트, OAuth2 authorize/token/userinfo 제공, provider-agnostic). 정확한 버전은 플랜에서 Spring Boot 4/Security 7 호환본으로 확정.

### 2. e2e 테스트 (`OAuthWebLoginE2ETest`, `@SpringBootTest(webEnvironment=RANDOM_PORT)`)
- `@DynamicPropertySource`로 mock 서버 URI 주입:
  - `spring.security.oauth2.client.provider.github.authorization-uri` → `{mock}/authorize`
  - `...provider.github.token-uri` → `{mock}/token`
  - `...provider.github.user-info-uri` → `{mock}/userinfo`
  - `...provider.github.user-name-attribute` = `id`
  - `...registration.github.{client-id,client-secret}` = 테스트값
  - `devpath.auth.web-url` = 테스트값(예: `http://web.test`)
- mock userinfo가 **GitHub 형태** `{id, login, name, email}` 반환하도록 구성(고유 `id`로 DB 충돌 회피).
- 테스트 클라이언트(`TestRestTemplate`/`WebTestClient`, 리다이렉트 수동 추적·쿠키 보존)로 흐름 구동:
  1. `GET /oauth2/authorization/github` → 302 mock authorize.
  2. mock authorize 자동 완료 → 302 콜백 `/login/oauth2/code/github?code&state`(쿠키/state 보존).
  3. 콜백 → SuccessHandler → **302 `Location={web-url}/auth/callback`** + `Set-Cookie` refresh.

### 3. 단언 (전 흐름)
- 최종 리다이렉트 `Location == {web-url}/auth/callback`.
- refresh 쿠키 존재 + `HttpOnly`.
- 이어서 **`POST /auth/refresh`**(refresh 쿠키 동봉) → `200` + 바디 `access_token`(비어있지 않음) + `user{id,email,nickname,role,onboardingStatus}`가 mock 유저와 일치.
- `registerOrFind`로 user 영속됨(재-로그인 시 동일 user id, 중복 생성 없음 — 흐름 2회 반복해 확인).

### 4. 실 GitHub 런북 (문서)
`docs/superpowers/reports/2026-07-04-oauth-real-github-runbook.md`: GitHub OAuth 앱 등록(Authorization callback URL `{platform}/login/oauth2/code/github`), env(`GITHUB_CLIENT_ID`·`GITHUB_CLIENT_SECRET`·`APP_WEB_URL`), 인프라+gateway+platform+프론트 기동, 브라우저 로그인→콜백→대시보드 진입 확인 절차. 인간이 실 GitHub 1회 확인용(자동화 대상 아님).

## 실행 모델

platform-svc 테스트 1개(+의존) 추가 + frontend 문서. **subagent-driven**(TDD): 실패 테스트 선작성 → mock 배선 → 통과. 로컬 DB 의존은 고유 mock user id로 오염 회피.

## 리스크

- **R-B1 호환**: mock-oauth2-server ↔ Spring Boot 4/Security 7. provider-agnostic이라 낮으나 버전은 플랜에서 확정(안되면 WireMock 스텁 폴백).
- **R-B2 비-OIDC**: github provider는 userinfo 기반 → mock userinfo를 github 형태로 구성, `user-name-attribute=id`. id_token/OIDC discovery에 의존하지 않도록 provider uri를 명시 주입.
- **R-B3 로컬 DB 오염**: platform @SpringBootTest도 로컬 postgres 사용([[devpath-svc-test-context-connection-flake]] 동류) → 고유 user id + 테스트 종료 정리. CI는 clean DB.
- **R-B4 리다이렉트/쿠키 추적**: TestRestTemplate이 302를 자동 추적하면 state/쿠키가 끊길 수 있음 → 리다이렉트 수동 비활성화하고 단계별로 Location·쿠키를 이어붙임.
