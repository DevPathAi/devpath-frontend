# admin 벌크 액션 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** admin users/ads 목록에서 다중 선택 후 일괄 처리(사용자 일괄 승인·광고 일괄 삭제)를 제공한다.

**Architecture:** 백엔드(`devpath-platform-svc`)는 실존 단건 서비스(`AdminBetaService.approveUser`·`AdAdminService.delete`)를 반복하는 벌크 메서드 2개 + 벌크 엔드포인트 2개(204)를 추가한다. 프론트(`devpath-frontend`)는 `DpDataTable`에 선택(체크박스) 패스스루를 추가하고, users/ads 컨트롤러에 `Set<선택id>` + 벌크 메서드를 두며, 두 페이지가 체크박스 열 + 공용 `BulkActionBar`(AnimatedSwitcher)로 소비한다. `shared` 발행 불필요(platform-svc 로컬 요청 바디).

**Tech Stack:** Java 21 · Spring Boot 4 · JUnit 5 + MockMvc + AssertJ · Flutter Web · data_table_2 · flutter_riverpod · melos.

## Global Constraints

- **TDD 필수**(CLAUDE.md 규칙 2): 실패 테스트 선작성 → 최소 구현 → 통과 확인.
- **추측 금지**(규칙 1): 명세에 없는 코드 즉흥 구현 금지.
- **벌크 계약**: `POST /admin/users/bulk-approve`·`POST /admin/ads/bulk-delete`, 요청 `{"ids":[<number>]}`(기존 `/admin/allowlist`처럼 `@RequestBody Map<String, List<Long>>` body), 응답 **204**. 없는 id는 무시(멱등·무해).
- **범위**: bulk-approve(users) + bulk-delete(ads)만. **bulk-sanction 제외**(백엔드 sanction 부재).
- **선택 상태**: 각 컨트롤러 state의 `Set<선택id>`(users=`Set<String>`·ads=`Set<int>`). 재조회(`load()`) 시 새 state로 자연 초기화.
- **DpDataTable**: 선택은 옵셔널 패스스루(`showCheckboxColumn`·`onSelectAll`) — 기존 소비처 불변. go_router/Riverpod 비의존 유지.
- **레포/브랜치**: 백엔드(Task 1~2)=`devpath-platform-svc` 브랜치 `feat/admin-bulk-actions`(Task 1에서 `develop` 분기) → 자체 `develop` PR. 프론트(Task 3~8)=`devpath-frontend` 브랜치 `feat/admin-bulk-actions`(이미 존재, spec 커밋 보유) → 자체 `develop` PR. **모든 git은 `git -C <레포 절대경로>`**. 백엔드 먼저 머지.
- **검증 게이트**: 백엔드 `./gradlew test`(로컬 통합테스트는 `docker run pgvector/pgvector:pg16` + DB `devpath` 필요). 프론트 `melos run format`→`analyze`→`test`.
- **커밋 스테이징**: 명시적 파일 경로로 `git add`.

## File Structure

**devpath-platform-svc** (패키지 `ai.devpath.platform`):
- `beta/AdminBetaService.java` (수정) — `bulkApprove(List<Long>)`.
- `beta/AdminUserController.java` (수정) — `POST /admin/users/bulk-approve`.
- `ads/AdAdminService.java` (수정) — `bulkDelete(List<Long>)`.
- `ads/AdminAdController.java` (수정) — `POST /admin/ads/bulk-delete`.
- 테스트: `beta/AdminUserControllerTest`(수정)·`ads/AdAdminServiceTest`(수정)·`ads/AdControllerTest`(수정).

**devpath-frontend**:
- `packages/dp_design/lib/src/data/dp_data_table.dart` (수정) — 선택 패스스루.
- `apps/admin/lib/src/widgets/bulk_action_bar.dart` (신규) — 공용 벌크 액션바.
- `apps/admin/lib/src/features/users/{data/users_source,state/users_state,application/users_controller,presentation/users_page}.dart` (수정).
- `apps/admin/lib/src/features/ads/{data/ads_source,state/ads_state,application/ads_controller,presentation/ads_page}.dart` (수정).
- `apps/admin/lib/src/data/admin_mock_fixtures.dart` (수정) — 벌크 목.
- 테스트: `dp_data_table_test`·`users_controller_test`·`users_page_test`·`ads_controller_test`·`ads_page_test`(수정).

