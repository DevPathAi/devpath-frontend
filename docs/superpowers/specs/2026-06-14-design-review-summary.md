# 디자인 리뷰 개선 내용 — React→Flutter 프로토 UI 스펙

> 원본 플랜: [`2026-06-14-react-to-flutter-and-proto-ui-design.md`](./2026-06-14-react-to-flutter-and-proto-ui-design.md)
> 리뷰: `/plan-design-review` (2026-06-14) · 디자인 완성도 **5/10 → 8/10** · 8개 결정 확정 · 미해결 0

## 차원별 개선 (Before → After)

| Pass | 차원 | 점수 | 무엇을 고쳤나 |
|---|---|---|---|
| 1 | 정보구조 | 7→8 | 화면별 위계(대시보드: 스트릭→진행률→단일 CTA→배지)를 와이어프레임에서 플랜 텍스트로 코드화 |
| 2 | 상태 커버리지 | 4→8 | **상태 테이블(§9.2)** 신설 — 9개 기능 × Loading/Empty/Error/Success/Partial을 "사용자가 보는 것" 기준으로 명세 |
| 3 | 유저 저니 | 6→8 | 1st Aha(SSE 4단계) 중단 시 **단계 보존+이어하기**로 첫 인상 신뢰 보존 |
| 4 | AI 슬롭 | 5→8 | 인디고 대비 분리 · Roboto→Pretendard · 이모지→Material Symbols · path 좌측 컬러보더 정리 |
| 5 | 디자인 시스템 | 3→9 | **DESIGN.md 신규** — 토큰 단일 출처(색·타이포·간격·반응형·a11y·모션) |
| 6 | 반응형·접근성 | 3→8 | breakpoint 값 확정 · SBX collapse 명세 · a11y 베이스라인 명문화 |

## 확정된 8개 디자인 결정 (DD1~DD8)

| # | 무엇을 바꿨나 | 해결한 문제 |
|---|---|---|
| **DD1** | 인디고 fill 유지 + 텍스트는 indigo-600/700 분리 | `#6366f1`/white ≈3.9:1 → **WCAG AA(4.5:1) 미달** 해결 |
| **DD2** | 본문 Pretendard + 코드 D2Coding | 한글 렌더 빈약한 기본 Roboto 폐기, 한글 우선 |
| **DD3** | Material Symbols 단일 아이콘셋 | 이모지 디자인요소(슬롭#7)·플랫폼별 렌더 불일치 제거 |
| **DD4** | AI `KILL_SWITCH` 전용 '점검 중' 상태 + 대체 행동 | 핵심 가치 다운 순간을 일반 에러로 방치하던 갭 |
| **DD5** | SBX 데스크톱 3-페인 / 모바일웹 1-페인 세그먼트 탭 | 375px에 3열을 그대로 축소해 깨지는 위험 |
| **DD6** | 전역 라이트/다크 토글 프로토 포함 | surface별 다크모드 동작 무명세 *(권장보다 넓게 채택)* |
| **DD7** | a11y 베이스라인 명문화 | 대비·44px·Monaco Esc 탈출·SSE `aria-live`·랜드마크 전무했음 |
| **DD8** | SSE 중단 시 단계 보존 + 재연결/이어하기 | 네트워크·60s 타임아웃 중단 시 전체 재시작 강요 문제 |

## 구체적 명세 추가물

- **컬러 토큰 분리**: `primary`(fill #6366f1) vs `primaryText`(#4f46e5) vs `primaryTextStrong`(#4338ca) — 면 전용/텍스트 전용 구분.
- **Breakpoint 값**: Compact <600 / Medium 600–839 / Expanded 840–1239 / Large ≥1240. 내비 레일 전환점 840, SBX 3-페인 전환점 1240.
- **한글 line-height**: 본문 1.6, 제목 1.3 명시.
- **신규 상태 위젯**: KillSwitch · Quota(429+Retry-After) · SandboxUnavailable · OfflineBanner · SSE 6단계 상태.

## 산출 태스크 (구현용 — 플랜 §12)

P1 5건 · P2 2건:
- **T1 (P1)** dp_design 토큰을 Material3 ThemeExtension으로 코드화(라이트+다크·Pretendard/D2Coding·8pt·라운드)
- **T2 (P1)** KillSwitch·Quota·SandboxUnavailable·Offline·SSE단계 상태 위젯
- **T3 (P1)** SBX 반응형(데스크톱 3-페인 / 모바일웹 1-페인 세그먼트 탭)
- **T4 (P1)** a11y 베이스라인(대비·44px·키보드·Monaco Esc·SSE aria-live·랜드마크)
- **T5 (P1)** SSE 중단 시 단계 보존+재연결/이어하기
- **T6 (P2)** 이모지→Material Symbols 교체
- **T7 (P2)** 빈 상태 카피·1차행동 일괄 적용

## NOT in scope (명시적 보류)

랜딩(Jaspr) 표현형 디자인 · 차별화 브랜드 색 탐색(/design-shotgun) · 커스텀 아이콘셋 · 고급 모션 · 결제(PAY) 화면.

## 남은 리스크

- **DD6(다크 전역 토글)**: 모든 골든 화면·상태위젯의 다크 변형 디자인 + golden 테스트를 2배로 만든다 — 구축 §6 일정에 반영 필요.
- **Eng Review(필수 게이트) 미실행**: DD5(반응형)·DD6(다크)·DD8(SSE 재연결)은 아키텍처 영향 → 구현 착수 전 `/plan-eng-review` 권장.
