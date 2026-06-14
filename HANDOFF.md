# HANDOFF — React→Flutter 전환 & 프로토 UI

> 최종 업데이트: 2026-06-14 · 브랜치: `docs/flutter-migration-proto-ui-spec` (main 앞 19커밋, **미푸시**)
> 이 문서는 다음 세션 재개용. 작업은 전부 **문서(스펙·플랜)** 단계이며 구현 코드는 아직 없음.

## 지금까지 (DONE)

- **스펙**: `docs/superpowers/specs/2026-06-14-react-to-flutter-and-proto-ui-design.md` (전환 B′ + 디자인 DD1~DD8)
- **디자인 SSoT**: `DESIGN.md` · **리뷰 요약**: `docs/superpowers/specs/2026-06-14-design-review-summary.md`
- **플랜 (모두 작성 완료)**:
  - `P1` 모노레포 골격 — CEO+Eng CLEARED · melos `test` 골든 제외 반영
  - `P2` dp_core — 리뷰 반영(8fb4651) + **SseClient 에러 정규화 보강**(4035137, P4c-A)
  - `P3` dp_design — 리뷰 반영(8fb4651) + **DpIcons 추가**(4035137, P4c-B: code/expand 등)
  - **`P4a`~`P4f` = web 골든패스 전 화면**:
    - `P4a` 셸·인증·라우팅·다크토글 · `P4b` 온보딩·PATH SSE(DD8) · `P4c` 콘텐츠·Sandbox(Monaco·DD5·실행SSE)
    - `P4d` AI 리뷰(REV)+KILL_SWITCH/Quota · `P4e` 멘토 SSE · `P4f` 대시보드·커뮤니티(커서 페이지네이션)
  - **리뷰 상태**: `P4a~c`는 외부 리뷰 반영 완료(**4035137, 3건**: P4a-A 셸 테스트버그·P4c-A SseClient정규화·P4c-B DD3아이콘). **`P4d~f`는 작성 완료, 외부 리뷰 대기.**
  - ✅ **web 골든패스 완성**: 로그인→온보딩→PATH→콘텐츠→Sandbox→리뷰→멘토→대시보드→커뮤니티
- **TODOS**: `TODOS.md`
  - 활성: `T-DEPLOY-REINTRO`(P4/P5 배포) · `T-LANDING-WORKSPACE`(P7) · `T-CI-FLUTTER-PIN`(최초 CI 후)
  - 부분/반영: `T-GOLDEN-CI-EXCLUDE`🔶(골든 전용 job 남음) · `T-SSE-ERR-NORMALIZE`✅(P4c-A 반영, P2 SSE 에러 테스트 1개 잔여)

> **플랜 단계 누적 후속 (구현 시 보강):** ① SSE `id:`/`Last-Event-ID` 재개(P4b·P4e DD8 표준화) — 미등록. ② `MockHttpAdapter` query-aware 매칭(P4f 다중페이지 목) — 미등록. ③ `DpIcons` 잔여(thumb/send/edit/circle — P4d~f 임시 Material Icons, DD3) — P4c-B가 code/expand는 처리. (`ApiClient.post`=P4a, `SseClient` 정규화=P4c-A 반영 완료.)

## 다음 세션 (RESUME HERE)

**web(P4) 계획 완료(P4d~f 리뷰 대기).** 남은 건 **새 앱 3종**(각각 새 스코프):

1. **P5 — admin** (`apps/admin`=`devpath_admin`): 운영대시보드·사용자관리·신고처리. 데이터테이블·필터·커서페이지네이션·차트·**역할 가드(ADMIN/OWNER)**. dp_core/dp_design + go_router/riverpod 재사용(새 라이브러리 없음).
2. **P6 — mobile** (`apps/mobile`): 하단 5탭 셸(StatefulShellRoute) + 대시보드·알림센터·오프라인. **신규 라이브러리: drift·FCM·딥링크(`devpath://`)** → 착수 시 Context7. `mobile/`→`apps/mobile/` 이전 전제. eng-review 권장.
3. **P7 — landing** (Jaspr): SEO 정적 랜딩. **신규 프레임워크 Jaspr** → Context7. **workspace 편입 = `T-LANDING-WORKSPACE` 선결.**

- 착수(구현) 전 게이트: P4(web)/P6(mobile)는 `/plan-eng-review` 권장(스펙 VERDICT). 작성된 P4a~f가 그 리뷰 입력.

## 미작성 플랜

| 플랜 | 범위 | 비고 |
|------|------|------|
| P5 | admin 대표 3화면(운영대시보드·사용자관리·신고처리) | 테이블·차트·역할가드, 새 라이브러리 없음 |
| P6 | mobile 셸 + 대표 3화면(대시보드·알림·오프라인) | drift·FCM·딥링크(Context7), eng-review 권장 |
| P7 | landing (Jaspr) | 새 프레임워크, workspace 편입 T-LANDING-WORKSPACE 선결 |

> P4a~f는 작성 완료(P4d~f 리뷰 대기).

## 핵심 결정 (변경 시 스펙·플랜 동기화 필요)

- 구조: melos + Dart pub workspaces, 공유 `dp_core`(순수 Dart)·`dp_design`(Flutter) + 앱 3개, **화면 로직 앱별 소유**
- `dp_core` **순수 Dart**, melos test/analyze는 `--flutter`/`--no-flutter` 분기. SSE/HTTP 실패는 모두 `ApiException`으로 정규화(get/post/SseClient).
- 프로토 = **목 API**(SSE·에러까지), 범위 = 골든패스 + surface별 대표화면
- **web 스택**(P4a~f 확정): Riverpod 3(`Notifier`/`FamilyNotifier`) · go_router(`redirect`+`refreshListenable`) · `ApiConfig.useMock`+`MockHttpAdapter`. **web `dio` 직접 의존 금지**. SSE는 feature별 `*ConnectProvider` 주입. **Monaco는 conditional import**(`stub`/`web`). 커서 페이지네이션은 `Page<T>` + fetch 시ام. **위젯 테스트 폭 의존은 `tester.view.physicalSize`**(MediaQuery 래핑은 MaterialApp이 덮어씀 — P4a-A 교훈).
- CLAUDE.md Vitest 지침 → Flutter 테스트 스택으로 대체 예정(구현 시 갱신)

## 실행 옵션(플랜 실행 시)

- `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans`. **구현 순서 의존**: P1→P2→P3→P4a→…→P4f(→P5/P6/P7).
- 실행 시 실제 레포 변경: 구 React(`web/`,`admin/`) 제거 → Flutter 앱 생성, `mobile/`→`apps/mobile/` 이전, CI를 melos로 교체.
