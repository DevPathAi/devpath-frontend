# admin 벌크 액션 — 설계 (Design)

> 날짜: 2026-07-31 · 범위: admin 콘솔 users/ads 목록에서 다중 선택 후 벌크 액션(사용자 일괄 승인·광고 일괄 삭제) · 성격: UI/UX 로드맵 **Phase 4 이월**(백엔드 계약 확장) · 파급 레포: `devpath-platform-svc` + `devpath-frontend`(`shared` 발행 불필요)

## 1. 배경 / 목표

UI/UX 로드맵 Phase 4(admin 운영 콘솔)는 users/ads를 `DpDataTable`+행 `MenuAnchor`로 완결했으나, **단건 API만 존재**해 벌크 액션바를 이월했다. 이번 작업은 벌크 엔드포인트를 신설하고 `DpDataTable`에 다중 선택을 추가해 **여러 행을 한 번에 처리**한다.

- **완료 정의**: admin이 users 목록에서 여러 사용자를 선택해 한 번에 승인하고, ads 목록에서 여러 광고를 선택해 한 번에 삭제한다. 선택이 있으면 벌크 액션바가 등장한다.

## 2. 현재 상태 (검증된 사실, 2026-07-31 코드 실측)

- **소관 = devpath-platform-svc**(단일 레포). users=`beta/AdminUserController`+`AdminBetaService`, ads=`ads/AdminAdController`+`AdAdminService`.
- 실존 단건 API:
  - `POST /admin/users/{id}/approve` → 204. `AdminBetaService.approveUser(long)`(status=ACTIVE + 아웃박스).
  - `DELETE /admin/ads/{id}` → 204. `AdAdminService.delete(long)`.
- **⚠️ sanction 백엔드 부재**: 프론트 `users_controller.sanction()`은 `POST /admin/users/{id}/sanction`을 호출하나 **어떤 백엔드 레포에도 sanction 엔드포인트가 없다**(전 레포 grep 무결과 → 실서버 404, 목 전용). → **벌크 sanction은 범위 제외**(백엔드 sanction 신설은 별개 기능).
- `AdminUserRow(String id, String nickname, String email, String role, String status)` — **id는 String**(dp_core Page.fromJson 계약). `AdRow` — id는 number(프론트 `int?`, `r.id!` 사용).
- `DpDataTable`(`dp_design/lib/src/data/dp_data_table.dart`) = `DataTable2` 래핑, props `columns·rows·minWidth·fixedLeftColumns·empty`. **선택(체크박스) 미지원** — `DataColumn2`/`DataRow2` re-export. `data_table_2`의 `DataTable2`는 `showCheckboxColumn`·`onSelectAll`, `DataRow2`는 `selected`·`onSelectChanged` 지원.
- admin 페이지: `apps/admin/lib/src/features/{users,ads}/presentation/{users_page,ads_page}.dart` — `DpDataTable` + `DataRow2` + 행 `MenuAnchor`. 컨트롤러 `{users,ads}_controller.dart`(Notifier). admin **자체 목** `apps/admin/lib/src/data/admin_mock_fixtures.dart`.

## 3. 범위 / 비범위

**범위**: 벌크 엔드포인트 2개(users bulk-approve·ads bulk-delete) + `DpDataTable` 다중 선택 + 벌크 액션바(users/ads).

**비범위**:
- **벌크 sanction**(백엔드 sanction 엔드포인트 부재 — 신설은 별개 기능).
- 단건 sanction 백엔드 구현(기존 목-전용 상태 유지).
- 벌크 광고 수정·통계·부분 실패 상세 리포트(YAGNI — 204 일괄).
- users 필터별 "전체 선택(서버측 전량)" — 현재 페이지(로드된 행) 내 선택만.

## 4. 데이터 계약 (벌크 엔드포인트 2개, 신규)

| 엔드포인트 | 요청 | 응답 |
|---|---|---|
| `POST /admin/users/bulk-approve` | `{"ids":[<number>]}` | 204 No Content |
| `POST /admin/ads/bulk-delete` | `{"ids":[<number>]}` | 204 No Content |

- 요청 record: `BulkIdsRequest(List<Long> ids)`(양 컨트롤러 공용 또는 각 패키지). Jackson이 JSON number/string→Long 관대 변환.
- 단건 API와 동일한 **204** 계약(반환 본문 없음). 부분 존재(일부 id 없음)는 존재하는 것만 처리(멱등·무해).

## 5. 백엔드 설계 (devpath-platform-svc, Java / Spring Boot 4) — `shared` 발행 불필요

