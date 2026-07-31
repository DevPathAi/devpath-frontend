# UI/UX Phase 4 — admin 운영 콘솔 고도화 (설계)

> 상위 로드맵: [`2026-07-30-web-admin-uiux-elevation-roadmap-design.md`](./2026-07-30-web-admin-uiux-elevation-roadmap-design.md) §5 Phase 4.
> 선행: Phase 0·1·2·3 develop 머지 완료(PR#86·#87·#90·#91).
> 대상: `apps/admin`(운영 콘솔, Flutter Web). 작성일 2026-07-31 · 브랜치 `feat/uiux-phase4-admin-console`.

---

## 1. 배경 · 목표 · 비목표

### 1.1 배경 (실측)
- `apps/admin`의 users·ads 화면은 SDK 기본 `DataTable` + `SingleChildScrollView(horizontal)`이라 **헤더가 스크롤에 따라 사라지고 첫 열 고정이 없다**.
  - `users_page.dart`: `DataTable`(닉네임·이메일·역할·상태) + 행 선택 시 우측 상세/제재 패널(`Row` 3:2). 상태 필터 ChoiceChip·사전승인 폼. `UsersController`: cursor 페이지네이션(`loadMore`/`nextCursor`), 단건 `sanction`/`approve`/`preApprove`.
  - `ads_page.dart`: `DataTable`(제목·슬롯·가중치·상태 Switch·액션) + 행 IconButton 3개(수정/통계/삭제). 전역 노출 Switch·생성 폼/통계 다이얼로그·슬롯 필터.
  - `reports_page.dart`: Card+ListTile 리스트(테이블 아님).
- 데이터 계약: `UsersController`·`AdsController`·상태·소스는 유지. **벌크(다중 대상) 엔드포인트는 없다**(sanction/approve/remove 전부 단건).
- `dp_design`엔 데이터 테이블 컴포넌트(`DpDataTable`)가 없다. `data_table_2`·`two_dimensional_scrollables` 미도입.

### 1.2 목표
1. `dp_design`에 재사용 `DpDataTable`(Layer 2, `data_table_2` 래핑)을 신설 — 헤더/첫 열 고정·가로 스크롤바·최소 폭·토큰 테마 기본 제공.
2. users·ads 화면을 `DpDataTable`로 전환하고, 행 작업을 `MenuAnchor` 행 메뉴로 통일한다.

### 1.3 비목표 (YAGNI)
- **벌크 액션바(다중 선택→일괄 처리) 제외**: 백엔드 벌크 엔드포인트 부재. 단건 액션(행 MenuAnchor) 유지. 계약 확장 시 후속.
- **`two_dimensional_scrollables` 미도입**: 초대형 양방향 지연 셀 전용 — 현재 규모엔 과함. `data_table_2`로 충분.
- **reports 화면 제외**: 신고는 카드 UX가 적합 → 이번 범위 밖(별도).
- **명령팔레트(Phase 1 `DpCommandPalette`) admin 배선 제외**: 이미 admin 셸에 존재(Phase 1). 이번은 테이블 고도화에 집중.
- 백엔드/컨트롤러/상태 계약 변경 없음. `apps/web`·`apps/mobile` 대상 아님.

---

## 2. 패키지 도입 (로드맵 §3 검증)

| 패키지 | 용도 | 대안(실패 시) |
|---|---|---|
| `data_table_2` | 헤더/첫 열 고정 테이블, 최소 폭·가로 스크롤 | 기본 `DataTable` + 자체 sticky 헤더 |

각 도입마다: ① Context7 최신 버전·API(`DataTable2`/`DataColumn2`/`DataRow2`/`fixedTopRows`/`fixedLeftColumns`) → ② Flutter Web(CanvasKit)·현 SDK 호환 → ③ 라이선스 → ④ `melos bootstrap`·`analyze` 통과 → ⑤ 확정 버전 리포트 기록. 도입 위치: `packages/dp_design`(DpDataTable가 래핑).

---

## 3. 아키텍처 (Layer 2 신설)

### 3.1 `DpDataTable` (dp_design)
`packages/dp_design/lib/src/data/dp_data_table.dart`, `dp_design.dart` export.
- `data_table_2`의 `DataTable2`를 래핑해 다음을 **기본값**으로 제공: 헤더 고정(`DataTable2`는 기본 sticky 헤더), 가로 `Scrollbar(thumbVisibility: true)`, `minWidth`, 토큰 색/보더.
- go_router·Riverpod **비의존** 순수 표현부.
- API:
  ```dart
  DpDataTable({
    Key? key,
    required List<DataColumn2> columns,
    required List<DataRow2> rows,
    double? minWidth,           // 이보다 좁으면 가로 스크롤
    int fixedLeftColumns = 0,   // 첫 열 고정 개수
    Widget? empty,
  })
  ```
- dp_design이 `data_table_2` 의존 + `DataColumn2`·`DataRow2`·`DataCell` 등 소비에 필요한 타입을 re-export(앱이 `dp_design`만 import).

### 3.2 Layer 3
- users/ads page가 `DpDataTable`을 조립. 컬럼 정의·행 셀·행 MenuAnchor는 화면 측. 컨트롤러/상태 불변.

---

## 4. users 화면

- **레이아웃**: 우측 상세/제재 패널(`_SanctionPanel`) 제거 → `DpDataTable` **풀폭**(헤더 고정). `state.selected`·`select()`는 UI 미사용(계약 유지 위해 남김).
- **열**: 닉네임·이메일·역할·상태·(작업).
- **(작업) 행 MenuAnchor**(더보기 아이콘 트리거):
  - `status == 'BETA_PENDING'` → 메뉴 `승인`(`approve(id)`).
  - 그 외 → 메뉴 `경고`·`7일 정지`·`30일 정지`·`영구 밴`(`sanction(id, action)`).
- 유지: 상태 필터 ChoiceChip(AppBar bottom)·사전승인 폼(`_PreApproveBar`)·`loadMore`(cursor).

## 5. ads 화면

- **레이아웃**: `DpDataTable`(헤더 고정). 열: 제목·슬롯·가중치·상태(Switch)·(작업).
- **(작업) 행 MenuAnchor**: `수정`(`_openForm`)·`통계`(`_openStats`)·`삭제`(`remove(id)`) — 기존 IconButton 3개 대체.
- 유지: 전역 노출 Switch·생성 폼/통계 다이얼로그(`DataTable`은 통계 다이얼로그 내부 유지 가능)·슬롯 필터.

---

## 6. 테스트 (TDD, Test-First — 절대 조건 2)

- **`DpDataTable`(dp_design)**: 컬럼 헤더·행 셀 텍스트 렌더, 빈 상태, `data_table_2` 위젯 존재(헤더 고정 구조).
- **users(admin)**: 행 데이터 렌더, MenuAnchor 열림→`승인`(BETA_PENDING)·`제재` 액션이 컨트롤러 호출, 상태 필터·사전승인 회귀. 기존 `users_page_test`·`users_page_beta_test`·`approve_test`를 패널 제거·행 메뉴 반영으로 갱신.
- **ads(admin)**: 행 렌더, MenuAnchor→수정/통계/삭제, 상태 Switch·생성 회귀. `ads_page_test` 갱신.
- **게이트**: `melos run analyze`(0 issues)·`melos run test`(전 패키지 pass)·`melos run format`(clean).

---

## 7. 수용 기준 (AC — 로드맵 §5 Phase 4)

- [ ] `DpDataTable`이 dp_design Layer 2로 신설되고 헤더 고정·가로 `Scrollbar(thumbVisibility:true)`를 기본 제공한다.
- [ ] users·ads가 `DpDataTable`로 렌더되고 헤더가 스크롤에 고정된다.
- [ ] 행 `MenuAnchor` 메뉴로 작업(users=승인/제재, ads=수정/통계/삭제)이 수행된다.
- [ ] `data_table_2` 도입이 §3 절차로 검증·기록된다(확정 버전).
- [ ] 벌크·two_dimensional_scrollables·reports는 범위에서 제외된다.
- [ ] 컨트롤러/상태/API 계약 불변.
- [ ] `melos analyze`·`test`·`format` green.

---

## 8. 구현 분해 지점 (→ writing-plans)

1. **`data_table_2` 도입 + 검증** (§3 기록).
2. **`DpDataTable`** (dp_design Layer 2, TDD).
3. **users_page 전환** (패널 제거·`DpDataTable`·행 MenuAnchor) + 테스트 갱신.
4. **ads_page 전환** (`DpDataTable`·행 MenuAnchor) + 테스트 갱신.

각 단계는 실패 테스트 → 구현 → green → 커밋(Conventional Commits).
