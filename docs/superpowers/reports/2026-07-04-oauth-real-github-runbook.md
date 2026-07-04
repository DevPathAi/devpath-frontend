# 실 GitHub OAuth e2e 수동 확인 런북 (축 B)

- 날짜: 2026-07-04
- 목적: 자동 회귀는 mock e2e(`devpath-platform-svc` `OAuthWebLoginE2ETest`)가 담당한다. **이 런북은 실 GitHub 로그인을 사람이 브라우저로 1회 확인**하기 위한 절차다(GitHub authorize는 헤드리스 자동화 대상이 아님).
- 관련: [[devpath-web-posttier2-roadmap]] 축 B(R4). 설계 `specs/2026-07-04-oauth-e2e-design.md`.

## 흐름 요약

프론트 `login()` → `{gateway}/oauth2/authorization/github` → GitHub authorize → platform 콜백 `/login/oauth2/code/github` → `OAuth2LoginSuccessHandler`(user 등록 + refresh HttpOnly 쿠키) → `{APP_WEB_URL}/auth/callback` → 프론트 `bootstrapFromCallback()` → `POST /auth/refresh` → 세션 복원 → 게이트가 온보딩 상태로 분기.

## 1. GitHub OAuth 앱 등록 (1회)

GitHub → Settings → Developer settings → **OAuth Apps** → New OAuth App:
- **Application name**: `DevPath (local)`
- **Homepage URL**: `http://localhost:5173` (프론트 flutter run 포트에 맞춤)
- **Authorization callback URL**: `http://localhost:8080/login/oauth2/code/github`
  - 게이트웨이(:8080) 경유. 게이트웨이가 `/login/**`·`/oauth2/**`를 platform으로 프록시(`devpath-gateway` `application.yml` `platform-auth` 라우트).
- 발급된 **Client ID**·**Client secret** 확보.

## 2. 환경변수

platform(:8081) 기동 시:
```
GITHUB_CLIENT_ID=<발급 client id>
GITHUB_CLIENT_SECRET=<발급 client secret>
APP_WEB_URL=http://localhost:5173     # SuccessHandler가 {APP_WEB_URL}/auth/callback로 리다이렉트
JWT_SECRET=test-secret-please-change-min-32-bytes-long-0123456789   # gateway/svc와 동일해야 검증 통과
```
gateway(:8080): `PLATFORM_URI=http://localhost:8081`.

## 3. 스택 기동

```bash
# 인프라(postgres 등)
docker compose -f devpath-shared/docker-compose.yml up -d
# gateway (:8080)
cd devpath-gateway && ./gradlew bootRun
# platform (:8081) — 위 env 주입
cd devpath-platform-svc && SERVER_PORT=8081 GITHUB_CLIENT_ID=... GITHUB_CLIENT_SECRET=... APP_WEB_URL=http://localhost:5173 ./gradlew bootRun
# 프론트 (실API, baseUrl=gateway)
cp apps/web/.env.local.example apps/web/.env.local   # baseUrl=http://localhost:8080/... 확인
cd apps/web && flutter run -d chrome --dart-define-from-file=.env.local
```

## 4. 브라우저 확인 절차

1. 프론트 로그인 페이지에서 **GitHub 로그인** 버튼 클릭.
2. 브라우저가 GitHub authorize 페이지로 이동 → **Authorize** 승인.
3. platform 콜백 처리 후 `http://localhost:5173/auth/callback`로 착지(로딩 스피너).
4. `bootstrapFromCallback()`이 `POST /auth/refresh`(HttpOnly refresh 쿠키 자동 동봉) 호출 → access token + user 수신 → `AuthAuthenticated`.
5. 게이트가 `onboardingStatus`로 분기: 미완이면 `/diagnostic`, 완료면 `/dashboard`(또는 `/path`).

## 5. 체크포인트 / 트러블슈팅

- **refresh 쿠키**: 브라우저 DevTools → Application → Cookies에 refresh 쿠키(HttpOnly) 존재.
- **/auth/refresh 200**: Network 탭에서 `POST /auth/refresh` 200 + 응답 `access_token`·`user`.
- **실패 시 점검**:
  - 콜백 URL 불일치 → GitHub 앱의 Authorization callback URL이 정확히 `http://localhost:8080/login/oauth2/code/github`인지.
  - `redirect_uri_mismatch` → 위 콜백 URL·게이트웨이 라우팅.
  - 콜백 후 `/auth/callback`가 아닌 곳으로 감 → platform `APP_WEB_URL` 확인.
  - 401 on `/auth/refresh` → 쿠키 도메인/SameSite(`devpath.auth.cookie-*`) 또는 `withCredentials`(프론트 `api_providers`에서 `true` 설정됨) 확인.
  - JWT 검증 실패 → gateway·platform·대상 svc의 `JWT_SECRET` 동일 여부.

> 자동 회귀는 `OAuthWebLoginE2ETest`(mock provider)가 담당한다. 이 런북은 실 GitHub 연동을 사람이 1회 확인하는 용도이며 CI 대상이 아니다.
