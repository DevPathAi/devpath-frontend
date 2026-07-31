# UI/UX Phase 4 — admin 운영 콘솔 고도화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** admin의 users·ads 화면을 `DpDataTable`(dp_design Layer 2, data_table_2 래핑)로 전환하고 행 작업을 `MenuAnchor` 메뉴로 통일한다(헤더 고정·가로 스크롤바, 계약 불변).

**Architecture:** dp_design에 `data_table_2`를 래핑한 `DpDataTable`을 신설(헤더 고정·가로 Scrollbar·최소 폭·토큰 테마 기본). users/ads page가 이를 조립하고 행 마지막 열에 MenuAnchor를 둔다. 컨트롤러/상태/소스/API 계약은 불변.

**Tech Stack:** Flutter Web(CanvasKit), Riverpod 3, `data_table_2`(신규), SDK `MenuAnchor`/`MenuItemButton`. 검증 SSoT = spec `docs/superpowers/specs/2026-07-31-uiux-phase4-admin-console-design.md`.

## Global Constraints

- **계약 불변**: `UsersController`(`load`·`loadMore`·`setStatusFilter`·`select`·`sanction`·`approve`·`preApprove`)·`UsersState`·`AdsController`·`AdsState`·소스 프로바이더·백엔드 API 시그니처 변경 금지.
- **`DpDataTable`은 go_router·Riverpod 비의존** 순수 표현부(Layer 2). data_table_2 의존은 dp_design 내부에 캡슐화, 필요한 타입만 re-export.
- **토큰만 사용**: `DpColors`(`context.dpColors`)·`DpSpacing`·`DpRadius`·`AppTokens`. 하드코딩 색/반경 금지. 아이콘은 `DpIcons`.
- **패키지 버전은 도입 시 Context7로 확정**, 확정 버전을 리포트에 기록. Flutter Web(CanvasKit) 지원 패키지만.
- **게이트(매 커밋 전 관련 범위, 최종 전체)**: `melos run analyze`(0 issues)·`melos run test`(pass)·`melos run format`(clean). PATH 미설정 시 `dart pub global run melos <cmd>`.
- **커밋**: Conventional Commits. 각 메시지 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## Task 1: data_table_2 도입 + 검증

**Files:**
- Modify: `packages/dp_design/pubspec.yaml` (dependencies)
- Create: `docs/superpowers/reports/2026-07-31-uiux-phase4-package-adoption.md`

**Interfaces:**
- Produces: `packages/dp_design`에서 `package:data_table_2/data_table_2.dart`(`DataTable2`/`DataColumn2`/`DataRow2`) 사용 가능.

- [ ] **Step 1: Context7로 data_table_2 최신 버전·API·CanvasKit 호환 확인**

`data_table_2` resolve-library-id → query-docs로 (a) 안정 버전 (b) Flutter Web 지원 (c) API: `DataTable2(columns, rows, minWidth, fixedLeftColumns, isHorizontalScrollBarVisible, empty, headingRowColor)`·`DataColumn2(label, size, fixedWidth)`·`DataRow2(cells, onTap, selected)`. 라이선스 확인.

- [ ] **Step 2: dp_design pubspec에 추가**

`cd packages/dp_design && flutter pub add data_table_2` (최신 caret 기록). 이어 루트에서 `dart pub global run melos bootstrap`.

- [ ] **Step 3: 해석·analyze 확인**

Run: `dart pub global run melos run analyze`
Expected: 해석 성공·0 issues.

- [ ] **Step 4: 도입 결과 리포트 기록**

`docs/superpowers/reports/2026-07-31-uiux-phase4-package-adoption.md`에 확정 버전·라이선스·CanvasKit 호환·bootstrap 결과를 표로 기록.

- [ ] **Step 5: Commit**

