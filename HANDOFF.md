# HANDOFF — React→Flutter 전환 & 프로토 UI

> 최종 업데이트: 2026-06-14 · 브랜치: `docs/flutter-migration-proto-ui-spec` (main 대비 8커밋, **미푸시**)
> 이 문서는 다음 세션 재개용. 작업은 전부 **문서(스펙·플랜)** 단계이며 구현 코드는 아직 없음.

## 지금까지 (DONE)

- **스펙**: `docs/superpowers/specs/2026-06-14-react-to-flutter-and-proto-ui-design.md`
  - 전환 아키텍처 **B′**(로그인 이후 Flutter Web + admin·mobile 100% Flutter + 랜딩만 Jaspr/Dart → 100% Dart)
  - 디자인 리뷰 DD1~DD8 본문 반영, 상태 매트릭스·반응형·a11y 포함
- **디자인 SSoT**: `DESIGN.md` · **리뷰 요약**: `docs/superpowers/specs/2026-06-14-design-review-summary.md`
- **플랜**:
  - `P1` 모노레포 골격 (`...-p1-monorepo-foundation.md`) — CEO+Eng 리뷰 **CLEARED**
  - `P2` dp_core 순수 Dart (`...-p2-dp-core.md`) — **외부 리뷰 대기**
  - `P3` dp_design (`...-p3-dp-design.md`) — **외부 리뷰 대기**
- **TODOS**: `TODOS.md` — `T-DPCORE-PURE-DART` 해소(순수 Dart 확정), 나머지 3건 추적
  - `T-DEPLOY-REINTRO`(P4/P5 배포 재도입) · `T-LANDING-WORKSPACE`(P7) · `T-CI-FLUTTER-PIN`(최초 CI 후)

## 다음 세션 (RESUME HERE)

1. **외부 리뷰 확인**: P2·P3에 대한 외부 리뷰(CEO/Eng 등) 결과를 받아 플랜에 반영.
2. **P4부터 이어서 작성**: web 골든패스 플랜. 큰 플랜이라 하위 분할 검토.
   - 착수 전 게이트: 아키텍처 영향 큰 **P4(web)/P6(mobile)는 `/plan-eng-review` 권장**(스펙 VERDICT).
3. 이후 **P5(admin) · P6(mobile) · P7(landing)** 순.

## 미작성 플랜

| 플랜 | 범위 | 비고 |
|------|------|------|
| P4 | web 골든패스(랜딩→OAuth→진단→경로SSE→콘텐츠→Sandbox+Monaco→리뷰→멘토SSE→대시보드→커뮤니티) | 最大, eng-review 권장 |
| P5 | admin 대표 3화면(운영대시보드·사용자관리·신고처리) | 테이블·차트·역할가드 |
| P6 | mobile 셸 + 대표 3화면(대시보드·알림·오프라인) | drift·FCM·딥링크, eng-review 권장 |
| P7 | landing (Jaspr) | workspace 편입 여부 T-LANDING-WORKSPACE에서 결정 |

## 핵심 결정 (변경 시 스펙·플랜 동기화 필요)

- 구조: melos + Dart pub workspaces, 공유 `dp_core`(순수 Dart)·`dp_design`(Flutter) + 앱 3개, **화면 로직 앱별 소유**
- `dp_core` **순수 Dart**(`package:test`/`dart test`, dio·freezed·json), melos test/analyze는 `--flutter`/`--no-flutter` 분기
- 프로토 = **목 API**(SSE·에러까지), 범위 = 골든패스 + surface별 대표화면
- CLAUDE.md의 Vitest 지침은 React 기준 → Flutter 테스트 스택으로 대체 예정(구현 시 CLAUDE.md 갱신)

## 실행 옵션(플랜 실행 시)

- P1~P3은 `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans`로 실행.
- 실행 시 실제 레포 변경 발생: 구 React(`web/`,`admin/`) 제거 → Flutter 앱 생성, `mobile/`→`apps/mobile/` 이전, CI를 melos로 교체(배포 잡은 P4/P5에서 재도입).