---

## Task 1: 백엔드 users 일괄 승인

**Repo:** `devpath-platform-svc`

**Files:**
- Modify: `devpath-platform-svc/src/main/java/ai/devpath/platform/beta/AdminBetaService.java`
- Modify: `devpath-platform-svc/src/main/java/ai/devpath/platform/beta/AdminUserController.java`
- Test: `devpath-platform-svc/src/test/java/ai/devpath/platform/beta/AdminUserControllerTest.java` (테스트 2개 추가)

**Interfaces:**
- Produces: `AdminBetaService.bulkApprove(List<Long> ids)`; `POST /admin/users/bulk-approve {ids:[number]}` → 204.

- [ ] **Step 1: 브랜치 분기(1회)**

```bash
git -C /d/workspace/dpa/devpath-platform-svc fetch origin --quiet
git -C /d/workspace/dpa/devpath-platform-svc checkout -b feat/admin-bulk-actions origin/develop
```

- [ ] **Step 2: 실패 테스트 작성** — `AdminUserControllerTest.java`의 `preApprove_learnerJwt_returns403` 아래(마지막 `}` 앞)에 추가

```java
    @Test
    void bulkApprove_adminJwt_returns204() throws Exception {
        User u1 = createBetaPendingUser("bulk-a-");
        User u2 = createBetaPendingUser("bulk-b-");

        mvc.perform(post("/admin/users/bulk-approve")
                        .header("Authorization", "Bearer " + adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ids\":[" + u1.getId() + "," + u2.getId() + "]}"))
                .andExpect(status().isNoContent());

        org.junit.jupiter.api.Assertions.assertEquals("ACTIVE",
                userRepository.findById(u1.getId()).orElseThrow().getStatus());
        org.junit.jupiter.api.Assertions.assertEquals("ACTIVE",
                userRepository.findById(u2.getId()).orElseThrow().getStatus());
    }

    @Test
    void bulkApprove_learnerJwt_returns403() throws Exception {
        User u = createBetaPendingUser("bulk-learner-");
        mvc.perform(post("/admin/users/bulk-approve")
                        .header("Authorization", "Bearer " + learnerToken(u.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ids\":[" + u.getId() + "]}"))
                .andExpect(status().isForbidden());
    }
```

- [ ] **Step 3: 실패 확인**(로컬 postgres 필요)

```bash
docker ps --format '{{.Names}}' | grep -q dpa-test-pg || docker run -d --name dpa-test-pg -e POSTGRES_USER=devpath -e POSTGRES_PASSWORD=localdev -e POSTGRES_DB=devpath -p 5432:5432 pgvector/pgvector:pg16
cd /d/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*AdminUserControllerTest' --console=plain 2>&1 | tail -8
```
Expected: 컴파일/404 실패(bulk-approve 엔드포인트 없음).

- [ ] **Step 4: `AdminBetaService.bulkApprove` 구현** — `AdminBetaService.java`의 `approveUser` 아래에 추가(파일 상단에 `import java.util.List;` 추가)

```java
    /** 여러 사용자를 일괄 승인. 존재하는 id만 처리(approveUser는 멱등). */
    @Transactional
    public void bulkApprove(List<Long> ids) {
        for (Long id : ids) {
            if (id != null && users.existsById(id)) {
                approveUser(id);
            }
        }
    }
```

- [ ] **Step 5: `AdminUserController` 엔드포인트 추가** — `approve` 아래에 추가(`java.util.List`·`java.util.Map`는 이미 import됨)

```java
    /** 여러 사용자 일괄 승인 — 204. body: {"ids":[<number>]}. */
    @PostMapping("/users/bulk-approve")
    public ResponseEntity<Void> bulkApprove(@RequestBody Map<String, List<Long>> body) {
        betaService.bulkApprove(body.getOrDefault("ids", List.of()));
        return ResponseEntity.noContent().build();
    }
```

