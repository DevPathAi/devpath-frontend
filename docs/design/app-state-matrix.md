# 앱 상태 matrix (apps/web)

> N02(2026-09-17). 8개 화면의 loading / empty / error / partial 상태와 복구 행동을 공용 primitive 로 통일했다.
> 계약 테스트: `apps/web/test/app/state_matrix_contract_test.dart`. primitive 테스트: `packages/dp_design/test/states/`.

## 규칙

- **전체화면 상태**는 `DpLoading`(라벨은 liveRegion 으로 읽힘) · `DpEmpty` · `DpError`(문의 진입점이 필요하면 `SupportableError`) 만 쓴다.
- **데이터를 유지한 채 보이는 인라인 실패·경고**(부분 실패, 저장 실패, stale) 는 `DpInlineNotice` 하나로 표현한다. 톤은 `danger`(사용자 행동이 실패) / `warning`(보조 정보 누락·연결 끊김) / `info`.
- 새 primitive 는 두 화면 이상에서 같은 의미가 있을 때만 만든다. `DpInlineNotice` 가 그 조건(5개 화면의 손수 만든 배너)을 충족한 유일한 신설이다.
- 전체화면 실패 상태는 반드시 재시도 또는 복귀 행동을 가진다.

## 화면별 matrix

| 화면 | loading | empty | error(전체화면) | partial / 인라인 | 복구 행동 |
|---|---|---|---|---|---|
| Login | `DpLoading('세션을 확인하는 중')` — 세션 복원(`AuthLoading`) 중 버튼 대신 표시 | — | — | `DpInlineNotice`(`AuthUnauthenticated.error`) | 로그인 버튼 유지 |
| Auth callback | `DpLoading('로그인을 확인하는 중')` | — | 복구 카드(기존) | — | 로그인 다시 확인 / 진단 결과로 돌아가기 |
| Diagnostic | `DpLoading('진단을 준비하고 있어요' · '다음 문항을 불러오고 있어요')` | — | `DpInlineNotice`(guestExpired·ownership 등 전체 실패) | `DpInlineNotice`(answer·initialLoad 실패) + 문항 유지 | retryLastAnswer / retryAdvance / restart |
| Today | `DpLoading('오늘의 미션을 불러오는 중')`, 보조 지표 `DpLoading` | `DpEmpty('아직 학습 경로가 없어요')` | `DpError`(미션 로드 실패·malformed) | `DpInlineNotice`(완료 저장·새로고침 실패), 보조 지표 `warning` + '지표 다시 보기' | invalidateAndRefetch / dashboard load |
| Path | `DpLoading` · SSE 단계(`DpSseStageView`) | 경로 없음 → 경로 생성 | `SupportableError`(생성 실패·kill switch) | `DpInlineNotice`(stale 실패, 상세 불일치 `warning`), `_PlanEnrichmentStatus` | 다시 생성 / 미션 다시 확인 / 경로 상세 재시도 |
| Community | `DpLoading` | `DpEmpty`(글 없음·검색 결과 없음) | `SupportableError` + 다시 시도 | 검색 실패 `SupportableError` | load / 검색 재시도 |
| Content | `DpLoading` | — | `SupportableError` | `DpInlineNotice`('콘텐츠 다시 불러오기' · '진행률 저장 다시 시도') | _loadContent / _retryFailedProgress |
| Sandbox | `DpLoading`(미션·맥락·편집기 준비) | `DpEmpty`(런타임 중립·로그·리뷰 없음) | `DpError`(미션·맥락 로드 실패) | 실행 로그 내 오류 | invalidateAndRefetch |
| Mentor | 답변 스트리밍 inline 진행 | `DpEmpty('첫 질문을 해보세요')` | `DpInlineNotice`(failed) | `DpInlineNotice`(`warning`, 부분 답변 보존 + '다시 시도') | retry |

## 회귀 방지

- 원시 `Center(child: CircularProgressIndicator())` 와 `danger.withValues(alpha: 0.08)` 손수 배너가 8개 화면 소스에 다시 들어오면 계약 테스트가 실패한다.
- Q/A 상세의 `SupportableError` 는 `onRetry` 없이 쓸 수 없다.
