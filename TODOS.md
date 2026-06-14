# TODOS — devpath-frontend

> cross-phase 보류 항목 추적. `/plan-ceo-review`(P1, 2026-06-14)에서 생성.
> Prime Directive: 보류는 적혀야 존재한다.

## P1 (모노레포 골격) 리뷰에서 도출

### T-DPCORE-PURE-DART — dp_core를 순수 Dart 패키지로 재검토
- **What:** dp_core를 Flutter 의존(`flutter_test`) 대신 순수 Dart(`package:test`, `dart test`)로 전환할지 P2 착수 전 재검토.
- **Why:** 스펙 §2가 dp_core를 "순수 Dart, UI 없음"으로 규정. P1은 툴링 균일(전멤버 `flutter test`)을 위해 Flutter 패키지로 둠(스펙 §5 결정). 그러나 도메인/데이터 계층이 Flutter에 결합되면 서버·CLI·백엔드 공유 등 순수 Dart 재사용이 막힘. dp_core에 들어갈 dio·freezed·json_serializable은 Flutter 불필요.
- **Cons(전환 시):** 테스트 명령이 멤버별 이질(`dart test` vs `flutter test`) → `melos exec` 필터 필요. 스펙 §5 갱신.
- **Context:** P1은 빈 골격뿐이라 지금이 가장 싼 전환 시점. 코드가 쌓이는 P2 이후엔 one-way door에 가까워짐.
- **Effort:** S (human) → S (CC) · **Priority:** P2 · **Depends on:** P2 착수 전 결정.

### T-DEPLOY-REINTRO — Flutter Web nginx 이미지·배포 P4/P5 재도입
- **What:** P1에서 제거된 web/admin Docker 이미지 빌드 + gitops 배포를 Flutter Web 산출물 기준으로 재도입.
- **Why:** P1이 React 전용 `web-image`/`admin-image`/`web-deploy`/`admin-deploy`를 삭제 → **web/admin 자동배포가 P1~P3 동안 중단(blackout)**. 수용됨(F5)이나 P4/P5에서 반드시 복구.
- **Context:** 빌드 산출물이 생기는 P4(web)/P5(admin) 시점. nginx 이미지 + kustomize gitops(기존 `DevPathAi/devpath-gitops`) 패턴 재사용.
- **Effort:** M (human) → S (CC) · **Priority:** P1(블로킹 — P4/P5 게이트) · **Depends on:** P4/P5 앱 빌드.

### T-LANDING-WORKSPACE — landing(Jaspr) workspace 편입 결정
- **What:** Jaspr 랜딩을 (a) 별도 resolution으로 workspace 편입 vs (b) workspace 밖 독립 프로젝트로 둘지 P7에서 결정.
- **Why:** Jaspr↔Flutter 의존성 해석 충돌 위험으로 P1 workspace에서 제외됨.
- **Effort:** M (human) → S (CC) · **Priority:** P3 · **Depends on:** P7.

### T-CI-FLUTTER-PIN — CI flutter-action 버전 핀
- **What:** CI `subosito/flutter-action@v2`의 `channel: stable`을 Dart 3.12.1 호환 `flutter-version`으로 핀할지 최초 CI 실행 결과로 확정.
- **Why:** stable이 Dart 3.12.1 미만으로 드리프트하면 빌드 깨짐. (melos는 F2로 7.0.0 핀 완료.)
- **Effort:** S (human) → S (CC) · **Priority:** P2 · **Depends on:** 최초 CI green 확인.
