# 베타 광고 관리 admin UI (P2) — 설계

> 작성 2026-07-22 · 대상 `apps/admin` · 백엔드: platform-svc `/admin/ads` (구현·머지 완료)

## 목적

베타 무료기간 하우스/스폰서 광고를 운영자가 관리하는 admin 화면을 추가한다. 광고 목록 조회·상태 토글·생성/수정(이미지 업로드 포함)·슬롯별 필터·노출/클릭 통계 조회, 그리고 전역 광고 노출 on/off 토글을 제공한다.

이 문서는 **P2(admin UI)** 범위만 다룬다. P1 백엔드는 완료(shared#47·platform#35·gateway#25), P3 web 위젯은 별도 spec.

## 백엔드 API 계약 (확정, 변경 없음)

모두 `/admin/**` → SecurityConfig `hasRole("ADMIN")` 보호. 게이트웨이 platform-auth 라우트(`/ads/**`는 서빙용, `/admin/ads/**`는 admin).

| 메서드 | 경로 | 요청 | 응답 |
|---|---|---|---|
| GET | `/admin/ads?slot=&status=` | — | `200` `AdRow[]` (id DESC 정렬) |
| POST | `/admin/ads` | `AdRequest` | `201` `AdRow` |
| PUT | `/admin/ads/{id}` | `AdRequest` | `200` `AdRow` (미존재 404) |
| DELETE | `/admin/ads/{id}` | — | `204` (미존재 404, stats CASCADE) |
| POST | `/admin/ads/{id}/image` | multipart `file` | `200` `AdRow` |
| GET | `/admin/ads/settings` | — | `200` `{enabled: bool}` |
| PUT | `/admin/ads/settings` | `{enabled: bool}` | `200` `{enabled: bool}` |
| GET | `/admin/ads/{id}/stats?from=&to=` | ISO date | `200` `AdStatsRow[]` |

**AdRow / AdRequest 필드**: `id`(응답만), `title`(필수), `imageUrl`(nullable), `linkUrl`(필수), `slot`, `weight`(≥1), `status`, `startsAt`(nullable, Instant/ISO-8601), `endsAt`(nullable). **AdStatsRow**: `date`(LocalDate), `impressions`(long), `clicks`(long).

**제약값(DB CHECK — 폼 드롭다운은 이 값만 사용)**
- `slot ∈ {DASHBOARD_TOP, COMMUNITY_FEED, CONTENT_PAGE}`
- `status ∈ {ACTIVE, PAUSED}` (토글 = 두 값 전환)
- `weight ≥ 1`
- 검증 위반 시 `IllegalArgumentException` → `400 VALIDATION_FAILED`

## 아키텍처

기존 `users`/`reports` feature와 동일한 4계층 구조. 신규 디렉토리 `apps/admin/lib/src/features/ads/`.

### data/
- **`ad_row.dart`** — `AdRow` 불변 모델. `fromJson`(응답 파싱)·`toRequestJson`(POST/PUT 바디: id 제외, slot/status/weight/title/linkUrl/imageUrl/startsAt/endsAt). Instant 필드는 ISO-8601 문자열로 직렬화.
- **`ad_stats_row.dart`** — `AdStatsRow`(date·impressions·clicks) `fromJson`.
- **`ads_source.dart`** — `apiClientProvider`를 래핑하는 함수형 Provider들(users_source.dart 패턴):
  - `adsListProvider` → `({String? slot, String? status}) → Future<List<AdRow>>`
  - `adCreateProvider` → `(AdRow draft) → Future<AdRow>` (POST)
  - `adUpdateProvider` → `(int id, AdRow draft) → Future<AdRow>` (PUT)
  - `adDeleteProvider` → `(int id) → Future<void>` (DELETE)
  - `adImageUploadProvider` → `(int id, List<int> bytes, String filename, String? contentType) → Future<AdRow>` (multipart; `ApiClient.postMultipart` 시그니처와 일치)
  - `adSettingsGetProvider` / `adSettingsSetProvider` → 전역 토글
  - `adStatsProvider` → `(int id, DateTime from, DateTime to) → Future<List<AdStatsRow>>`
  - multipart 업로드는 dp_core `ApiClient.postMultipart`(마이페이지 P4에서 도입됨) 사용.

### state/
- **`ads_state.dart`** — `AdsState`(`rows`·`phase`{initial,loading,loaded,failed}·`slotFilter`·`statusFilter`·`globalEnabled`·`error`). `copyWith`.

### application/
- **`ads_controller.dart`** — `AdsController extends Notifier<AdsState>`:
  - `load()` — 목록 + 전역 설정 동시 조회 → loaded/failed.
  - `setSlotFilter(String?)` / `setStatusFilter(String?)` → load 재호출.
  - `create(AdRow draft)` / `update(int id, AdRow draft)` / `remove(int id)` → 성공 후 load.
  - `toggleStatus(AdRow row)` — status를 ACTIVE↔PAUSED 뒤집어 `update` 호출.
  - `toggleGlobal(bool enabled)` — `adSettingsSetProvider` 호출 후 state.globalEnabled 갱신.
  - `uploadImage(int id, ...)` → 성공 후 load.
  - 에러는 `ApiException` catch → `phase=failed, error=e.message` (users_controller 패턴).
  - 통계 조회는 전역 `AdsState`를 오염시키지 않도록 통계 다이얼로그 내부에서 `adStatsProvider`를 호출하는 로컬 `FutureBuilder`로 처리한다.

### presentation/
- **`ads_page.dart`** — `ConsumerWidget`:
  - 상단 바: 전역 노출 스위치(`globalEnabled`) + "광고 생성" 버튼 + 슬롯/상태 필터 Dropdown.
  - 본문: 광고 목록 `DataTable`(또는 반응형 목록) — 컬럼: 썸네일·제목·슬롯·가중치·상태(토글 스위치)·기간·액션(수정·통계·삭제).
  - 로딩/실패/빈 상태 처리(dp_design 컴포넌트 재사용).
  - **생성/수정 다이얼로그**(`AdFormDialog`): title·linkUrl·slot(Dropdown)·weight(숫자)·status(Dropdown)·imageUrl(선택)·startsAt/endsAt(날짜선택, 선택). **이미지 파일 업로드 필드는 수정 모드에서만 노출**(생성 시 id 미확보 — 백엔드 계약). 저장 시 create/update.
  - **통계 다이얼로그**(`AdStatsDialog`): 기간 선택(기본 최근 7일) → `adStatsProvider` → 일별 테이블(날짜·노출·클릭·CTR) + 합계 행. CTR = clicks/impressions(0 division 가드).

### 기존 파일 수정 (최소)
- **`app/router.dart`** — ShellRoute `routes`에 `GoRoute(path: '/ads', builder: (_, _) => const AdminAdsPage())` 추가.
- **`features/shell/presentation/admin_shell.dart`** — `kAdminDestinations`에 `(path: '/ads', icon: DpIcons.ads, label: '광고')` 추가.
- **`packages/dp_design/lib/src/icons/dp_icons.dart`** — `static const IconData ads = Symbols.campaign_rounded;` 추가.

## 테스트 (test-first, Flutter 스택)

- **`ads_controller_test.dart`** — `ProviderContainer`(인라인 overrides로 source Provider를 fake 주입, Riverpod 3.0 패턴):
  - load: 목록+설정 조회 → `loaded`, rows/globalEnabled 채워짐.
  - toggleStatus: ACTIVE→PAUSED로 update 호출됨(fake가 인자 캡처) + load 재호출.
  - create/remove: 성공 후 load 재호출.
  - toggleGlobal: settingsSet 호출 + globalEnabled 갱신.
  - ApiException → `failed` + error 메시지.
- **`ads_page_test.dart`** — 위젯 테스트(`DpTheme.light()` 주입, `tester.view.physicalSize` 폭 지정):
  - 목록 렌더(행 존재)·전역 스위치 렌더·"광고 생성" 탭 시 다이얼로그 열림.
  - 상태 토글 스위치 존재.

## 범위 밖 (YAGNI)

- 페이지네이션(광고 소규모 — 전체 조회). 필요 시 후속.
- 차트 시각화(통계는 테이블+합계). 사용자 승인.
- 대량 편집·복제·미리보기·A/B.
- 광고 이미지의 클라이언트 측 크기/형식 사전검증(백엔드 StoredFileValidator가 담당, 실패 시 에러 표시만).

## 완료 기준

- 위 테스트 전부 GREEN(`melos run analyze`·`test`·`format`).
- admin 앱에서 `/ads` 진입 → 목록·생성·수정·상태토글·삭제·전역토글·통계 동작(로컬 실API 스모크는 6단계 로컬 재테스트에서).
- develop PR CI 녹색.
