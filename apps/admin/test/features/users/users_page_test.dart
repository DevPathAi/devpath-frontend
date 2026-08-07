import 'package:devpath_admin/src/features/users/data/admin_user_row.dart';
import 'package:devpath_admin/src/features/users/data/users_source.dart';
import 'package:devpath_admin/src/features/users/presentation/users_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart' hide Page; // dp_core Page와 심볼 충돌 회피
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devpath_admin/src/features/shell/presentation/admin_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AdminUsersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('지수'), findsOneWidget);
    // 행 MenuAnchor 열기 → 제재 메뉴
    await tester.tap(find.byIcon(DpIcons.moreVert));
    await tester.pumpAndSettle();
    expect(find.text('영구 밴'), findsOneWidget);
  });

  testWidgets('users_page: 행 선택 시 벌크바 등장', (tester) async {
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
                status: 'BETA_PENDING',
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
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AdminUsersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('users-bulk-bar')), findsNothing);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('users-bulk-bar')), findsOneWidget);
  });

  testWidgets('DpPageHeader 제목은 "사용자 관리" + 상태 필터가 filters 슬롯에 렌더', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = ProviderContainer(
      overrides: [
        adminUsersFetchProvider.overrideWithValue(
          ({String? cursor, String? status}) async =>
              Page(data: const [], limit: 20),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AdminUsersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '사용자 관리');
    // 화면이 실제로 adminHeaderTitleFor를 호출한다는 것만 확인한다(경로 인자 오타 등).
    // 상수 값 변경 감지는 위 리터럴 단언의 몫이고, 화면이 같은 값의 리터럴로 퇴행하는
    // 방향은 admin_title_source_test의 소스 검사가 막는다.
    expect(header.title, adminHeaderTitleFor('/users'));
    expect(find.byKey(const ValueKey('page-header-filters')), findsOneWidget);
  });
}
