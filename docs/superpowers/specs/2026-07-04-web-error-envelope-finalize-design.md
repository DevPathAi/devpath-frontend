# 설계: 축 A — 에러 envelope 프론트 정합 마무리

- 날짜: 2026-07-04
- 브랜치: `feat/web-error-envelope-finalize` (base: `develop`)
- 로드맵 위치: Tier-2 이후 A → C → B 중 **A**

## 배경

백엔드는 스펙 §3.4 공통 에러 envelope(`{"error":{"code","message","trace_id","timestamp"}}`)를 5개 svc에 표준화 완료했다. 프론트 `dp_core`는 이미:

- **파싱**: `ApiException.fromDio`가 중첩 `error.code/message/trace_id`를 파싱, `ApiErrorCode.fromWire`가 전 코드 매핑.
- **전송 배선**: `api_client`(인터셉터 + get/post 헬퍼), `sse_client.connect`가 모든 실패를 `ApiException`으로 정규화.
- **401 세션 갱신**: `auth_interceptor.dart` 큐잉 refresh.
- **온보딩 게이트**: `router.dart` `gateRedirect`가 캐시된 `onboardingStatus`로 리다이렉트.
- **상태 위젯**: `dp_design`의 `DpError`/`DpKillSwitch`/`DpQuota`, feature(review·path·mentor·sandbox)가 kill switch·quota 소비.

즉 이 조각은 큰 구축이 아니라 **잔여 정합을 감사로 확정하고, 계약을 골든으로 고정하고, 좁은 gap 1건을 채우는 마무리**다. 행동 변경 최소, 회귀 안전망 확보가 목표.

## 목표 / 비목표

**목표**
- 전 feature 에러 경로가 무음 소실 없이 표면화됨을 감사로 확정.
- 중첩 envelope 계약을 프론트 골든 테스트로 고정(백엔드 drift 조기 감지).
- 라이브 403 `ONBOARDING_INCOMPLETE`를 전역에서 잡아 온보딩으로 유도.

**비목표 (명시적 제외)**
- SSE 스트림 **중간** 에러 프레임 처리 → **축 C**(백엔드 R1 SSE 에러 계약 미확정).
- 백엔드 envelope/코드 변경(이미 표준화 완료).
- 실서버 부분 bootRun 스모크 → 축 C.
- OAuth 실 리다이렉트 e2e → 축 B(R4).

## 구성 — 3개 유닛(독립 검증 가능)

### 유닛 1 — 에러 표면화 감사 (코드 변경 0, 산출물=리포트)

- **무엇**: 전 feature 컨트롤러의 `catch`/에러 상태 경로를 훑어, `ApiException`이 무음 소실 없이 `dp_design` 상태나 명시적 에러 상태로 표면화되는지 표로 정리.
- **판정 기준**: 각 화면 × 해당 가능한 코드 {network, unauthorized(refresh 실패 후), forbidden, resourceNotFound, validationFailed, conflict, quota, killSwitch, internal} 이 사용자에게 보이는가.
- **산출물**: `docs/superpowers/reports/2026-07-04-web-error-surfacing-audit.md`.
- **후속**: 무음 실패 발견 시에만 유닛 3에 gap 항목 추가(YAGNI — 실제 발견분만). 발견이 예상보다 많으면 재-스코핑 위해 멈추고 보고.

### 유닛 2 — 중첩 envelope 골든 계약 테스트 (dp_core)

- **무엇**: 백엔드 §3.4 envelope 대표 payload 픽스처를 두고 `ApiException.fromDio` 매핑을 고정.
- **위치**: `packages/dp_core/test/error/api_exception_contract_test.dart` (기존 `api_exception_test.dart`와 분리 — "계약 골든" 전용).
- **커버**:
  - (a) 중첩 `{"error":{...}}` 정상 파싱(code·message·traceId·status).
  - (b) 각 `ErrorCode` wire 문자열 → enum 전 10종 + `unknown` 폴백.
  - (c) `trace_id` snake_case 파싱.
  - (d) 429 + `retry-after` 헤더 → `retryAfterSeconds`.
  - (e) 네트워크 타입(connectionTimeout 등) → `ApiErrorCode.network`.
  - (f) envelope 형태가 아닌 응답(비-Map/`error` 누락) 방어 폴백(`unknown` + 기본 메시지).
- **의도**: 백엔드가 envelope 형태를 바꾸면 이 테스트가 깨져 조기 감지. shared `ErrorResponse` Javadoc("이 형태 유지")과 짝을 이루는 프론트 측 앵커.

### 유닛 3 — 라이브 403 ONBOARDING_INCOMPLETE 전역 핸들러 (apps/web)

- **문제**: `ApiException.isOnboardingIncomplete` 플래그는 있으나 소비하는 곳이 없다. 라우터는 캐시된 `onboardingStatus`로만 게이팅 → 세션 중 서버가 403 `ONBOARDING_INCOMPLETE`를 주면 온보딩으로 유도되지 않는다.
- **해법**: `apps/web/lib/src/providers/api_providers.dart`의 `AuthInterceptor` 삽입 지점 옆에 형제 인터셉터(또는 onError 훅)를 추가. 응답 에러가 `ApiException.isOnboardingIncomplete`이면 `AuthController`의 신규 메서드 `markOnboardingIncomplete()`를 호출 → 현재 user의 `onboardingStatus`를 done이 아닌 값으로 강등 → `refreshListenable` 발화 → `gateRedirect`가 `/diagnostic`으로 유도.
- **레이어링**: 라우터/auth 반응은 앱 레벨에만 둔다. `dp_core`는 계속 라우터를 모른다(401 refresh 배선과 동일 패턴).
- **테스트**:
  - `AuthController.markOnboardingIncomplete()` 단위 — `AuthAuthenticated(done)` → `AuthAuthenticated(!done)` 전이, 비인증 상태에선 무동작.
  - 인터셉터 단위 — 403 `ONBOARDING_INCOMPLETE` 응답에서 강등 메서드 호출, 그 외 코드에선 미호출.

## 데이터 흐름 (유닛 3)

```
protected API → 403 {"error":{"code":"ONBOARDING_INCOMPLETE",...}}
  → api_client 인터셉터: DioException.error = ApiException(isOnboardingIncomplete)
  → onboarding 인터셉터(apps/web): isOnboardingIncomplete 감지
  → AuthController.markOnboardingIncomplete(): onboardingStatus 강등
  → routerProvider.refreshListenable 발화
  → gateRedirect: onboardingDone=false → '/diagnostic'
```

## 테스트 / 검증

- `flutter test`(dp_core + apps/web) 그린을 눈으로 확인.
- 감사 리포트 커밋.
- 브랜치 `feat/web-error-envelope-finalize` → `develop` PR(2단계 흐름). CI 그린 확인 후 머지.

## 리스크

- **R-A1**: 유닛 1 감사에서 예상보다 많은 무음 실패 발견 시 유닛 3 gap 증가 → 멈추고 재-스코핑 보고.
- **R-A2**: (해소) 강등 값은 기존 `OnboardingStatus.pending` 재사용(enum: `pending`/`inProgress`/`done`/`unknown` — [enums.dart:22](../../../packages/dp_core/lib/src/models/enums.dart)). enum 추가 불필요. `gateRedirect`는 `done`이 아니면 `/diagnostic`으로 보내므로 `pending` 강등으로 충분.
