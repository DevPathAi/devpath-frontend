# HANDOFF — React→Flutter 전환 & 프로토 UI

> 최종 업데이트: 2026-06-14 · 브랜치: `docs/flutter-migration-proto-ui-spec` (main 앞 14커밋, **미푸시**)
> 이 문서는 다음 세션 재개용. 작업은 전부 **문서(스펙·플랜)** 단계이며 구현 코드는 아직 없음.

## 지금까지 (DONE)

- **스펙**: `docs/superpowers/specs/2026-06-14-react-to-flutter-and-proto-ui-design.md`
  - 전환 아키텍처 **B′**(로그인 이후 Flutter Web + admin·mobile 100% Flutter + 랜딩만 Jaspr/Dart → 100% Dart)
  - 디자인 리뷰 DD1~DD8 본문 반영, 상태 매트릭스·반응형·a11y 포함
- **디자인 SSoT**: `DESIGN.md` · **리뷰 요약**: `docs/superpowers/specs/2026-06-14-design-review-summary.md`
- **플랜**:
  - `P1` 모노레포 골격 — CEO+Eng 리뷰 **CLEARED** · melos `test` 골든 제외 반영(T-GOLDEN-CI-EXCLUDE 부분해소)
  - `P2` dp_core 순수 Dart — **리뷰 반영 완료**(8fb4651: P2-A·B·C)
  - `P3` dp_design — **리뷰 반영 완료**(8fb4651: P3-A·B·C·D)
  - `P4a` web 셸·인증·라우팅 — **작성 완료**(go_router 게이트·반응형 셸·OAuth목·다크토글)
  - `P4b` 온보딩·진단 + 학습경로 SSE(PATH-001) — **작성 완료**(DD8 중단보존·이어하기, dp_core LearningPath)
  - `P4c` 콘텐츠 뷰어 + Sandbox(Monaco·실행SSE·DD5 반응형) — **작성 완료**(Monaco conditional import, 3/2/1 페인, SANDBOX_UNAVAILABLE) · **REV-001은 미포함→P4d**
- **TODOS**: `TODOS.md` — `T-DPCORE-PURE-DART` 해소. 추적 4건:
  - `T-DEPLOY-REINTRO`(P4/P5 배포 재도입) · `T-LANDING-WORKSPACE`(P7) · `T-CI-FLUTTER-PIN`(최초 CI 후) · `T-GOLDEN-CI-EXCLUDE`(부분반영 — 골든 검증 전용 job, P3 구현 시)

> **플랜 단계 누적 후속(구현 시 dp_core 보강 필요, P2 패턴):** ① `ApiClient.post`(P4a 추가됨) ② `SseClient.connect` 실패를 `ApiException`으로 정규화(P4c가 요구 — web dio-free 유지). ③ SSE `id:`/`Last-Event-ID` 재개(P4b DD8 표준화).

## 다음 세션 (RESUME HERE)

P2·P3 리뷰 반영 완료, P4는 분할 진행 중 — **P4a·P4b·P4c 작성 완료**. 다음:

1. **P4d 작성**: **REV-001 AI 코드리뷰**(신뢰도·잘한점·개선[라인·심각도]·보안 + 👍👎) — P4c SandboxPage의 `_ReviewPlaceholder` 칸을 채움. **+ KILL_SWITCH/Quota 상태 일괄 처리**(`DpKillSwitch`/`DpQuota`, P4b·P4c가 통합 지점 명시). 리뷰 모델은 dp_core freezed.
2. 이후 **멘토 SSE(MEN-001) · 대시보드(DASH-001) · 커뮤니티(COM-001/003)** → 규모 보고 **P4e+로 분할**(MEN은 SSE라 단독 가능, DASH+COM 묶음 등).
3. 그다음 **P5(admin) · P6(mobile) · P7(landing)**.
   - 착수(구현) 전 게이트: 아키텍처 영향 큰 **P4(web)/P6(mobile)는 `/plan-eng-review` 권장**(스펙 VERDICT). P4a~ 전부 그 리뷰 입력 문서.

## 미작성 플랜

| 플랜 | 범위 | 비고 |
|------|------|------|
| ~~P4a~~ | web 셸·인증·라우팅·다크토글 | ✅ 작성 완료 |
| ~~P4b~~ | 온보딩·진단 + 학습경로 SSE(PATH-001) | ✅ 작성 완료(DD8 이어하기) |
| ~~P4c~~ | 콘텐츠 뷰어 + Sandbox(Monaco·실행SSE·DD5) | ✅ 작성 완료(REV 제외) |
| P4d | AI 코드리뷰(REV-001) + KILL_SWITCH/Quota | SBX 리뷰칸 채움, dp_design 위젯 존재 |
| P4e+ | 멘토 SSE(MEN-001) · 대시보드(DASH-001) · 커뮤니티(COM-001/003) | 규모 보고 분할 |
| P5 | admin 대표 3화면(운영대시보드·사용자관리·신고처리) | 테이블·차트·역할가드 |
| P6 | mobile 셸 + 대표 3화면(대시보드·알림·오프라인) | drift·FCM·딥링크, eng-review 권장 |
| P7 | landing (Jaspr) | workspace 편입 여부 T-LANDING-WORKSPACE에서 결정 |

## 핵심 결정 (변경 시 스펙·플랜 동기화 필요)

- 구조: melos + Dart pub workspaces, 공유 `dp_core`(순수 Dart)·`dp_design`(Flutter) + 앱 3개, **화면 로직 앱별 소유**
- `dp_core` **순수 Dart**(`package:test`/`dart test`, dio·freezed·json), melos test/analyze는 `--flutter`/`--no-flutter` 분기
- 프로토 = **목 API**(SSE·에러까지), 범위 = 골든패스 + surface별 대표화면
- **web 스택**(P4a~c 확정): Riverpod 3(`Notifier`/`NotifierProvider`) · go_router(`redirect`+`refreshListenable`) · `ApiConfig.useMock`+`MockHttpAdapter`. **web은 `dio` 직접 의존 금지**(dp_core 헬퍼 경유). SSE는 feature별 `*ConnectProvider`로 목/실서버 주입 교체. **Monaco는 conditional import**(`stub`/`web` — `dart:ui_web`+`package:web`+`dart:js_interop`, index.html JS 셈)로 web 격리.
- CLAUDE.md의 Vitest 지침은 React 기준 → Flutter 테스트 스택으로 대체 예정(구현 시 CLAUDE.md 갱신)

## 실행 옵션(플랜 실행 시)

- P1~P4x는 `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans`로 실행. **단 구현은 P1→P2→P3→P4a→P4b→P4c… 순서 의존**.
- 실행 시 실제 레포 변경 발생: 구 React(`web/`,`admin/`) 제거 → Flutter 앱 생성, `mobile/`→`apps/mobile/` 이전, CI를 melos로 교체(배포 잡은 P4/P5에서 재도입).
