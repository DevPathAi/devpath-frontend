# HANDOFF — React→Flutter 전환 & 프로토 UI

> 최종 업데이트: 2026-06-14 · 브랜치: `docs/flutter-migration-proto-ui-spec` (⚠️ P2 커밋 미푸시 — origin보다 앞섬)
> **상태: 설계·계획 + 디자인/Eng 리뷰 완료 + P1·P2 구현 완료(검증).** 다음은 **P3(dp_design)**.

## P2 구현 완료 (2026-06-14, 커밋 208deab~0f2c1d5 — 미푸시)
`packages/dp_core` 데이터 계층 TDD 완성(Task 1~10). **검증됨**: `melos run analyze`(전 멤버+dp_core No issues)·`melos run test`(dp_core 23 PASS, 전 멤버 SUCCESS).
- error(`ApiErrorCode`+`ApiException.fromDio`: network·429 Retry-After·503 kill-switch) · `Page<T>` 커서 · models(enum unknown fallback + freezed User, codegen 커밋) · `ApiConfig`/`ApiClient`(public dio·`create` 에러 인터셉터·`get`·**`sse()` D1**) · auth(`TokenStore`·`AuthInterceptor` QueuedInterceptor 401 단일 refresh+회전가드) · sse(`SseClient` 청크 재조립·`SseStage` 단일출처) · mock(**query-aware `MockHttpAdapter` D3**·`MockSseSource` **`failAfter`/`fromStep` D2**) · barrel.
- **P2 교훈**: ① freezed 3.x는 프리릴리스(`3.2.6-dev.1`)만 존재 — `^3.0.0` 핀으로 codegen 정상. ② `QueuedInterceptor`는 직렬화만 하고 dedup 안 함 → 동시 401 단일 refresh엔 **토큰 회전 가드** 필수, 재시도는 **별도 dio**로(같은 dio면 큐 교착). ③ Task 검증 시 test뿐 아니라 **analyze도** 실행(미사용 import 누락 방지).
- **서브에이전트 범위 이탈 사건**: 초기 1개 에이전트가 Task 2 후 플랜 없이 P2 전체를 자체 구조로 즉흥 구현 → reset 후 Task별 재구현. 재발 방지 규칙을 CLAUDE.md(절대 조건 4)·전역 `~/.claude/rules/subagent-scope.md`에 기재.

## P1 구현 완료 (2026-06-14, 커밋 b513eee~12cd1a9)
melos 7 + Dart pub workspaces 모노레포 골격: `packages/dp_core`(순수 Dart)·`dp_design`(Flutter) + `apps/{web,admin,mobile}` 5멤버 단일 해석. 구 React `web/`·`admin/` 제거, `mobile/`→`apps/mobile/`(이력 보존), CI를 melos analyze/test로 교체. **검증됨**: `melos run format`(0 changed)·`analyze`(No issues)·`test`(전 멤버 PASS, web은 cross-import 포함). 전 멤버 sdk `^3.12.1`·flutter_lints `^6.0.0` 정렬. melos 호출은 PATH 미설정 시 `dart pub global run melos <cmd>`.

## 지금까지 (DONE) — 플랜 작성 + 외부 리뷰 전부 완료

- **스펙**: `.../specs/2026-06-14-react-to-flutter-and-proto-ui-design.md` (전환 B′ + DD1~DD8) · **디자인 SSoT**: `DESIGN.md` · 리뷰요약: `.../design-review-summary.md`
- **플랜 (`docs/superpowers/plans/`)**: `P1` 골격 · `P2` dp_core · `P3` dp_design · `P4a~f` web 골든패스(셸·인증 / 온보딩·PATH SSE DD8 / 콘텐츠·Sandbox Monaco DD5 / AI리뷰·KILL_SWITCH·Quota / 멘토 SSE / 대시보드·커뮤니티) · `P5` admin · `P6` mobile(drift·FCM스텁·딥링크) · `P7` landing(Jaspr SSG, standalone)
- **외부 리뷰 전부 반영 완료**:
  - P2·P3: 8fb4651(7건)
  - P4a~c: 4035137(3건 — 셸 테스트버그·SseClient 정규화·DD3아이콘)
  - P4d~f: 73f5ca1(3건 — P4f-A 테스트 theme·P4f-B FamilyNotifier→Notifier·DD3 아이콘 일괄)
  - P5·P6·P7: 73cfe23(4건 — P7-A Document.lang 제거·P7-C config 분리·P7-D CSS·P6 아이콘)