- [ ] **Step 6: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*AdminUserControllerTest' --console=plain 2>&1 | tail -6
```
Expected: PASS(기존 + 신규 2).

- [ ] **Step 7: 커밋**

```bash
git -C /d/workspace/dpa/devpath-platform-svc add src/main/java/ai/devpath/platform/beta/AdminBetaService.java src/main/java/ai/devpath/platform/beta/AdminUserController.java src/test/java/ai/devpath/platform/beta/AdminUserControllerTest.java
git -C /d/workspace/dpa/devpath-platform-svc commit -m "feat(admin): 사용자 일괄 승인 POST /admin/users/bulk-approve"
```

---

## Task 2: 백엔드 ads 일괄 삭제 + PR

**Repo:** `devpath-platform-svc`

**Files:**
- Modify: `devpath-platform-svc/src/main/java/ai/devpath/platform/ads/AdAdminService.java`
- Modify: `devpath-platform-svc/src/main/java/ai/devpath/platform/ads/AdminAdController.java`
- Test: `devpath-platform-svc/src/test/java/ai/devpath/platform/ads/AdAdminServiceTest.java` (테스트 1개 추가)

**Interfaces:**
- Produces: `AdAdminService.bulkDelete(List<Long> ids)`; `POST /admin/ads/bulk-delete {ids:[number]}` → 204.

- [ ] **Step 1: 실패 테스트 작성** — `AdAdminServiceTest.java`의 마지막 `}` 앞에 추가

```java
  @Test
  void bulkDeleteRemovesExistingIgnoresMissing() {
    AdRow a = service.create(new AdRequest("벌크1", null, "https://e.com", "DASHBOARD_TOP", 1, "ACTIVE", null, null));
    AdRow b = service.create(new AdRequest("벌크2", null, "https://e.com", "DASHBOARD_TOP", 1, "ACTIVE", null, null));

    service.bulkDelete(java.util.List.of(a.id(), b.id(), 999999L));

    assertThat(service.list(null, null)).extracting(AdRow::id).doesNotContain(a.id(), b.id());
  }
```

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*AdAdminServiceTest' --console=plain 2>&1 | tail -8
```
Expected: 컴파일 에러(`bulkDelete` 없음).

- [ ] **Step 3: `AdAdminService.bulkDelete` 구현** — `delete` 아래에 추가(`java.util.List`는 이미 import됨)

```java
  /** 여러 광고 일괄 삭제. 존재하는 id만 삭제(없는 id 무시). ad_daily_stats는 FK CASCADE. */
  @Transactional
  public void bulkDelete(List<Long> ids) {
    for (Long id : ids) {
      if (id != null && repo.existsById(id)) {
        repo.deleteById(id);
      }
    }
  }
```

- [ ] **Step 4: `AdminAdController` 엔드포인트 추가** — `delete` 아래에 추가. 파일 상단 import에 `import java.util.Map;` 추가(`java.util.List`는 이미 존재, 어노테이션은 `org.springframework.web.bind.annotation.*` 와일드카드)

```java
  @PostMapping("/bulk-delete")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void bulkDelete(@RequestBody Map<String, List<Long>> body) {
    service.bulkDelete(body.getOrDefault("ids", List.of()));
  }
```

