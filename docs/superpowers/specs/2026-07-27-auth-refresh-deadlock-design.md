# 미인증 부팅 무한 스피너(AuthInterceptor 재진입 교착) 수정 설계

- 날짜: 2026-07-27
- 대상: `apps/{web,admin,mobile}` api_providers 배선 + `packages/dp_core` AuthInterceptor 회전 가드
- 관련: platform `docs/superpowers/specs/2026-07-27-refresh-rotate-grace-design.md`(서버측 1차 수정),
  gitops 런북 🔴 OPEN(동의화면 401)

## 1. 증상과 근본 원인 (운영 실측 2026-07-27)

**증상**: refresh 쿠키가 없거나 무효인 상태로 웹 앱을 열면 `/#/login`으로 리다이렉트되지 못하고
`/#/dashboard` 무한 스피너에 영구 고착된다. 콘솔에는 `/auth/refresh` 401 2건 + `/dashboard/me` 401.
사용자는 로그인 화면에 도달할 수 없어 어떤 진행도 불가능하다(서버에는 OAuth 시도 흔적조차 없음).

**근본 원인**: `AuthInterceptor`는 dio `QueuedInterceptor`(콜백 직렬화)인데, 앱 배선이
`refresh:`와 `retry:`를 **같은 dio 인스턴스**로 호출한다(web·admin·mobile 동일).
무인증 부팅 시: `bootstrapSession()`의 `/auth/refresh` 401 → onError[A] 진입 → A가 같은 dio로
`/auth/refresh` 재호출 → 이 요청도 401 → 그 에러 콜백이 **같은 큐에 enqueue되어 A가 끝나기를
대기** → A는 그 응답을 await → **순환 대기(교착)**. bootstrapSession Future가 영원히 미완결 →
인증 상태가 `AuthLoading`에 고정 → 라우터 게이트가 모든 리다이렉트를 보류(무한 스피너).

dp_core의 기존 테스트(`auth_interceptor_test.dart` '큐잉' 테스트)는 이 교착을 알고 있었고
**"재시도는 큐를 재진입하지 않도록 별도 dio로 수행 — 교착 방지"**라고 주석까지 달았지만,
실제 앱 배선은 같은 dio를 재진입한다.

쿠키가 **유효**할 때는 내부 refresh가 200(성공 경로는 에러 큐 미사용)이라 교착이 없어
지금까지 잠복했다. 서버 회전 유예창(1차 수정) 배포 후에도, 쿠키가 아예 없는 신규/로그아웃
방문자는 이 교착에 빠진다.

## 2. 수정

### 2.1 앱 배선 (web·admin·mobile 공통 패턴)

`authFlowClientProvider`(신규): **AuthInterceptor가 없는** 전용 `ApiClient`
(`ApiClient.create` = dio + 에러 정규화만). `refresh:` 콜백과 `retry:`를 이 클라이언트로 배선한다.

- web: `withCredentials=true` 설정 + 재시도 응답의 403 ONBOARDING_INCOMPLETE 의미 보존을 위해
  `OnboardingGateInterceptor`를 authFlow 클라이언트에도 장착. mock 모드면 MockHttpAdapter 동일 장착.
- admin: `withCredentials=true` + mock 어댑터 동일 장착 (OnboardingGate 없음 — 기존과 동일).
- mobile: 바디 기반 refresh 동일 이관 + mock 어댑터 동일 장착.

### 2.2 dp_core 회전 가드 보강

기존 가드는 `usedAuth != null`일 때만 "토큰이 이미 교체됨 → refresh 없이 재시도"를 적용한다.
**무토큰으로 발사된 요청**(부팅 직후 대시보드 fetch 등)의 401은 가드를 지나쳐 매번 refresh를
추가 발사한다. 가드를 `currentAccess != null && usedAuth != 'Bearer $currentAccess'`로 완화해
무토큰 요청도 이미 확보된 토큰으로 즉시 재시도하게 한다(불필요한 회전 제거).

### 2.3 비변경 (후속 백로그)

- `bootstrapSession` + `bootstrapFromCallback` 이중 직행 호출: 서버 유예창이 흡수(둘 다 200).
  single-flight 통합은 후속 정리.
- 첫 로드 시 무토큰 선발사 요청의 콘솔 401 잔상 1건: 기능 무해. 후속 정리.

## 3. 테스트 계획 (Test-First)

1. **web 배선 회귀**(`apps/web/test/providers/auth_interceptor_wire_test.dart`):
   모든 요청에 401을 돌려주는 어댑터를 main·authFlow 클라이언트에 주입 →
   `client.post('/auth/refresh')`가 **5초 안에 ApiException으로 완결**됨을 단언.
   (수정 전 = 교착으로 타임아웃/컴파일 실패 → RED)
2. **dp_core 가드**(`packages/dp_core/test/auth/auth_interceptor_test.dart`):
   무토큰 요청 401 + store에 현재 토큰 존재 → refresh 0회·`Bearer <현재>`로 재시도 단언. (RED)
3. admin/mobile: 기존 테스트 회귀 녹색 (동일 패턴 배선 교체).
4. `melos run analyze` + `melos run test` 전체 녹색.

## 4. 릴리스·검증

1. PR → develop(CI) → 머지 → develop→main 릴리스 PR → web 이미지 빌드 → ArgoCD.
2. **운영 재검증(헤드리스, 사용자 개입 없음)**: ① 쿠키 없는 부팅 → `/#/login` 도달(스피너 고착 없음)
   ② 유효 쿠키 주입 부팅 → 동의→진단 완주 ③ 콘솔에 교착성 401 루프 없음.
3. 사용자 최종 GitHub E2E는 위 자동 검증 통과 후 1회만 요청.