- **TODOS** (`TODOS.md`): 활성 `T-DEPLOY-REINTRO`·`T-CI-FLUTTER-PIN` / 부분 `T-GOLDEN-CI-EXCLUDE`·`T-LANDING-CI` / 반영 `T-SSE-ERR-NORMALIZE`·`T-LANDING-WORKSPACE`(standalone)

## 다음 세션 (RESUME HERE) — 전체 리뷰 완료, 구현 시작

1. **✅ Eng Review 완료(2026-06-14)**: P4(web)·P6(mobile) 심층 리뷰 → 결정 D1~D4 승인 → 7개 플랜(P2·P4b~f·P6) 반영 완료. 요약: `docs/superpowers/specs/2026-06-14-eng-review-summary.md`. 결정: D1(P2 단일 SSE 기반 — `ApiClient.sse()`·`SseStage` 단일출처·`fromStep`), D2(DD8 핵심+`MockSseSource.failAfter`+60s, 재개키는 백엔드 합의까지 fromStep 보류), D3(query-aware `MockHttpAdapter`), D4(P6 재연결 동기화 최소+ConnectivityService, OAuth·secure_storage 이관). 필수수정 F4·F5·F6·F9는 해당 플랜에 반영됨.
2. **✅ P1·P2 완료** — 위 절들. 다음은 **P3(dp_design)**: `docs/superpowers/plans/2026-06-14-p3-dp-design.md`. `superpowers:subagent-driven-development`(권장). **순서 의존** P3→P4a→…→P4f→P5→P6→P7. **P2 Task 10(D1/D2/D3)이 P4b/c/e/f 착수 게이트 — 완료됨**(`apiClient.sse()`·`SseStage`·query-aware 목·`failAfter`/`fromStep`). 서브에이전트 위임 시 **범위 강제**(CLAUDE.md 절대 조건 4) + **컨트롤러 직접 검증**(커밋 범위·analyze·test) 필수.

## 구현 시 남은 결정/보강 (플랜에 노트로 명시됨)

- **dp_core**: ① SSE `id:`/`Last-Event-ID` 재개(P4b·P4e DD8) · ② `MockHttpAdapter` query-aware(P4f·P5 다중페이지·필터) · ③ `T-SSE-ERR-NORMALIZE` 잔여(SSE 스트림 중간 503 정규화, P4d 멘토 구현 시).
- **CI**: ④ 골든 전용 job(T-GOLDEN-CI-EXCLUDE) · ⑤ landing 전용 job(T-LANDING-CI).
- **mobile**: ⑥ 실 FCM(firebase_messaging+설정)·실 connectivity_plus(P6 스텁 대체).
- **landing**: ⑦ `<html lang="ko">` 주입 수단 — 설치 Jaspr의 `htmlAttributes` 지원 확인 또는 post-build 주입(P7-A, Task5 grep 게이트로 검증). P7-B(`testComponents`·`text()` 시그니처)도 설치본 확인.
- **DD3 아이콘 후속은 해소됨**(P4·P6 전부 DpIcons화, P3에 thumb/send/edit/dotSmall/downloadDone 등 추가).

## 핵심 결정 (변경 시 스펙·플랜 동기화)

- 구조: melos + Dart pub workspaces, `dp_core`(순수 Dart)·`dp_design`(Flutter) + 앱 3개. **landing은 워크스페이스 밖 독립**(Jaspr, standalone).
- 프로토 = **목 API**(SSE·에러 정규화 포함), 범위 = 골든패스 + surface별 대표화면.
- **공통 스택**: Riverpod 3 — **plain `Notifier`/`NotifierProvider` 통일**(family 베이스 미사용, P4f-B). go_router(web=`redirect`게이트·`refreshListenable`, mobile=`StatefulShellRoute`). `ApiConfig.useMock`+`MockHttpAdapter`. **앱은 `dio` 직접 의존 금지**. SSE는 feature별 `*ConnectProvider` 주입. **Monaco=conditional import** · **mobile 캐시=drift**(테스트 `NativeDatabase.memory`) · **landing=Jaspr SSG**.
- **위젯 테스트 폭 의존은 `tester.view.physicalSize`** + `context.dpColors` 쓰는 위젯 테스트엔 `theme: DpTheme.light()`(P4a-A·P4f-A 교훈).
- CLAUDE.md Vitest 지침 → Flutter 테스트 스택으로 대체(구현 시 갱신).

## 미작성 플랜

> 없음 — **P1~P7 전부 작성·리뷰 완료**. 다음은 eng-review·구현.
