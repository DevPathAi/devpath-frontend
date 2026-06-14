# 전체 플랜 횡단 재검토 — 문제점 정리 (P1~P7)

> 작성: 2026-06-14 · 대상: `docs/superpowers/plans/2026-06-14-p1..p7` 전체 + 스펙 + `DESIGN.md` + `TODOS.md`
> 성격: **문서 간 횡단(cross-cutting) 재검토** — 개별 플랜 리뷰(P1 CEO/Eng, P2~P7 문서리뷰)에서 이미 잡아 반영한 항목 외에, **여러 문서를 함께 봐야 드러나는 일관성·누락·실서버 게이트**를 모음.
> 검증 방식: 주장은 grep/Context7로 사실 확인(추측 금지). 이미 반영·해소된 항목은 제외.

## 0. 재검토로 확인된 "이상 없음"(오해 방지)
- **AuthInterceptor 결선**: P4b **Task 0**에서 `apiClientProvider`에 결선됨(ENG-REVIEW D1). 死코드 아님. ✅
- **스펙 §5 dp_core**: 이미 `test`(순수 Dart)로 갱신됨(T-DPCORE-PURE-DART 반영). ✅
- **freezed 3.x 일관**: P2 핀 `^3.0.0` + 전 feature 모델 `abstract class`(3.x) 정합. ✅
- **riverpod 3.3 / drift / Jaspr 0.22 / go_router**: Context7로 핵심 API 정합 확인(세부는 §D 설치본 재확인).

---

## A. 계획에 "한다"고 했으나 **구현 태스크가 없는 누락** (가장 위험 — 조용히 빠짐)

### A1. web/admin 배포 재도입 — 어떤 플랜에도 태스크 없음 〔BLOCKING〕
- **사실**: P1이 React 전용 `web-image`/`admin-image`/`web-deploy`/`admin-deploy`(Docker+gitops)를 제거. "P4/P5에서 재도입"이라 명시했으나 **P4a~f·P5 플랜 어디에도 nginx 이미지 빌드/gitops 배포 태스크가 없음**(grep 확인). `TODOS.md`의 `T-DEPLOY-REINTRO`로만 추적.
- **영향**: P1 머지 시점부터 web/admin **자동배포 영구 중단** — 누가 P4/P5에 태스크를 넣지 않으면 끝까지 미복구.
- **조치**: P4f(web 완성)·P5(admin 완성) 끝에 "Flutter Web → nginx 이미지 + 기존 `DevPathAi/devpath-gitops` kustomize 배포 재도입" 태스크 추가. (또는 별도 P8-deploy 플랜.)

### A2. 골든 검증 CI job 부재 — 골든이 CI에서 0회 실행 〔HIGH〕
- **사실**: P3가 골든에 `@Tags(['golden'])` + `dart_test.yaml` + melos `test`에 `--exclude-tags golden` 적용. 그러나 **골든을 실제 돌리는 동일-플랫폼(ubuntu) 전용 CI job은 어디에도 추가되지 않음**(grep: 언급만, 태스크 없음). `T-GOLDEN-CI-EXCLUDE ②`.
- **영향**: 골든 baseline이 CI에서 한 번도 검증되지 않아 부패(회귀 무방비). DD6 다크 시연의 의미 반감.
- **조치**: P1 `ci.yml`에 `golden` job(`flutter test --tags golden`, ubuntu 고정) 추가 — P3 구현 시 동반.

### A3. landing 전용 CI job 부재 〔MEDIUM〕
- **사실**: landing은 workspace 밖(standalone) → `melos run test` 미포함. 전용 CI job(`cd landing && dart test` + `jaspr build`)이 P1 `ci.yml`에 없음. `T-LANDING-CI`.
- **영향**: landing이 CI에서 미검증(빌드 깨짐 무방비).
- **조치**: P7 구현 시 P1 `ci.yml`에 landing job 추가.

---

## B. 목 프로토의 구조적 한계 (실서버 전환 게이트)

### B1. MockHttpAdapter 매칭이 `METHOD path` 리터럴 — 동적 id·쿼리 무시 〔HIGH(데모 체감)〕
- **사실**(P2 `mock_http_adapter.dart` L1114): `final key = '${options.method} ${options.path}'`. **경로 파라미터·쿼리스트링을 매칭에 쓰지 않음.**
- **영향(횡단)**:
  - **동적 id GET은 seeded id만 동작**: `GET /contents/c1`(P4c)·`GET /community/posts/q1`(P4f)은 리터럴 키라 **c1/q1만** 200, 그 외 id는 404→에러 상태. 커뮤니티 목록의 q2·q3를 탭하면 상세가 깨짐.
  - **쿼리 무시**: 커서(`cursor`)·필터(`status`)가 매칭에 반영 안 됨 → 앱 목은 항상 단일 페이지/무필터. 다중페이지·필터는 **컨트롤러 단위 테스트로만** 검증(P4f·P5가 자인).
