# WS-C2b — 베타 대기 페이지(/beta-pending) + 승인 폴링 설계

- 작성일: 2026-07-18
- 상태: 승인됨(브레인스토밍 완료)
- 관련: 베타 게이팅 C1(백엔드)·C2a(admin 승인 UI) 완료 이후의 웹 대기 페이지 조각
- 레포: `devpath-platform-svc`(백엔드) + `devpath-frontend`(apps/web·dp_core)

## 1. 배경 / 목표

베타 게이팅에서 허용 목록에 없는 사용자는 OAuth 로그인에 성공해도 `BetaGate.admit()==false`가 되어
**토큰·쿠키 없이** 리다이렉트된다(`OAuth2LoginSuccessHandler`). 현재 리다이렉트 목적지는
`/login?beta=pending`인데, **web `LoginPage`는 `beta=pending` 쿼리를 전혀 처리하지 않아** 미승인자는
아무 안내 없는 맨 로그인 화면을 본다("깨진 창").

**목표**: 미승인자가 착지하는 전용 대기 페이지 `/beta-pending`을 신설하고, **승인되면 자동으로 진입**하도록
승인 여부를 주기 폴링한다. 관리자 승인(기존 `AdminBetaService`, `user.status=ACTIVE`)이 반영되면
사용자가 새 동작 없이 데모에 입장한다.

## 2. 전제 / 핵심 제약

- 미승인자는 **인증 토큰이 전혀 없다**(보안 하드닝: 미승인=무토큰). 따라서 승인 여부를 물어볼
  **인증된 폴링 엔드포인트가 없다.** → 폴링을 성립시키려면 **단명 조회 전용 토큰 + 공개 상태 API**가 필요.
- 조회 토큰을 **JWT로 만들면 안 된다**: `SecurityConfig.oauth2ResourceServer.jwt`가 같은 시크릿 서명 JWT를
  실 인증(Bearer)으로 오인할 수 있다. → **Redis opaque 토큰**(refresh 패턴)으로 완전 분리한다.
- 승인 감지 후 실제 진입에는 여전히 **재-OAuth**가 필요하다(폴링으로 APPROVED를 봐도 access 토큰은 없음).

## 3. 전체 흐름

```
① 미승인자 OAuth 성공 → SuccessHandler admit=false
     → beta_status 쿠키(단명 30분) 발급 + (webUrl + pendingRedirect=/beta-pending) 리다이렉트
② 프론트 /beta-pending 로드(gateRedirect 미인증 통과) → 안내 표시 + 5초마다 GET /beta/status 폴링
③ 관리자 승인 → user.status = ACTIVE (기존 AdminBetaService.approve)
④ 다음 폴링이 {status:"APPROVED", provider} 수신
     → 자동 authController.login(provider) 재-OAuth
     → SuccessHandler admit=true → refresh 쿠키 + /auth/callback → 정상 게이트 진입
⑤ 쿠키 만료(30분 경과) → 폴링이 {status:"EXPIRED"} 수신 → "다시 로그인" 버튼으로 전환
```

## 4. platform 백엔드 상세 (`ai.devpath.platform.beta`)

### 4.1 `BetaStatusTokens` (신규)
- Redis opaque 토큰. `RefreshTokenStore`와 **동일 패턴**(랜덤 32B → Base64url → SHA-256 해시 키 저장)이되
  **네임스페이스 완전 분리**: prefix `beta-status:`.
- `String issue(long userId)`: TTL = `BetaProperties.statusTtl`(기본 `PT30M`). 값 = userId.
- `Optional<Long> validate(String token)`: 해시 조회 → userId.
- refresh와 달리 rotate/역인덱스/revokeAll 불필요(단명 조회 전용). 최소 구현.

### 4.2 `beta_status` 쿠키
- 쿠키명 `beta_status`, HttpOnly, `path=/`, maxAge = statusTtl(초), domain/SameSite/secure는 기존
  `AuthProperties`(refresh 쿠키와 동일 정책) 재사용.