- **users**: `AdminBetaService.bulkApprove(List<Long> ids)` — 각 id에 `approveUser(id)` 반복(이미 ACTIVE는 멱등). `AdminUserController`에 `POST /admin/users/bulk-approve`(@RequestBody `BulkIdsRequest`) → 204.
- **ads**: `AdAdminService.bulkDelete(List<Long> ids)` — 각 id에 `delete(id)` 반복(없는 id는 무시 or 기존 delete 동작 준용). `AdminAdController`에 `POST /admin/ads/bulk-delete` → 204.
- **⚠️ 예외/멱등**: `delete`가 없는 id에 예외를 던지면 벌크가 중단되지 않도록 서비스에서 흡수(존재하는 것만 삭제). `approveUser`는 멱등 전제. 구현 시 단건 서비스 동작 실측 후 결정.
- `BulkIdsRequest`는 platform-svc 로컬 DTO → shared 무관.

## 6. 프론트 설계 (devpath-frontend)

- **dp_design `DpDataTable`**: 다중 선택 패스스루 추가 — `bool showCheckboxColumn`(기본 false)·`ValueChanged<bool?>? onSelectAll`. `DataTable2`에 전달. 소비 페이지가 `DataRow2(selected:, onSelectChanged:)`로 행별 선택 반영. 기존 소비처(선택 미사용)는 기본값으로 불변.
- **선택 상태(Fork 2)**: 각 컨트롤러(Notifier state)에 `Set<선택id>`(users=`Set<String>`, ads=`Set<int>`) + `toggleSelect(id)`·`selectAll(bool)`(로드된 행 대상)·`clearSelection()`·`bulkApprove()`/`bulkDelete()`(선택 id로 벌크 POST 후 재조회·선택 초기화).
- **벌크 액션바**: `AnimatedSwitcher`로 선택 비어있지 않을 때 등장 — "선택 N개" + 액션 버튼(users "승인"·ads "삭제") + "선택 해제". `apps/admin/.../{users,ads}/presentation/*`.
- **목**: `admin_mock_fixtures.dart`에 `POST /admin/users/bulk-approve`·`POST /admin/ads/bulk-delete`(204) 추가.

## 7. 결정 기록 (Forks)

- **Fork 1 — 범위 = bulk-approve(users) + bulk-delete(ads)**. 둘 다 실존 단건 엔드포인트 확장. **벌크 sanction 제외**(백엔드 sanction 엔드포인트 부재 → 신설은 별개 기능). 발견: 단건 sanction도 실서버 미구현(목 전용).
- **Fork 2 — 선택 상태 = 컨트롤러 `Set<id>`**(위젯 로컬 아님). 필터·재조회와 정합, 결정적 테스트.

## 8. 검증 / 테스트 전략 (TDD, CLAUDE.md 규칙 2)

- **백엔드**: `AdminBetaService.bulkApprove`·`AdAdminService.bulkDelete` 단위/통합 테스트(다건 처리·멱등·부분 존재 무해). `AdminUserControllerTest`/기존 컨트롤러 테스트 패턴 준용(@SpringBootTest). 로컬은 pgvector 컨테이너(platform-svc 테스트 DB명 실측 후).
- **프론트**: `DpDataTable` 선택 위젯 테스트(체크박스 열·onSelectAll), users/ads 컨트롤러 선택/벌크 테스트(Fake source로 결정적), 페이지 벌크바 등장/해제 테스트.
- **게이트**: 백엔드 `./gradlew test`. 프론트 `melos run format`→`analyze`→`test`.

## 9. 작업 분해 / 레포 / 브랜치

- **레포 2곳**: `devpath-platform-svc`(벌크 2엔드포인트+서비스) · `devpath-frontend`(DpDataTable·2컨트롤러·2페이지·목). `shared` 발행 불필요.
- **브랜치**: frontend `feat/admin-bulk-actions`(spec/plan/구현) → `develop` PR. platform-svc `feat/admin-bulk-actions` → 자체 `develop` PR. 백엔드 먼저 머지 권장.
- **순서**: 백엔드 벌크 계약 → DpDataTable 선택 → users/ads 컨트롤러 선택+벌크 → 페이지 벌크바+목.

## 10. 참조

- 로드맵 spec(이월 근거): `devpath-frontend/docs/superpowers/specs/2026-07-30-web-admin-uiux-elevation-roadmap-design.md`
- 핸드오프: `documents/docs/superpowers/handoff-2026-07-31-uiux-roadmap-complete-next-contract-expansion.md`(§C)
- 선행 A(대시보드 시계열)·B(커뮤니티 excerpt) spec(동형 계약확장): `2026-07-31-dashboard-timeseries-design.md`·`2026-07-31-community-excerpt-preview-design.md`
- 관련 코드: `devpath-platform-svc/.../beta/{AdminUserController,AdminBetaService}.java`·`.../ads/{AdminAdController,AdAdminService}.java` · `devpath-frontend/packages/dp_design/lib/src/data/dp_data_table.dart`·`apps/admin/lib/src/features/{users,ads}/`