- **조치**: dp_core `MockHttpAdapter`를 **경로 패턴(`/contents/:id`) + 쿼리 인지** 매칭으로 보강(T 후보). 또는 프로토 데모는 "seeded id만" 한계를 명시하고 목록을 seeded id로 제한.

### B2. SSE 에러 정규화 — 테스트 부재 + 스트림 중간 에러 미정규화 〔MEDIUM〕
- **사실**: P4c-A로 `SseClient.connect`가 **연결(POST) 시점** 실패를 `ApiException`으로 정규화하도록 보강했으나, (a) 그 경로의 **테스트가 없음**(P2 SSE 테스트는 200 happy만), (b) **스트림 시작 후 발생하는 에러**(전송 중 503/끊김)는 `await for` 내부라 정규화 범위 밖.
- **영향**: 실서버에서 스트림 도중 `AI_KILL_SWITCH_ACTIVE`/`QUOTA`가 오면 멘토(P4e)·PATH(P4b)·실행로그(P4c)가 일반 오류로 처리.
- **조치**: P2 SSE 테스트에 연결-실패 정규화 케이스 추가 + 스트림 내부 에러 매핑은 멘토(P4e) 실서버 연동 시 재설계. `T-SSE-ERR-NORMALIZE` 잔여.

---

## C. 검증 커버리지·일관성

### C1. 형식 eng-review 편차 〔MEDIUM〕
- **사실**: 정식 `/plan-eng-review`는 **P1만** 수행. P4b·P4f에 `ENG-REVIEW` 마커 존재(부분 반영). 나머지(P2·P3·P4a/c/d/e·P5·P6·P7)는 **이번 세션 문서리뷰**(Context7 사실검증 포함)만.
- **조치**: 구현 착수 전, 변경 누적분 기준 일괄 `/plan-eng-review` 1회 권장(특히 P5/P6/P7).

### C2. 풀 골든패스 E2E 부재 〔LOW〕
- 각 P4 하위 플랜이 자기 구간 스모크만 보유. login→온보딩→PATH→콘텐츠→Sandbox→리뷰→멘토→대시보드→커뮤니티를 한 번에 도는 통합 테스트 없음. (선택 — 구현 후 `integration_test`로.)

### C3. P5 사용자 필터 해제 불가 〔LOW, 자인〕
- `UsersState.copyWith`가 `statusFilter ?? this.statusFilter`라 null 해제 불가 → "필터 초기화"가 'ACTIVE' 기본값으로 동작. nullable sentinel copyWith로 보강 권장.

---

## D. 구현 시 설치본 재확인(라이브러리 lock 후)
Context7로 0.22.1/3.3.0/2.x 기준 확인했으나, `pubspec.lock` 확정 후 아래는 설치본 예제로 최종 정렬:
- **Jaspr 0.22**: `Document`의 `lang`(없음 → htmlAttributes/post-build) · `testComponents` vs `testClient/testServer` · `text()` vs `.text()` · `Jaspr.initializeApp` · `main_` 헬퍼.
- **riverpod 3.3**: family notifier 베이스(P4f는 plain Notifier로 회피 완료).
- **drift_flutter**: `driftDatabase(name:)` · 위젯테스트 `DatabaseConnection(closeStreamsSynchronously:true)`(watch 스트림 추가 시).
- **freezed 3.x**: codegen 산출물 커밋 규약.
- **go_router 14.x**: `StatefulShellRoute.indexedStack` · `refreshListenable` 패턴.

---

## 우선순위 요약
| 순위 | 항목 | 성격 | 추적 |
|---|---|---|---|
| 1 | A1 배포 재도입 태스크 누락 | 계획 누락(영구 미배포) | T-DEPLOY-REINTRO |
| 2 | A2 골든 CI job 부재 | 계획 누락(골든 0회 검증) | T-GOLDEN-CI-EXCLUDE② |
| 3 | B1 Mock 동적id·쿼리 무시 | 목 한계(데모/실서버) | (신규 T 후보) |
| 4 | A3 landing CI job 부재 | 계획 누락 | T-LANDING-CI |
| 5 | B2 SSE 에러 정규화 테스트/스트림중 | 실서버 게이트 | T-SSE-ERR-NORMALIZE |
| 6 | C1 일괄 eng-review | 검증 커버리지 | — |
| 7 | C2·C3·D | 보강·확인 | — |
