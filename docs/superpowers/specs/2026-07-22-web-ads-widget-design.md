# 베타 광고 web 위젯 (P3) — 설계

> 작성 2026-07-22 · 대상 `apps/web` · 서빙 백엔드: platform-svc `GET /ads`·`POST /ads/{id}/events`(구현·머지 완료)

## 목적

베타 무료기간 하우스/스폰서 광고를 web 앱의 3개 슬롯에 표시한다. 광고는 fail-silent(로드 실패·미노출 시 조용히 사라짐)로 동작하고, 실제 뷰포트 가시성 기준 노출(IMPRESSION) 1회·클릭(CLICK) 이벤트를 측정한다.

이 문서는 **P3(web 위젯)** 범위만 다룬다. P1 백엔드·P2 admin UI는 완료.

## 서빙 API 계약 (확정)

| 메서드 | 경로 | 응답 |
|---|---|---|
| GET | `/ads?slot=<SLOT>` | `200` `AdView` 1개, 또는 **`204`(적격 광고 없음/전역 off)** |
| POST | `/ads/{id}/events` | `202` (body `{type: "IMPRESSION"|"CLICK"}`) |

- `AdView` = `{id: number, title: string, imageUrl: string?, linkUrl: string, slot: string}`.
- 슬롯: `DASHBOARD_TOP`(대시보드 상단) · `COMMUNITY_FEED`(커뮤니티 피드 5번째 게시글 뒤) · `CONTENT_PAGE`(콘텐츠/학습경로 페이지).
- 서버가 전역 토글·게이팅·가중치 랜덤을 이미 처리 → 클라이언트는 "1개 받으면 표시, 없으면 미표시"만.

## 아키텍처

기존 web feature 구조(data/application/presentation)를 따르는 신규 `apps/web/lib/src/features/ads/`. 슬롯 3종을 **단일 파라미터 위젯** `AdSlotWidget(slot:)`으로 공용 처리(DRY).

### data/
- **`ad_view.dart`** — `AdView` 모델(id·title·imageUrl·linkUrl·slot) + `fromJson`.
- **`ads_source.dart`** — `apiClientProvider` 래핑:
  - `adFetchProvider` → `Future<AdView?> Function(String slot)`. `GET /ads?slot=`; **200이면 AdView, 204(빈 본문)·모든 예외→null(fail-silent)**. try/catch로 ApiException 삼킴.
  - `adEventProvider` → `Future<void> Function(int id, String type)`. `POST /ads/{id}/events` body `{type}`; **예외 삼킴(측정 실패는 무시)**.

### application/
- **`ad_link_opener.dart`**(+`ad_link_opener_web.dart`/`ad_link_opener_stub.dart`) — `oauth_launcher` 패턴 미러링:
  - `abstract interface class AdLinkOpener { void open(String url); }`
  - 조건부 import: web=`window.open(url, '_blank')`(새 탭), stub=`UnsupportedError`(테스트에서 override).
  - `final adLinkOpenerProvider = Provider<AdLinkOpener>((ref) => createAdLinkOpener());`

### presentation/
- **`ad_slot_widget.dart`** — `class AdSlotWidget extends ConsumerStatefulWidget`(`final String slot`):
  - `initState` 후 `adFetchProvider(slot)` 호출 → 결과를 로컬 상태(`AdView? _ad`, `bool _loaded`)에 보관.
  - `_ad == null`(미로드/204/실패)이면 `SizedBox.shrink()` 반환(fail-silent, 레이아웃 미점유).
  - 로드 성공 시 `VisibilityDetector`(key=`ad-<slot>-<id>`)로 감싸 `onVisibilityChanged`에서 `visibleFraction >= 0.5` && `!_impressed`이면 IMPRESSION 1회 발사(`_impressed=true` 가드) → `adEventProvider(id,'IMPRESSION')`.
  - 카드 UI: 이미지(있으면 `Image.network`, 실패 시 title 폴백) + title + **"광고" 라벨**(투명성). `InkWell` 탭 → CLICK 발사(`adEventProvider(id,'CLICK')`) + `adLinkOpenerProvider.open(linkUrl)`.
  - 슬롯별 미세 스타일(예: COMMUNITY_FEED는 피드 카드 폭에 맞춤)만 분기, 구조는 공통.

### 배선 (기존 3페이지 최소 수정)
- **`dashboard/presentation/dashboard_page.dart`** — `_Body`의 `ListView` children 최상단에 `const AdSlotWidget(slot: 'DASHBOARD_TOP')`.
- **`community/presentation/community_home_page.dart`** — `ListView.separated`의 `itemCount`/`itemBuilder`를 조정해 5번째 게시글(인덱스 4) **뒤**에 `AdSlotWidget(slot:'COMMUNITY_FEED')` 삽입. 게시글이 5개 미만이면 미삽입.
- **`content/presentation/content_page.dart`** — 본문 `Column`의 **콘텐츠 본문 아래(스크롤 하단)**에 `AdSlotWidget(slot:'CONTENT_PAGE')`. 구현자는 실제 `Column` children 말미에 배치(기존 액션/네비 요소가 있으면 그 위).

## 에러 처리 (fail-silent 원칙)

- fetch 실패/204 → `_ad=null` → `SizedBox.shrink()`. 사용자에게 에러·빈 자리 노출 안 함.
- 이벤트(impression/click) 발사 실패 → 조용히 무시(측정 유실 허용, P1 spec과 일치).
- 이미지 로드 실패 → `Image.network`의 `errorBuilder`로 title 텍스트 카드 폴백.

## 테스트 (test-first, Flutter 스택)

- **`ad_slot_widget_test.dart`**(위젯 테스트, `DpTheme.light()` 주입):
  - fetch→null이면 `SizedBox.shrink`만(`find.byType(InkWell)` 없음).
  - fetch→AdView면 title·"광고" 라벨 렌더.
  - 탭 시 CLICK 이벤트 발사 + `AdLinkOpener.open(linkUrl)` 호출(Fake 오퍼너가 URL 캡처) — `adEventProvider`도 fake로 캡처.
  - IMPRESSION 1회 가드: `VisibilityDetectorController.instance.updateInterval = Duration.zero`로 강제 후 가시 → 이벤트 1회만(중복 pump에도 1회).
- **`ads_source_test.dart`**: `adFetchProvider`가 예외 시 null 반환(fail-silent) — `apiClientProvider`를 예외 던지는 fake로 override.

## 신규 의존성

- `visibility_detector`(뷰포트 가시성). `apps/web/pubspec.yaml`에 추가 + `melos bootstrap`. `package:web`는 기존 의존(oauth_launcher_web에서 사용 중).

## 범위 밖 (YAGNI)

- 타게팅·빈도캡·dedup·A/B·캐러셀(복수 광고 회전).
- 모바일 앱(`apps/mobile`) 위젯 — 별도.
- admin/web 슬롯 프리뷰.

## 완료 기준

- 위 테스트 GREEN(`melos run analyze`·`test`·`format`).
- 3개 페이지에서 광고 로드 시 표시·미로드 시 완전 미표시(fail-silent), 클릭 시 새 탭 오픈, 가시 시 impression 1회(로컬 실API 스모크는 6단계 재테스트).
- develop PR CI 녹색.