```bash
git add packages/dp_design/pubspec.yaml pubspec.lock docs/superpowers/reports/2026-07-31-uiux-phase4-package-adoption.md
git commit -m "chore(dp_design): Phase4 data_table_2 도입

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: DpDataTable (dp_design Layer 2)

**Files:**
- Create: `packages/dp_design/lib/src/data/dp_data_table.dart`
- Modify: `packages/dp_design/lib/dp_design.dart` (export 추가)
- Test: `packages/dp_design/test/data/dp_data_table_test.dart`

**Interfaces:**
- Consumes: `data_table_2`, `context.dpColors`.
- Produces: `DpDataTable({required List<DataColumn2> columns, required List<DataRow2> rows, double? minWidth, int fixedLeftColumns, Widget? empty})`. `DataColumn2`·`DataRow2`를 re-export.

- [ ] **Step 1: Write the failing test**

`packages/dp_design/test/data/dp_data_table_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DpDataTable: 헤더·행 셀 렌더', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpDataTable(
            minWidth: 400,
            columns: [
              DataColumn2(label: const Text('이름')),
              DataColumn2(label: const Text('상태')),
            ],
            rows: [
              DataRow2(
                cells: [
                  DataCell(const Text('홍길동')),
                  DataCell(const Text('ACTIVE')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('이름'), findsOneWidget);
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/dp_design && flutter test test/data/dp_data_table_test.dart`
Expected: FAIL — `DpDataTable`·`DataColumn2`(re-export 전) 미정의.

- [ ] **Step 3: Write minimal implementation**

`packages/dp_design/lib/src/data/dp_data_table.dart`:

```dart
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';

// 소비 화면이 dp_design만 import하도록 테이블 셀/컬럼 타입을 re-export.
export 'package:data_table_2/data_table_2.dart' show DataColumn2, DataRow2;

/// 데이터 테이블(Layer 2). data_table_2를 래핑해 헤더 고정·가로 스크롤바·최소 폭·
/// 토큰 테마를 기본 제공한다. go_router·Riverpod 비의존 순수 표현부.
class DpDataTable extends StatelessWidget {
  const DpDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth,
    this.fixedLeftColumns = 0,
    this.empty,
  });

  final List<DataColumn2> columns;
  final List<DataRow2> rows;
  final double? minWidth;
  final int fixedLeftColumns;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return DataTable2(
      columns: columns,
      rows: rows,
      minWidth: minWidth,
      fixedLeftColumns: fixedLeftColumns,
      isHorizontalScrollBarVisible: true,
      empty: empty,
      headingRowColor: WidgetStatePropertyAll(c.surface),
      border: TableBorder.all(color: c.border, width: 1),
    );
  }
}
```

`packages/dp_design/lib/dp_design.dart`에 export 추가(`export 'src/data/dp_list_row.dart';` 다음 줄):

```dart
export 'src/data/dp_data_table.dart';
```

> Step 1 Context7 결과가 위 API와 다르면(예: `isHorizontalScrollBarVisible`·`headingRowColor` 시그니처) 확정 버전 API로 대조·수정한다. `DataCell`은 flutter/material 기본이라 re-export 불필요.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/dp_design && flutter test test/data/dp_data_table_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/dp_design/lib/src/data/dp_data_table.dart packages/dp_design/lib/dp_design.dart packages/dp_design/test/data/dp_data_table_test.dart
git commit -m "feat(dp_design): DpDataTable — data_table_2 래핑 고정헤더 테이블(Layer 2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: users_page 전환 (패널 제거·DpDataTable·행 MenuAnchor)

**Files:**
- Modify: `apps/admin/lib/src/features/users/presentation/users_page.dart`
- Test: `apps/admin/test/features/users/users_page_test.dart`·`users_page_beta_test.dart` (갱신)

**Interfaces:**
- Consumes: `DpDataTable`·`DataColumn2`·`DataRow2`(Task 2), `MenuAnchor`/`MenuItemButton`(SDK), `DpIcons.moreVert`, `UsersController`(`approve`·`sanction`·`load`·`setStatusFilter`·`preApprove`).
- Produces: users 화면이 풀폭 `DpDataTable` + 행 MenuAnchor(BETA_PENDING→승인 / 그 외→제재).

- [ ] **Step 1: Update the tests (기존 패널 → 행 MenuAnchor)**

`users_page_test.dart`의 유일 테스트를 교체:

```dart
  testWidgets('테이블 렌더 + 행 MenuAnchor 제재 메뉴', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = ProviderContainer(
      overrides: [
        adminUsersFetchProvider.overrideWithValue(
          ({String? cursor, String? status}) async => Page(
            data: [
              AdminUserRow(
                id: 'u1',
                nickname: '지수',
                email: 'a@x',
                role: UserRole.learner,
                status: 'ACTIVE',
              ),
            ],
            limit: 20,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const AdminUsersPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('지수'), findsOneWidget);
    // 행 MenuAnchor 열기 → 제재 메뉴
    await tester.tap(find.byIcon(DpIcons.moreVert));
    await tester.pumpAndSettle();
    expect(find.text('영구 밴'), findsOneWidget);
  });
```

(상단에 `import 'package:dp_design/dp_design.dart';`는 이미 있음 — `DpIcons` 참조 확인. 없으면 추가.)

`users_page_beta_test.dart`의 (b)·(b-2)를 행 MenuAnchor 기반으로 교체(나머지 (a)·(c)는 유지):

```dart
  testWidgets('(b) BETA_PENDING 행 메뉴에 승인이 있고 탭하면 approve(id) 호출', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final spy = _SpyController();
    final c = _makeContainer(controller: spy);
    addTearDown(c.dispose);

    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    // 첫 행(대기자, BETA_PENDING)의 MenuAnchor 열기
    await tester.tap(find.byIcon(DpIcons.moreVert).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(MenuItemButton, '승인'), findsOneWidget);
    expect(find.text('영구 밴'), findsNothing); // BETA_PENDING엔 제재 없음

    await tester.tap(find.widgetWithText(MenuItemButton, '승인'));
    await tester.pumpAndSettle();
    expect(spy.approvedIds, contains('u-pending'));
  });

  testWidgets('(b-2) ACTIVE 행 메뉴에 제재가 있다', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = _makeContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    // 둘째 행(활성유저, ACTIVE)의 MenuAnchor 열기
    await tester.tap(find.byIcon(DpIcons.moreVert).at(1));
    await tester.pumpAndSettle();

    expect(find.text('영구 밴'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '승인'), findsNothing);
  });
