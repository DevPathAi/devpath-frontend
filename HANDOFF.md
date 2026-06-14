# HANDOFF — React→Flutter 전환 & 프로토 UI

> 최종 업데이트: 2026-06-14 · 브랜치: `docs/flutter-migration-proto-ui-spec` (main 앞 23커밋, **미푸시**)
> **상태: 설계·계획 단계 전체 완료(P1~P7 플랜 작성됨).** 구현 코드는 아직 없음 — 다음은 리뷰 → 구현.

## 지금까지 (DONE) — 플랜 전체 작성 완료

- **스펙**: `.../specs/2026-06-14-react-to-flutter-and-proto-ui-design.md` (전환 B′ + DD1~DD8) · **디자인 SSoT**: `DESIGN.md` · 리뷰요약: `.../design-review-summary.md`
- **플랜 (`docs/superpowers/plans/`)**:
  - `P1` 모노레포 골격 — 리뷰 CLEARED
  - `P2` dp_core(순수 Dart) · `P3` dp_design — 리뷰 반영(8fb4651) + P4 리뷰 보강(4035137: SseClient 정규화·DpIcons)
  - `P4a~f` **web 골든패스 전 화면**: a 셸·인증 · b 온보딩·PATH SSE(DD8) · c 콘텐츠·Sandbox(Monaco·DD5) · d AI리뷰·KILL_SWITCH/Quota · e 멘토 SSE · f 대시보드·커뮤니티
  - `P5` admin(역할가드·테이블·제재·신고) · `P6` mobile(5탭·drift·FCM스텁·딥링크) · `P7` landing(Jaspr SSG·SEO, standalone)
- **리뷰 상태**: `P4a~c`만 외부 리뷰 반영 완료(4035137). **`P4d·e·f`·`P5`·`P6`·`P7`은 외부 리뷰 대기.**
- **TODOS** (`TODOS.md`):
  - 활성: `T-DEPLOY-REINTRO`(P4/P5 배포) · `T-CI-FLUTTER-PIN`(최초 CI)
  - 부분/반영: `T-GOLDEN-CI-EXCLUDE`🔶 · `T-SSE-ERR-NORMALIZE`✅(4035137) · `T-LANDING-WORKSPACE`✅(standalone) · `T-LANDING-CI`🔶(landing 전용 job)

## 다음 세션 (RESUME HERE) — 계획 완료, 리뷰→구현 단계

1. **외부 리뷰 반영**: `P4d~f`·`P5`·`P6`·`P7`을 (4035137처럼) 외부 리뷰하고 반영. 누적 후속(아래) 함께 정리.
2. **eng-review 게이트**: 아키텍처 영향 큰 **P4(web)·P6(mobile)** 는 구현 착수 전 `/plan-eng-review` 권장(스펙 VERDICT).
3. **구현 시작**: `superpowers:subagent-driven-development`(권장). **순서 의존** P1→P2→P3→P4a→…→P4f→P5→P6→P7. 첫 실제 레포 변경(구 React 제거·Flutter 앱 생성·mobile 이전·CI melos 교체)은 P1.

## 구현 시 보강 필요 (플랜 단계 누적 후속)

- **dp_core**: ① `SseClient` 스트림 중간 에러 정규화 재확인(P4d 멘토, T-SSE-ERR-NORMALIZE 잔여) · ② SSE `id:`/`Last-Event-ID` 재개(P4b·P4e DD8 표준화, 미등록) · ③ `MockHttpAdapter` query-aware(P4f·P5 다중페이지·필터, 미등록).
- **dp_design**: ④ `DpIcons` 잔여 아이콘(thumb/send/edit/circle/cloud_off 등 — P4d~f·P6 임시 Material Icons, DD3). (code/expand는 4035137 처리.)
- **CI**: ⑤ 골든 전용 job(T-GOLDEN-CI-EXCLUDE) · ⑥ landing 전용 job(T-LANDING-CI).
- **mobile**: ⑦ 실 FCM(firebase_messaging+Firebase 설정) · 실 connectivity_plus(P6 스텁 대체).

## 핵심 결정 (변경 시 스펙·플랜 동기화)

- 구조: melos + Dart pub workspaces, `dp_core`(순수 Dart)·`dp_design`(Flutter) + 앱 3개. **landing은 워크스페이스 밖 독립**(Jaspr, T-LANDING-WORKSPACE=standalone).
- 프로토 = **목 API**(SSE·에러 정규화 포함), 범위 = 골든패스 + surface별 대표화면.
- **공통 스택**: Riverpod 3(`Notifier`/`FamilyNotifier`) · go_router(web=`redirect`게이트·`refreshListenable`, mobile=`StatefulShellRoute`) · `ApiConfig.useMock`+`MockHttpAdapter`. **앱은 `dio` 직접 의존 금지**(dp_core 헬퍼). SSE는 feature별 `*ConnectProvider` 주입. **Monaco=conditional import** · **mobile 캐시=drift**(테스트 `NativeDatabase.memory`) · **landing=Jaspr SSG**.
- **위젯 테스트 폭 의존은 `tester.view.physicalSize`**(MediaQuery 래핑은 MaterialApp이 덮음 — P4a-A 교훈).
- CLAUDE.md Vitest 지침 → Flutter 테스트 스택으로 대체(구현 시 갱신).

## 미작성 플랜

> 없음 — **P1~P7 전부 작성 완료**. 다음은 리뷰·구현.