- [ ] **Step 5: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*AdAdminServiceTest' --tests '*AdminUserControllerTest' --console=plain 2>&1 | tail -6
```
Expected: PASS.

- [ ] **Step 6: 컴파일 회귀 + 커밋 + 푸시 + PR**

```bash
cd /d/workspace/dpa/devpath-platform-svc && ./gradlew compileJava compileTestJava --console=plain 2>&1 | tail -3
git -C /d/workspace/dpa/devpath-platform-svc add src/main/java/ai/devpath/platform/ads/AdAdminService.java src/main/java/ai/devpath/platform/ads/AdminAdController.java src/test/java/ai/devpath/platform/ads/AdAdminServiceTest.java
git -C /d/workspace/dpa/devpath-platform-svc commit -m "feat(admin): 광고 일괄 삭제 POST /admin/ads/bulk-delete"
git -C /d/workspace/dpa/devpath-platform-svc push -u origin feat/admin-bulk-actions
```
그 후 `feat/admin-bulk-actions` → `develop` PR(제목 `feat(admin): 벌크 액션 엔드포인트(사용자 일괄 승인·광고 일괄 삭제)`). CI green + 사용자 승인 후 머지. **develop 직접 push 금지.**

---

## Task 3: DpDataTable 선택 패스스루

**Repo:** `devpath-frontend` (브랜치 `feat/admin-bulk-actions` — 이미 체크아웃, spec 보유)

**Files:**
- Modify: `devpath-frontend/packages/dp_design/lib/src/data/dp_data_table.dart`
- Test: `devpath-frontend/packages/dp_design/test/data/dp_data_table_test.dart` (테스트 1개 추가)

**Interfaces:**
- Produces: `DpDataTable({..., bool showCheckboxColumn, ValueChanged<bool?>? onSelectAll})`. 소비 페이지가 `DataRow2(selected:, onSelectChanged:)`로 행 선택.

- [ ] **Step 1: 실패 테스트 작성** — `dp_data_table_test.dart`의 `main()` 안에 추가

```dart
  testWidgets('DpDataTable: showCheckboxColumn 시 체크박스 렌더', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpDataTable(
            minWidth: 400,
            showCheckboxColumn: true,
            columns: [DataColumn2(label: const Text('이름'))],
            rows: [
              DataRow2(
                selected: true,
                onSelectChanged: (_) {},
                cells: [DataCell(const Text('홍길동'))],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsWidgets);
  });
```

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_design && flutter test test/data/dp_data_table_test.dart 2>&1 | tail -8
```
Expected: 컴파일 에러(`showCheckboxColumn` 파라미터 없음).

- [ ] **Step 3: DpDataTable에 선택 패스스루 추가** — `dp_data_table.dart`

생성자에 `this.showCheckboxColumn = false,`·`this.onSelectAll,` 추가, 필드에 추가:
```dart
  final bool showCheckboxColumn;
  final ValueChanged<bool?>? onSelectAll;
```
`DataTable2(...)`에 전달(예: `empty: empty,` 아래):
```dart
      showCheckboxColumn: showCheckboxColumn,
      onSelectAll: onSelectAll,
```

- [ ] **Step 4: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_design && flutter test test/data/dp_data_table_test.dart 2>&1 | tail -6
```
Expected: PASS(기존 1 + 신규 1).

- [ ] **Step 5: 포맷 + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format
git -C /d/workspace/dpa/devpath-frontend add packages/dp_design/lib/src/data/dp_data_table.dart packages/dp_design/test/data/dp_data_table_test.dart
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(dp_design): DpDataTable 선택(체크박스) 패스스루"
```

---

## Task 4: users 선택 상태 + 일괄 승인 컨트롤러

**Repo:** `devpath-frontend`

**Files:**
- Modify: `devpath-frontend/apps/admin/lib/src/features/users/data/users_source.dart`
- Modify: `devpath-frontend/apps/admin/lib/src/features/users/state/users_state.dart`
- Modify: `devpath-frontend/apps/admin/lib/src/features/users/application/users_controller.dart`
- Test: `devpath-frontend/apps/admin/test/features/users/users_controller_test.dart` (테스트 1개 추가)

**Interfaces:**
- Consumes: `POST /admin/users/bulk-approve`(Task 1).
- Produces: `adminUsersBulkApproveProvider`(`Future<void> Function(List<int>)`); `UsersState.selectedIds`(`Set<String>`); `UsersController.toggleSelect(String)`·`selectAll(bool)`·`clearSelection()`·`bulkApprove()`.

- [ ] **Step 1: 실패 테스트 작성** — `users_controller_test.dart`의 `main()` 안에 추가

```dart
  test('bulkApprove: 선택 id로 POST 후 재조회·선택 초기화', () async {
    List<int>? sentIds;
    final c = ProviderContainer(
      overrides: [
        adminUsersFetchProvider.overrideWithValue(({cursor, status}) async =>
            Page(data: [_r('1', 'BETA_PENDING'), _r('2', 'BETA_PENDING')], limit: 20)),
        adminUsersBulkApproveProvider.overrideWithValue((ids) async {
          sentIds = ids;
        }),
      ],
    );
    addTearDown(c.dispose);

    await c.read(adminUsersProvider.notifier).load();
    c.read(adminUsersProvider.notifier).toggleSelect('1');
    c.read(adminUsersProvider.notifier).toggleSelect('2');
    expect(c.read(adminUsersProvider).selectedIds, {'1', '2'});

    await c.read(adminUsersProvider.notifier).bulkApprove();
    expect(sentIds, [1, 2]);
    expect(c.read(adminUsersProvider).selectedIds, isEmpty);
  });
```
그리고 파일 상단 import에 `import 'package:devpath_admin/src/features/users/data/users_source.dart';`가 이미 있음(확인).

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/users/users_controller_test.dart 2>&1 | tail -8
```
Expected: 컴파일 에러(`adminUsersBulkApproveProvider`·`selectedIds`·`toggleSelect` 없음).

- [ ] **Step 3: 소스 provider 추가** — `users_source.dart` 끝에 추가

```dart
typedef AdminUsersBulkApprove = Future<void> Function(List<int> ids);

final adminUsersBulkApproveProvider = Provider<AdminUsersBulkApprove>((ref) {
  final client = ref.watch(apiClientProvider);
  return (ids) => client.post<void>('/admin/users/bulk-approve', body: {'ids': ids});
});
```

- [ ] **Step 4: `UsersState`에 selectedIds 추가** — `users_state.dart`

생성자에 `this.selectedIds = const {},` 추가, 필드 `final Set<String> selectedIds;` 추가, copyWith에 파라미터 `Set<String>? selectedIds,` + 매핑 `selectedIds: selectedIds ?? this.selectedIds,` 추가.

- [ ] **Step 5: `UsersController`에 선택/벌크 메서드 추가** — `users_controller.dart`의 `preApprove` 아래에 추가

```dart
  void toggleSelect(String id) {
    final next = {...state.selectedIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(selectedIds: next, nextCursor: state.nextCursor);
  }

  void selectAll(bool selected) => state = state.copyWith(
    selectedIds: selected ? state.rows.map((r) => r.id).toSet() : <String>{},
    nextCursor: state.nextCursor,
  );

  void clearSelection() => state =
      state.copyWith(selectedIds: <String>{}, nextCursor: state.nextCursor);

  /// 선택된 사용자 일괄 승인 후 목록 재조회(새 state로 선택 초기화).
  Future<void> bulkApprove() async {
    if (state.selectedIds.isEmpty) return;
    await ref.read(adminUsersBulkApproveProvider)(
      state.selectedIds.map(int.parse).toList(),
    );
    await load();
  }
```

- [ ] **Step 6: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/users/users_controller_test.dart 2>&1 | tail -6
```
Expected: PASS(기존 + 신규).

- [ ] **Step 7: 포맷 + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format
git -C /d/workspace/dpa/devpath-frontend add apps/admin/lib/src/features/users/data/users_source.dart apps/admin/lib/src/features/users/state/users_state.dart apps/admin/lib/src/features/users/application/users_controller.dart apps/admin/test/features/users/users_controller_test.dart
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(admin): users 다중선택 상태 + 일괄 승인 컨트롤러"
```

---

## Task 5: users_page 체크박스 + 벌크바 + 공용 BulkActionBar

**Repo:** `devpath-frontend`

**Files:**
- Create: `devpath-frontend/apps/admin/lib/src/widgets/bulk_action_bar.dart`
- Modify: `devpath-frontend/apps/admin/lib/src/features/users/presentation/users_page.dart`
- Test: `devpath-frontend/apps/admin/test/features/users/users_page_test.dart` (테스트 1개 추가)

**Interfaces:**
- Consumes: `UsersController.toggleSelect/selectAll/clearSelection/bulkApprove`(Task 4), `DpDataTable.showCheckboxColumn/onSelectAll`(Task 3).
- Produces: `BulkActionBar({int count, String actionLabel, VoidCallback onAction, VoidCallback onClear})`(공용); users_page 벌크바(`Key('users-bulk-bar')`).

- [ ] **Step 1: 실패 테스트 작성** — `users_page_test.dart`의 `main()` 안에 추가. (기존 테스트의 provider override/호스트 패턴을 그대로 사용하되, 로드된 행에서 첫 체크박스를 탭해 벌크바 등장을 확인)

```dart
  testWidgets('users_page: 행 선택 시 벌크바 등장', (tester) async {
    final container = ProviderContainer(
      overrides: [
        adminUsersFetchProvider.overrideWithValue(({cursor, status}) async =>
            Page(data: [
              AdminUserRow(id: '1', nickname: 'a', email: 'a@x', role: UserRole.learner, status: 'BETA_PENDING'),
            ], limit: 20)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AdminUsersPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('users-bulk-bar')), findsNothing);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('users-bulk-bar')), findsOneWidget);
  });
```
파일 상단 import에 `admin_user_row.dart`·`users_source.dart`·`dp_core`(UserRole)가 필요하면 추가(기존 테스트 import 확인 후 보강).

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/users/users_page_test.dart 2>&1 | tail -8
```
Expected: FAIL(벌크바 없음).

- [ ] **Step 3: 공용 `BulkActionBar` 생성** — `bulk_action_bar.dart`

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 다중 선택 시 등장하는 벌크 액션바(admin 공용).
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.count,
    required this.actionLabel,
    required this.onAction,
    required this.onClear,
  });

  final int count;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Material(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DpSpacing.lg,
          vertical: DpSpacing.sm,
        ),
        child: Row(
          children: [
            Text('선택 $count개', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton(onPressed: onClear, child: const Text('선택 해제')),
            const SizedBox(width: DpSpacing.sm),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: users_page 배선** — `users_page.dart`

상단 import에 `import '../../../widgets/bulk_action_bar.dart';` 추가. `DpDataTable(minWidth: 720,` 에 선택 패스스루 추가:
```dart
              UsersPhase.loaded => DpDataTable(
                minWidth: 720,
                showCheckboxColumn: true,
                onSelectAll: (v) => n.selectAll(v ?? false),
```
각 `DataRow2(`에 선택 상태 추가(cells 위):
```dart
                    DataRow2(
                      selected: s.selectedIds.contains(r.id),
                      onSelectChanged: (_) => n.toggleSelect(r.id),
                      cells: [
```
그리고 body `Column`의 `_PreApproveBar(...)` 아래(Expanded 위)에 벌크바 삽입:
```dart
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: s.selectedIds.isEmpty
                ? const SizedBox.shrink()
                : BulkActionBar(
                    key: const Key('users-bulk-bar'),
                    count: s.selectedIds.length,
                    actionLabel: '승인',
                    onAction: n.bulkApprove,
                    onClear: n.clearSelection,
                  ),
          ),
```

- [ ] **Step 5: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/users/ 2>&1 | tail -8
```
Expected: PASS(기존 users_page/beta + 신규). 기존 테스트가 체크박스 열 추가로 깨지면 셀렉터를 조정(행 텍스트/키 기반).

- [ ] **Step 6: 포맷 + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format
git -C /d/workspace/dpa/devpath-frontend add apps/admin/lib/src/widgets/bulk_action_bar.dart apps/admin/lib/src/features/users/presentation/users_page.dart apps/admin/test/features/users/users_page_test.dart
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(admin): users_page 다중선택 체크박스 + 벌크바(BulkActionBar)"
```

---

## Task 6: ads 선택 상태 + 일괄 삭제 컨트롤러

**Repo:** `devpath-frontend`

**Files:**
- Modify: `devpath-frontend/apps/admin/lib/src/features/ads/data/ads_source.dart`
- Modify: `devpath-frontend/apps/admin/lib/src/features/ads/state/ads_state.dart`
- Modify: `devpath-frontend/apps/admin/lib/src/features/ads/application/ads_controller.dart`
- Test: `devpath-frontend/apps/admin/test/features/ads/ads_controller_test.dart` (테스트 1개 추가)

**Interfaces:**
- Consumes: `POST /admin/ads/bulk-delete`(Task 2).
- Produces: `adBulkDeleteProvider`(`Future<void> Function(List<int>)`); `AdsState.selectedIds`(`Set<int>`); `AdsController.toggleSelect(int)`·`selectAll(bool)`·`clearSelection()`·`bulkDelete()`.

- [ ] **Step 1: 실패 테스트 작성** — `ads_controller_test.dart`의 `main()` 안에 추가

```dart
  test('bulkDelete: 선택 id로 POST 후 재조회·선택 초기화', () async {
    List<int>? sentIds;
    final c = ProviderContainer(
      overrides: [
        adsListProvider.overrideWithValue(({slot, status}) async => [_ad(id: 1), _ad(id: 2)]),
        adSettingsGetProvider.overrideWithValue(() async => false),
        adBulkDeleteProvider.overrideWithValue((ids) async {
          sentIds = ids;
        }),
      ],
    );
    addTearDown(c.dispose);

    await c.read(adsProvider.notifier).load();
    c.read(adsProvider.notifier).toggleSelect(1);
    c.read(adsProvider.notifier).toggleSelect(2);
    expect(c.read(adsProvider).selectedIds, {1, 2});

    await c.read(adsProvider.notifier).bulkDelete();
    expect(sentIds, [1, 2]);
    expect(c.read(adsProvider).selectedIds, isEmpty);
  });
```

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/ads/ads_controller_test.dart 2>&1 | tail -8
```
Expected: 컴파일 에러(`adBulkDeleteProvider`·`selectedIds`·`toggleSelect` 없음).

- [ ] **Step 3: 소스 provider 추가** — `ads_source.dart`의 `adDeleteProvider` 아래에 추가

```dart
typedef AdBulkDelete = Future<void> Function(List<int> ids);

final adBulkDeleteProvider = Provider<AdBulkDelete>((ref) {
  final client = ref.watch(apiClientProvider);
  return (ids) => client.post<void>('/admin/ads/bulk-delete', body: {'ids': ids});
});
```

- [ ] **Step 4: `AdsState`에 selectedIds 추가** — `ads_state.dart`

생성자에 `this.selectedIds = const {},` 추가, 필드 `final Set<int> selectedIds;` 추가, copyWith에 `Set<int>? selectedIds,` + `selectedIds: selectedIds ?? this.selectedIds,` 추가.

- [ ] **Step 5: `AdsController`에 선택/벌크 추가** — `ads_controller.dart`의 `remove` 아래에 추가

```dart
  void toggleSelect(int id) {
    final next = {...state.selectedIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(selectedIds: next);
  }

  void selectAll(bool selected) => state = state.copyWith(
    selectedIds: selected ? state.rows.map((r) => r.id).whereType<int>().toSet() : <int>{},
  );

  void clearSelection() => state = state.copyWith(selectedIds: <int>{});

  /// 선택된 광고 일괄 삭제 후 목록 재조회(새 state로 선택 초기화).
  Future<void> bulkDelete() async {
    if (state.selectedIds.isEmpty) return;
    await ref.read(adBulkDeleteProvider)(state.selectedIds.toList());
    await load();
  }
```

- [ ] **Step 6: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/ads/ads_controller_test.dart 2>&1 | tail -6
```
Expected: PASS.

- [ ] **Step 7: 포맷 + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format
git -C /d/workspace/dpa/devpath-frontend add apps/admin/lib/src/features/ads/data/ads_source.dart apps/admin/lib/src/features/ads/state/ads_state.dart apps/admin/lib/src/features/ads/application/ads_controller.dart apps/admin/test/features/ads/ads_controller_test.dart
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(admin): ads 다중선택 상태 + 일괄 삭제 컨트롤러"
```

---

## Task 7: ads_page 체크박스 + 벌크바

**Repo:** `devpath-frontend`

**Files:**
- Modify: `devpath-frontend/apps/admin/lib/src/features/ads/presentation/ads_page.dart`
- Test: `devpath-frontend/apps/admin/test/features/ads/ads_page_test.dart` (테스트 1개 추가)

**Interfaces:**
- Consumes: `AdsController.toggleSelect/selectAll/clearSelection/bulkDelete`(Task 6), `BulkActionBar`(Task 5), `DpDataTable` 선택(Task 3).
- Produces: ads_page 벌크바(`Key('ads-bulk-bar')`).

- [ ] **Step 1: 실패 테스트 작성** — `ads_page_test.dart`의 `main()` 안에 추가(기존 provider override/호스트 패턴 사용)

```dart
  testWidgets('ads_page: 행 선택 시 벌크바 등장', (tester) async {
    final container = ProviderContainer(
      overrides: [
        adsListProvider.overrideWithValue(({slot, status}) async => [
          AdRow(id: 1, title: 't', imageUrl: null, linkUrl: 'https://e.com', slot: 'DASHBOARD_TOP', weight: 1, status: 'ACTIVE', startsAt: null, endsAt: null),
        ]),
        adSettingsGetProvider.overrideWithValue(() async => false),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AdminAdsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ads-bulk-bar')), findsNothing);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ads-bulk-bar')), findsOneWidget);
  });
```
(ads_page의 public 위젯 클래스명 = `AdminAdsPage`(실측). 기존 `ads_page_test.dart` import에 `AdRow`·`ads_source`·`ads_page`·`dp_core`가 있으면 재사용, 없으면 보강.)

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/ads/ads_page_test.dart 2>&1 | tail -8
```
Expected: FAIL(벌크바 없음).

- [ ] **Step 3: ads_page 배선** — `ads_page.dart`

상단 import에 `import '../../../widgets/bulk_action_bar.dart';` 추가. `DpDataTable(minWidth: 760,`에 `showCheckboxColumn: true, onSelectAll: (v) => n.selectAll(v ?? false),` 추가. 각 `DataRow2(`에 `selected: s.selectedIds.contains(r.id), onSelectChanged: (_) => n.toggleSelect(r.id!),` 추가(AdRow.id는 `int?` → `r.id!`). 그리고 `Scaffold`의 body를 `Column`으로 감싸 벌크바 + 기존 switch를 배치:
```dart
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: s.selectedIds.isEmpty
                ? const SizedBox.shrink()
                : BulkActionBar(
                    key: const Key('ads-bulk-bar'),
                    count: s.selectedIds.length,
                    actionLabel: '삭제',
                    onAction: n.bulkDelete,
                    onClear: n.clearSelection,
                  ),
          ),
          Expanded(
            child: switch (s.phase) {
              // ... 기존 switch 본문 그대로 ...
            },
          ),
        ],
      ),
```
(기존 `body: switch (...)`를 위 구조로 이동. FAB·appBar 등 나머지는 불변.)

- [ ] **Step 4: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/ads/ 2>&1 | tail -8
```
Expected: PASS(기존 ads_page/route/controller + 신규).

- [ ] **Step 5: 포맷 + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format
git -C /d/workspace/dpa/devpath-frontend add apps/admin/lib/src/features/ads/presentation/ads_page.dart apps/admin/test/features/ads/ads_page_test.dart
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(admin): ads_page 다중선택 체크박스 + 벌크바"
```

---

## Task 8: 목 픽스처 + 전체 게이트 + PR

**Repo:** `devpath-frontend`

**Files:**
- Modify: `devpath-frontend/apps/admin/lib/src/data/admin_mock_fixtures.dart`

**Interfaces:**
- Consumes: 전 Task.
- Produces: 목 모드에서 벌크 액션 204 응답.

- [ ] **Step 1: 목 픽스처에 벌크 엔드포인트 추가** — `admin_mock_fixtures.dart`의 `'POST /admin/users/u1/sanction': (200, {'ok': true}),` 아래에 추가

```dart
  'POST /admin/users/bulk-approve': (204, <String, dynamic>{}),
  'POST /admin/ads/bulk-delete': (204, <String, dynamic>{}),
```

- [ ] **Step 2: 프론트 전체 게이트**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format 2>&1 | tail -3
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run analyze 2>&1 | tail -4
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run test 2>&1 | tail -8
```
Expected: format 0 changed·analyze 전 패키지 통과·test 전 패키지 SUCCESS(admin 신규 포함).

- [ ] **Step 3: 커밋 + 푸시 + PR**

```bash
git -C /d/workspace/dpa/devpath-frontend add apps/admin/lib/src/data/admin_mock_fixtures.dart
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(admin): 벌크 액션 목 픽스처(bulk-approve·bulk-delete 204)"
git -C /d/workspace/dpa/devpath-frontend push -u origin feat/admin-bulk-actions
```
그 후 `feat/admin-bulk-actions` → `develop` PR(제목 `feat(admin): 벌크 액션 UI(다중선택·벌크바)`). CI(`analyze-test`) green + 사용자 승인 후 머지.

---

## 통합 검증(양 레포 머지 후)

- 백엔드·프론트 PR 각각 CI green + 사용자 승인 → 머지(백엔드 먼저). 로컬 목 모드는 Task 8 픽스처로 즉시 확인(users/ads 체크박스 선택 → 벌크바 → 승인/삭제).
- 실서버 스모크(선택): admin `flutter run -d chrome --dart-define-from-file=.env.local` → users/ads 다중선택 벌크.
