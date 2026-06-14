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

### T-LANDING-WORKSPACE — landing(Jaspr) workspace 편입 결정
- **What:** Jaspr 랜딩을 (a) 별도 resolution으로 workspace 편입 vs (b) workspace 밖 독립 프로젝트로 둘지 P7에서 결정.
- **Why:** Jaspr↔Flutter 의존성 해석 충돌 위험으로 P1 workspace에서 제외됨.
- **Effort:** M (human) → S (CC) · **Priority:** P3 · **Depends on:** P7.

### T-CI-FLUTTER-PIN — CI flutter-action 버전 핀
- **What:** CI `subosito/flutter-action@v2`의 `channel: stable`을 Dart 3.12.1 호환 `flutter-version`으로 핀할지 최초 CI 실행 결과로 확정.
- **Why:** stable이 Dart 3.12.1 미만으로 드리프트하면 빌드 깨짐. (melos는 F2로 7.0.0 핀 완료.)
- **Effort:** S (human) → S (CC) · **Priority:** P2 · **Depends on:** 최초 CI green 확인.

## P2·P3 리뷰에서 도출 (2026-06-14)

### T-GOLDEN-CI-EXCLUDE — melos `test` 스크립트에 골든 제외 (P3-A)
- **What:** P1 Task 7의 melos `test` 스크립트를 `melos exec --dir-exists="test" -- flutter test --exclude-tags golden`로 갱신. 골든은 `dart_test.yaml`에 `tags: {golden: {}}` 선언 + 동일 플랫폼(ubuntu) 전용 job에서 `flutter test --tags golden`으로만 검증.
- **Why:** 픽셀 골든은 OS/폰트 렌더러 종속 → Windows 로컬 생성 골든이 ubuntu CI(`melos run test`)에서 깨짐. P3 Task 8이 골든을 도입하므로 P3 착수 전(또는 동시) P1 스크립트 1줄 갱신 필요.
- **Context:** P1은 이미 리뷰·커밋(브랜치). main 머지 전이면 P1 커밋에 직접 반영, 머지 후면 별도 커밋. P3 Task 8 Step 1에 태그·dart_test.yaml·FontLoader 반영 완료.
- **Effort:** S (human) → S (CC) · **Priority:** P1(P3 골든 게이트) · **Depends on:** P3 Task 8.