- 구현: 신규 소형 `BetaStatusCookies`(병렬 컴포넌트). 기존 `RefreshCookies`(refresh 계약)를 건드리지 않는다.
  쿠키명 `beta_status`, maxAge = statusTtl.

### 4.3 `BetaStatusController` (신규) — `GET /beta/status`
- **permitAll**(Spring Security 인증 아님, 쿠키 기반 자체 검증).
- 요청의 `beta_status` 쿠키 → `BetaStatusTokens.validate` → userId → `UserRepository.findById`.
  - `user.status == "ACTIVE"` → `{ "status": "APPROVED", "provider": "<대표 provider>" }`
  - `user.status == "BETA_PENDING"` → `{ "status": "PENDING" }`
  - 쿠키 없음/무효/유저 없음 → `{ "status": "EXPIRED" }` (HTTP 200; 프론트가 재로그인 유도)
- **대표 provider**: `UserOauthIdentity` 목록의 첫 번째(가입 순) provider. identity가 없으면 provider 필드 생략 →
  프론트는 `/login`으로 보내 수동 선택.
- 응답 DTO: `record BetaStatusResponse(String status, String provider)`.

### 4.4 `OAuth2LoginSuccessHandler` 수정 (현 75~78행)
```java
if (!betaGate.admit(user)) {
    String statusToken = betaStatusTokens.issue(user.getId());
    response.addHeader(HttpHeaders.SET_COOKIE, betaStatusCookies.create(statusToken).toString());
    response.sendRedirect(props.getWebUrl() + betaProps.getPendingRedirect());
    return;
}
```
- 의존성 2개 주입 추가(`BetaStatusTokens`, `BetaStatusCookies`).

### 4.5 설정 변경
- `application.yml`: `devpath.beta.pending-redirect` 기본값 `/login?beta=pending` → **`/beta-pending`**.
- `BetaProperties`: `Duration statusTtl`(기본 `PT30M`) 추가.
- `SecurityConfig`: permitAll 목록에 `"/beta/status"` 추가.

## 5. frontend 상세 (`apps/web` + `packages/dp_core`)

### 5.1 라우트 / 게이트 (`src/app/router.dart`)
- 라우트 신설: `GoRoute(path: '/beta-pending', builder: (_, _) => const BetaPendingPage())` (ShellRoute 밖, /login과 동급).
- `gateRedirect` 수정:
  - `final atBetaPending = location == '/beta-pending';`
  - 미인증(`auth is! AuthAuthenticated`) 분기에서 `atLogin || atDiagnostic || atBetaPending` 통과(null).
  - **인증(ACTIVE) 유저가 `/beta-pending` 방문 시** → `/dashboard`(정상 게이트로 흡수). 즉 인증 상태에서는
    대기 페이지에 머무르지 않는다.

### 5.2 `BetaPendingPage` (신규, `features/beta/presentation/beta_pending_page.dart`)
- 안내 문구: 대기자 명단 등록됨 / 승인되면 이메일 통보 / 승인 시 자동 입장.
- `Timer.periodic(Duration(seconds: 5))` → `apiClient.get<Map>('/beta/status')` + `BetaStatus.fromJson`:
  - `APPROVED` → 타이머 취소 후 `authController.login(provider)`(provider 없으면 `/login` 이동).
  - `PENDING` → 계속 폴링(대기 상태 유지).
  - `EXPIRED` → 타이머 취소, "다시 로그인" 버튼 노출(→ `/login`).
- `dispose`에서 타이머 취소(누수 방지). 위젯 상태이므로 `ConsumerStatefulWidget`.

### 5.3 dp_core
- 모델 `BetaStatus { BetaStatusKind status; String? provider; }`, `enum BetaStatusKind { pending, approved, expired }` + `BetaStatus.fromJson`. dp_core.dart export.
- 조회는 **기존 dashboard 패턴**대로 페이지가 `apiClient.get<Map>('/beta/status')`(withCredentials로 쿠키 자동 동봉) 호출 후 `BetaStatus.fromJson` 파싱. `ApiClient`에 도메인 메서드를 추가하지 않으므로 **fake override 파급 없음**(위젯테스트는 자체 fake의 `get`만 스텁).