```

(`users_page_beta_test.dart` 상단에 `import 'package:dp_design/dp_design.dart';`가 이미 있음 — `DpIcons` 사용 가능.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/admin && flutter test test/features/users/users_page_test.dart test/features/users/users_page_beta_test.dart`
Expected: FAIL — MenuAnchor 미존재(현재 패널).

- [ ] **Step 3: Write minimal implementation**

`users_page.dart`의 `loaded` 분기(현재 `Row`[테이블 + 패널])를 풀폭 `DpDataTable`로 교체하고, `_SanctionPanel` 클래스를 제거. build의 `loaded` 케이스:

```dart
              UsersPhase.loaded => DpDataTable(
                minWidth: 720,
                columns: [
                  DataColumn2(label: const Text('닉네임')),
                  DataColumn2(label: const Text('이메일')),
                  DataColumn2(label: const Text('역할')),
                  DataColumn2(label: const Text('상태')),
                  DataColumn2(label: const Text('작업'), fixedWidth: 64),
                ],
                rows: [
                  for (final r in s.rows)
                    DataRow2(
                      cells: [
                        DataCell(Text(r.nickname)),
                        DataCell(Text(r.email)),
                        DataCell(Text(r.role.name)),
                        DataCell(Text(r.status)),
                        DataCell(_rowMenu(context, n, r)),
                      ],
                    ),
                ],
              ),
```

`_S` 클래스(State)에 행 메뉴 헬퍼 추가:

```dart
  Widget _rowMenu(BuildContext context, UsersController n, AdminUserRow r) {
    return MenuAnchor(
      builder: (context, controller, child) => IconButton(
        icon: const Icon(DpIcons.moreVert),
        tooltip: '작업',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: r.status == 'BETA_PENDING'
          ? [
              MenuItemButton(
                onPressed: () => n.approve(r.id),
                child: const Text('승인'),
              ),
            ]
          : [
              for (final a in const ['경고', '7일 정지', '30일 정지', '영구 밴'])
                MenuItemButton(
                  onPressed: () => n.sanction(r.id, a),
                  child: Text(a),
                ),
            ],
    );
  }
```

기존 `_SanctionPanel` 클래스 전체를 삭제한다(패널 제거). `_PreApproveBar`·상태 필터 ChoiceChip은 유지. `_emailCtrl`·`select`·`state.selected`는 손대지 않는다(계약 유지).

> `DpDataTable`은 bounded height가 필요하다 — 현재 build는 `body: Column(children: [_PreApproveBar, Expanded(child: switch...)])` 구조라 `Expanded` 안에서 `DpDataTable`이 bounded 높이를 받는다(구조 유지).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd apps/admin && flutter test test/features/users/`
Expected: PASS — 갱신된 page·beta 테스트 + `approve_test`(순수 컨트롤러, 불변)·`users_controller_test`.

- [ ] **Step 5: Commit**

```bash
git add apps/admin/lib/src/features/users/presentation/users_page.dart apps/admin/test/features/users/users_page_test.dart apps/admin/test/features/users/users_page_beta_test.dart
git commit -m "feat(admin): users를 DpDataTable + 행 MenuAnchor로 전환(패널 제거)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: ads_page 전환 (DpDataTable·행 MenuAnchor)

**Files:**
- Modify: `apps/admin/lib/src/features/ads/presentation/ads_page.dart`
- Test: `apps/admin/test/features/ads/ads_page_test.dart` (행 메뉴 테스트 추가)

**Interfaces:**
- Consumes: `DpDataTable`·`DataColumn2`·`DataRow2`, `MenuAnchor`/`MenuItemButton`, `DpIcons.moreVert`, `AdsController`(`toggleStatus`·`remove`)·`_openForm`·`_openStats`.
- Produces: ads 목록이 `DpDataTable`, 행 작업이 MenuAnchor(수정/통계/삭제).

- [ ] **Step 1: Add failing test (행 메뉴)**

`ads_page_test.dart`에 테스트 추가(기존 2개는 유지):

```dart
  testWidgets('행 MenuAnchor에 수정/통계/삭제가 있다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(
            ({slot, status}) async => [_ad(1, '첫 배너')],
          ),
          adSettingsGetProvider.overrideWithValue(() async => true),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(DpIcons.moreVert));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, '수정'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '통계'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '삭제'), findsOneWidget);
  });
```

(상단 import에 `import 'package:dp_design/dp_design.dart';`는 이미 있음.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/admin && flutter test test/features/ads/ads_page_test.dart`
Expected: FAIL — MenuAnchor 미존재(현재 IconButton 3개).

- [ ] **Step 3: Write minimal implementation**

`ads_page.dart`의 `loaded` 분기 `DataTable`을 `DpDataTable`로 교체하고, 액션 셀 IconButton 3개를 MenuAnchor로:

```dart
        AdsPhase.loaded => DpDataTable(
          minWidth: 760,
          columns: [
            DataColumn2(label: const Text('제목')),
            DataColumn2(label: const Text('슬롯')),
            DataColumn2(label: const Text('가중치')),
            DataColumn2(label: const Text('상태')),
            DataColumn2(label: const Text('액션'), fixedWidth: 64),
          ],
          rows: [
            for (final r in s.rows)
              DataRow2(
                cells: [
                  DataCell(Text(r.title)),
                  DataCell(Text(r.slot)),
                  DataCell(Text('${r.weight}')),
                  DataCell(
                    Switch(
                      value: r.status == 'ACTIVE',
                      onChanged: (_) => n.toggleStatus(r),
                    ),
                  ),
                  DataCell(_rowMenu(context, n, r)),
                ],
              ),
          ],
        ),
```

`_AdsPageState`에 헬퍼 추가:

```dart
  Widget _rowMenu(BuildContext context, AdsController n, AdRow r) {
    return MenuAnchor(
      builder: (context, controller, child) => IconButton(
        icon: const Icon(DpIcons.moreVert),
        tooltip: '작업',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => _openForm(context, n, r),
          child: const Text('수정'),
        ),
        MenuItemButton(
          onPressed: () => _openStats(context, r),
          child: const Text('통계'),
        ),
        MenuItemButton(
          onPressed: () => n.remove(r.id!),
          child: const Text('삭제'),
        ),
      ],
    );
  }
