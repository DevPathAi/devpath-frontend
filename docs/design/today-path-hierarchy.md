# Today / Path 정보 위계와 폭별 구성

> N05(2026-09-17). Today(`/dashboard`)와 Path(`/path`)를 `다음 행동 → 완료 조건 → 진행 → 보조 맥락` 순서로 재구성하고, compact 와 large 의 구성을 다르게 설계했다.

## 위계 규칙

`DpMissionHeader` 가 위계의 단일 원천이다. 렌더 순서:

1. eyebrow + 상태 라벨
2. **제목**(heading)
3. **다음 행동** — `action` 슬롯의 `DpNextActionBand`(화면당 하나)
4. **완료 조건** — `완료 조건 · …`
5. **진행** — 진행 라벨 + 진행 바(semantics `'<label>, N%'`)
6. **보조 맥락** — `why`(근거, `bodyMedium`·secondary)

행동이 필요 없는 상태(로딩·완료·빈 상태)는 기존 전체화면 primitive(`DpLoading`/`DpEmpty`/`DpError`)를 유지한다. 데이터를 유지한 채 보이는 실패는 `DpInlineNotice`(N02 규칙).

## 폭별 구성

| 창 폭(DpWindowClass) | Today | Path |
|---|---|---|
| compact (<600) | 1열. 헤더 `compact` 변형(행동 포함) → 보조 지표(주간 활동, 스트릭만) → 광고 | 1열. 헤더 `compact` → 인라인 알림 → 진행 spine(`text` 레이아웃) → 다음 잠금 해제 → 주차 상세 → 로드맵 |
| medium (600–839) | 1열. 헤더 `standard` → 보조 지표(주간 활동, 스트릭, 완료 콘텐츠) → 광고 | 1열. spine `vertical` |
| expanded / large (≥840) | **2열**: 왼쪽(3) 미션 섹션 / 오른쪽(2) 보조 레일(주간 활동, 추세, 스트릭, 완료 콘텐츠) → 광고 | **2열**: 왼쪽(3) 헤더+알림+spine / 오른쪽(2) 다음 잠금 해제·주차 상세·로드맵 |

보조 지표 그리드의 열 수는 창 폭이 아니라 **실제 가용 폭**(LayoutBuilder)으로 정한다. 2열 레일(창의 2/5) 안에서는 1열이 되고, 추세 카드는 가용 폭 440px 이상에서만 보인다(`_trendMinWidth`).

## 제거한 것과 이유

| 제거 | 위치 | 이유 |
|---|---|---|
| 진행률 도넛(`_DonutCard`) | Today 보조 지표 | 헤더의 진행 바·퍼센트와 중복 |
| 배지 스트립(`_BadgeStrip`) | Today 보조 지표 | 사용자 행동이 아닌 장식(legacy 대시보드에는 유지) |
| 페이지 헤더 설명 '지금 완료할 한 가지 미션부터 시작합니다' | Today | 미션 헤더의 완료 조건·근거와 중복 |
| 페이지 헤더 설명 '현재 미션을 먼저 보고, 필요할 때 12주 계획을 펼쳐보세요' | Path(flag ON) | 위와 같음. flag OFF(legacy) 설명은 유지 |
| 완료 경로의 손수 만든 stale 문구 + TextButton | Path 완료 상태 | `DpInlineNotice` + '완료 상태 다시 확인' 으로 통일 |

## 회귀 방지 테스트

- `packages/dp_design/test/mission/dp_mission_header_test.dart` — action 슬롯 순서(제목 < 행동 < 완료 조건 < 진행 < why).
- `apps/web/test/features/dashboard/today_dashboard_page_test.dart` — 390px 순서·도넛/배지/설명 부재, 1240px 2열.
- `apps/web/test/features/dashboard/dashboard_body_test.dart` — compact 보조 지표 = 주간 활동 + 스트릭.
- `apps/web/test/features/path/mission_path_plan_view_test.dart` — 390px 순서, 1240px 2열, 320px·200% overflow 없음.