## 6. 엣지 / 에러 처리

- 미인증 아무나 `/beta-pending` 직접 방문 → status 쿠키 없음 → 즉시 `EXPIRED` → 재로그인 버튼(무해).
- 자동 재-OAuth 시 브라우저에 SSO 세션 없으면 provider 로그인 화면 노출(불가피, 수용).
- 폴링 중 네트워크 오류 → 해당 회차 무시하고 다음 주기 재시도(연속 실패해도 페이지는 대기 유지).
- 쿠키 30분 만료 후 승인되면: 사용자는 `EXPIRED` 안내를 보고 재로그인 → admit=true로 정상 진입(폴링 없이도 성립).

## 7. 보안 고려

- `beta_status` 토큰은 **조회 전용**: `/beta/status` 외 어떤 API도 인증하지 않는다(opaque + 별도 네임스페이스라
  resourceServer JWT 경로와 물리적으로 분리). 탈취돼도 노출은 "해당 계정의 PENDING/APPROVED 여부"뿐.
- 사용자 열거 방지: 쿠키 없는 요청은 일률 `EXPIRED`(이메일/식별자 입력 경로 없음).
- 토큰은 HttpOnly 쿠키로만 전달(URL 노출 없음).

## 8. 테스트 전략

### platform
- `BetaStatusTokensTest`: issue→validate 왕복, 무효 토큰 empty.
- `BetaStatusControllerTest`(@SpringBootTest): PENDING / APPROVED(+provider) / EXPIRED(쿠키 없음) 3케이스.
- `OAuth2LoginSuccessHandlerBetaTest` 확장: admit=false가 `beta_status` 쿠키를 Set-Cookie로 발급하고
  `/beta-pending`으로 리다이렉트하는지.
- pendingRedirect 기본값 회귀(기존 리다이렉트 테스트가 있으면 `/beta-pending`으로 갱신).
- 회귀 주의: 실 `BetaGate` 통합테스트(`OAuthWebLoginE2ETest`)는 allowlist 시드 유지(C1 교훈).

### frontend
- `gateRedirect` 단위테스트: 미인증 `/beta-pending` 통과, 인증 유저 `/beta-pending`→`/dashboard`.
- `BetaPendingPage` 위젯테스트(fake ApiClient): PENDING 지속 → APPROVED 시 `login(provider)` 호출 → EXPIRED 시 버튼.
- `melos run format` 게이트 대비 커밋 전 `dart format .`(교훈 ⑪).

## 9. 범위 / 비범위

**범위**: 위 platform 백엔드 + frontend 변경, 테스트.

**비범위**:
- 이메일 알림 문구/발송(C1 notification #10에서 이미 처리 — waitlisted/approved 이메일).
- admin 승인 UI(C2a 완료).
- 모바일 앱 대기 화면(웹 데모 우선; 모바일은 후속).
- 실배포 도메인·환경변수 확정(WS-D 소관).

## 10. 작업 순서(구현 플랜에서 Task 분해)

1. platform: `BetaStatusTokens` + `BetaStatusCookies` + `BetaProperties.statusTtl` (TDD).
2. platform: `BetaStatusController` `GET /beta/status` + `SecurityConfig` permitAll (TDD).
3. platform: `OAuth2LoginSuccessHandler` admit=false 쿠키 발급 + `pending-redirect` 기본값 변경 (기존 테스트 확장).
4. frontend: dp_core `ApiClient.getBetaStatus` + `BetaStatus` 모델 + fake override.
5. frontend: `gateRedirect` 예외 + `/beta-pending` 라우트 + `BetaPendingPage` + 폴링 (TDD).

> platform과 frontend는 **각각 별도 작업 브랜치**(`feat/beta-pending-*`), 각 레포 develop으로 PR.
> platform PR을 먼저 머지(백엔드 계약 확정) 후 frontend가 실계약에 정합.