```

통계 다이얼로그 내부의 `DataTable`은 유지(소형 고정 표). 전역 Switch·생성 버튼·슬롯 필터 유지.

> ads의 `loaded` 분기는 현재 `SingleChildScrollView`(가로) 안의 `DataTable`이었다 — `DpDataTable`로 교체 시 `SingleChildScrollView` 래핑을 제거하고 `Scaffold`의 `body`(switch 결과)가 직접 `DpDataTable`이 되도록 한다(DpDataTable이 bounded body 높이를 받음).

- [ ] **Step 4: Run test to verify it passes (ads 폴더 전체)**

Run: `cd apps/admin && flutter test test/features/ads/`
Expected: PASS — 신규 행 메뉴 + 기존 renders/생성 다이얼로그 + `ads_controller_test`·`ad_row_test`·`ads_route_test`.

- [ ] **Step 5: 전체 게이트**

Run: `dart pub global run melos run analyze` · `dart pub global run melos run test` · `dart pub global run melos run format`
Expected: analyze 0 issues · 전 패키지 test PASS(admin·dp_design 포함) · format clean.

- [ ] **Step 6: Commit**

```bash
git add apps/admin/lib/src/features/ads/presentation/ads_page.dart apps/admin/test/features/ads/ads_page_test.dart
git commit -m "feat(admin): ads를 DpDataTable + 행 MenuAnchor로 전환

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (작성자 체크 결과)

**1. Spec coverage:**
- §2 data_table_2 도입·검증 → Task 1 ✓ / §3.1 DpDataTable(헤더 고정·가로 스크롤바·re-export) → Task 2 ✓ / §4 users(패널 제거·풀폭·행 MenuAnchor 승인/제재) → Task 3 ✓ / §5 ads(DpDataTable·행 MenuAnchor 수정/통계/삭제) → Task 4 ✓ / §6 테스트(DpDataTable·users·ads 갱신) → Task 2~4 ✓ / §7 계약 불변 → Global Constraints ✓.

**2. Placeholder scan:** TBD/TODO 없음. 모든 코드 스텝 실제 코드 포함(외부 패키지 버전만 Context7 확정 대상, 의도된 검증 스텝) ✓.

**3. Type consistency:** `DpDataTable`(columns/rows/minWidth/fixedLeftColumns/empty)가 정의(Task 2)와 소비(Task 3·4)에서 일치 ✓. `DataColumn2`/`DataRow2` re-export로 admin이 dp_design만 import ✓. `AdminUserRow`(id/nickname/email/role/status)·`AdRow`(id/title/slot/weight/status)·`UsersController`/`AdsController` 메서드 실측과 일치 ✓. `DpIcons.moreVert` 존재 확인 ✓. `MenuAnchor`/`MenuItemButton` SDK ✓.

**4. 회귀 주의:** users는 패널 제거로 `users_page_test`·`users_page_beta_test`(b·b-2) 갱신(Task 3). `approve_test`·`users_controller_test`는 순수 컨트롤러라 불변. ads는 IconButton→MenuAnchor지만 상태 Switch 유지라 기존 renders/생성 테스트 유지 + 행 메뉴 신규(Task 4). `select`/`state.selected`는 미사용으로 남겨 계약 유지.
