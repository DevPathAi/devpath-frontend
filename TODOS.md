# TODOS — devpath-frontend

> cross-phase 보류 항목 추적. `/plan-ceo-review`(P1, 2026-06-14)에서 생성.
> Prime Directive: 보류는 적혀야 존재한다.

## P1 (모노레포 골격) 리뷰에서 도출

### ✅ T-DPCORE-PURE-DART — dp_core 순수 Dart 전환 [RESOLVED 2026-06-14]
- **결정:** **순수 Dart로 전환 확정**(사용자 승인). dp_core는 `flutter` 의존 없이 `package:test`/`dart test`, `lints` 사용. 스펙 §2 "순수 Dart" 준수.
- **반영:** P1 플랜 Task 2(`dart create --template=package`, 순수 Dart pubspec, `dart test`), Task 7 melos `analyze`/`test` 스크립트 `--flutter`/`--no-flutter` 분기, 스펙 §5(dp_core `flutter_test`→`test`).
- **부수효과(긍정):** dp_core가 `flutter_lints` 미사용 → E1(공유 의존성 정렬)은 Flutter 멤버 4개로 한정, 정렬 부담 감소.
- **Original Why:** 스펙 §2가 dp_core를 "순수 Dart, UI 없음"으로 규정. dio·freezed·json_serializable은 Flutter 불필요. P1 빈 골격일 때가 가장 싼 전환 시점이라 P2 전 결정함.

### T-DEPLOY-REINTRO — Flutter Web nginx 이미지·배포 P4/P5 재도입
- **What:** P1에서 제거된 web/admin Docker 이미지 빌드 + gitops 배포를 Flutter Web 산출물 기준으로 재도입.
- **Why:** P1이 React 전용 `web-image`/`admin-image`/`web-deploy`/`admin-deploy`를 삭제 → **web/admin 자동배포가 P1~P3 동안 중단(blackout)**. 수용됨(F5)이나 P4/P5에서 반드시 복구.
- **Context:** 빌드 산출물이 생기는 P4(web)/P5(admin) 시점. nginx 이미지 + kustomize gitops(기존 `DevPathAi/devpath-gitops`) 패턴 재사용.
- **Effort:** M (human) → S (CC) · **Priority:** P1(블로킹 — P4/P5 게이트) · **Depends on:** P4/P5 앱 빌드.

### ✅ T-LANDING-WORKSPACE — landing(Jaspr) workspace 편입 결정 [RESOLVED 2026-06-14]
- **결정:** (b) **워크스페이스 밖 독립 프로젝트(standalone)** — P7 플랜 채택. Jaspr↔Flutter 해석 충돌 회피 + 앱과 코드/상태 무공유(스펙 §10). `landing/`은 자체 pubspec·`dart pub get`, 루트 workspace members 비편입, 연결은 CTA URL뿐.
- **Why:** Jaspr↔Flutter 의존성 해석 충돌 위험으로 P1 workspace에서 제외됨.
- **Effort:** M (human) → S (CC) · **Priority:** P3 · **Depends on:** P7.

### 🔶 T-LANDING-CI — landing 전용 CI job (T-LANDING-WORKSPACE 부수)
- **What:** landing이 melos 밖 → `melos run test`에 미포함. P1 `ci.yml`에 landing 전용 job(`cd landing && dart pub get && dart test` + `jaspr build`) 추가.
- **Why:** standalone 결정의 필연 — 별도 해석이라 melos 일괄 검증 대상 아님. 미추가 시 landing이 CI에서 미검증.
- **Effort:** S (human) → S (CC) · **Priority:** P3 · **Depends on:** P7 구현 + 최초 CI.

### T-CI-FLUTTER-PIN — CI flutter-action 버전 핀
- **What:** CI `subosito/flutter-action@v2`의 `channel: stable`을 Dart 3.12.1 호환 `flutter-version`으로 핀할지 최초 CI 실행 결과로 확정.
- **Why:** stable이 Dart 3.12.1 미만으로 드리프트하면 빌드 깨짐. (melos는 F2로 7.0.0 핀 완료.)
- **Effort:** S (human) → S (CC) · **Priority:** P2 · **Depends on:** 최초 CI green 확인.

## P2·P3 리뷰에서 도출 (2026-06-14)

### 🔶 T-GOLDEN-CI-EXCLUDE — melos `test` 골든 제외 + 골든 전용 job (P3-A) [부분반영 2026-06-14]
- **What:**
  - ① P1 Task 7 melos `test` 스크립트를 `flutter test --exclude-tags golden`로 갱신 — **✅ 플랜 반영 완료**(P1 plan L418, 2026-06-14).
  - ② 골든을 실제 검증하는 동일-플랫폼(ubuntu) 전용 job(`flutter test --tags golden`)을 CI에 추가 — **⬜ 미반영**(P3 Task 8 구현 시 P1 `ci.yml`의 `analyze-test` 옆에 golden job 추가).
- **Why:** 픽셀 골든은 OS/폰트 렌더러 종속 → Windows 로컬 생성 골든이 ubuntu CI(`melos run test`)에서 깨짐. P3 Task 8이 골든을 도입.
- **Context:** P3 Task 8 Step 1에 `@Tags(['golden'])`·`dart_test.yaml`·FontLoader 반영 완료, melos `test`도 골든 제외로 갱신됨. 남은 건 골든을 **검증하는** 별도 job(현재 `melos run test`가 골든을 건너뛰므로 골든이 CI에서 한 번도 안 돌게 됨 → P3 구현 시 job 추가 필수).
- **Effort:** S (human) → S (CC) · **Priority:** P1(P3 골든 게이트) · **Depends on:** P3 Task 8 구현.

## P4 리뷰에서 도출 (2026-06-14)

### ✅ T-SSE-ERR-NORMALIZE — SseClient 에러 ApiException 정규화 (P4c-A) [반영 2026-06-14]
- **What:** dp_core `SseClient.connect`가 실패 시 `ApiException`을 throw하도록 보강(get/post 헬퍼 동일 규약).
- **반영:** P2 Task 7 sse_client.dart에 try/catch + `ApiException.fromDio` 정규화 추가(2026-06-14).
- **Why:** 미정규화 시 실서버 SSE 경로의 `SANDBOX_UNAVAILABLE`/`AI_KILL_SWITCH_ACTIVE`/`QUOTA_EXCEEDED`가 일반 오류로 처리됨 → P4c RunController·P4b PathController·P4d 멘토가 코드 분기 불가. 목 프로토는 영향 없으나 실서버 전환 시 필수.
- **잔여:** P2 SSE 테스트에 에러 정규화 케이스 1개 추가 권장(현재 200 스텁만). 실서버 SSE 단계별 에러(스트림 중간 503)는 전송 시작 후 발생 가능 — 스트림 내부 에러 정규화는 P4d 멘토 구현 시 재확인.
- **Effort:** S (human) → S (CC) · **Priority:** P2(실서버 전환 게이트) · **Depends on:** —
