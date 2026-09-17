# ET13 커뮤니티 fixture (FREE / QNA / FEEDBACK)

> N06(2026-09-17). ET13 시각·접근성 증거 카탈로그에 커뮤니티 게시판 fixture 3종을 추가했다. 카탈로그 계약 버전은 v1 그대로이고 fixture 순서는 기존 12개 뒤에 append 했다(기존 case id·artifact 경로 불변).

## 추가된 fixture

| id | 원천 위젯 | 데이터 | 캡처 |
|---|---|---|---|
| `web-community-free` | `WebCommunityBoardProjection(board: free)` | `mockCommunityPosts('FREE')` (id 10) | body_projection |
| `web-community-qna` | `WebCommunityBoardProjection(board: qna)` | `mockCommunityPosts('QNA')` (id 1, 해결됨) | body_projection |
| `web-community-feedback` | `WebCommunityBoardProjection(board: feedback)` | `mockCommunityPosts('FEEDBACK')` (id 20) | body_projection |

visual matrix(320/600/840/1240 × light/dark)가 compact 와 desktop 을 모두 덮으므로 게시판당 fixture 는 하나다. a11y matrix(320 light 200% / 1240 dark 200%)도 그대로 적용된다.

## 계약 변경

| 항목 | 이전 | 이후 |
|---|---|---|
| fixture 수 | 12 | 15 |
| visual case (`fixture × 4 폭 × 2 테마`) | 96 | 120 |
| a11y case (`fixture × 2`) | 24 | 30 |
| web surface case | 48 / 12 | 72 / 18 |
| `projection_contract_sha256` | `c66d08b6…4bde3` | `106e8d29…de3ca` |

`tools/et13_evidence.dart` 의 case 수는 이제 `_fixtureIds.length` 에서 파생된다(`_visualCaseCount`, `_a11yCaseCount`) — 다음 fixture 추가는 id 목록·카탈로그·스키마 prefixItems·계약 테스트만 바꾸면 된다. 5개 스키마(`catalog`·`evidence`·`manifest`·`generated-cases`·`baseline-approval`)의 `prefixItems`/`minItems`/`maxItems` 를 함께 갱신했고, 생성 카탈로그는 `dart run tools/et13_evidence.dart generate` 로만 만든다.

## 투영 위젯

`WebCommunityBoardProjection` 은 `CommunityHomePage` 가 provider 로 채우는 H1·설명·게시판 세그먼트·목록·빈 상태를 순수 입력만으로 그린다. 페이지도 같은 `CommunityBoardFilterBar`·`CommunityPostRow`·`CommunityBadgeChip` 을 쓰므로 fixture 와 운영 화면이 갈라지지 않는다. 검색·광고·라우팅은 fixture 밖이다.

## baseline 승인 절차

- `baseline_status` 는 `pending_external_review` 그대로다. PR 의 `et13-evidence.yml` 은 diagnostic 모드로 15 fixture 를 캡처만 하고 baseline 과 비교하지 않는다.
- release_ready 전환은 사람이 `et13-baseline-approval.yml` 경로로 새 baseline 번들(120 PNG + 메타 2)을 승인하고 provenance 를 남긴 뒤에만 한다. 자동 갱신은 없다.
