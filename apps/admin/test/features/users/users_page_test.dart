import 'package:devpath_admin/src/features/users/application/users_controller.dart';
import 'package:devpath_admin/src/features/users/data/admin_user_row.dart';
import 'package:devpath_admin/src/features/users/data/users_source.dart';
import 'package:devpath_admin/src/features/users/presentation/users_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart' hide Page; // dp_core Page와 심볼 충돌 회피
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('테이블 렌더 + 행 선택 시 제재 패널', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = ProviderContainer(overrides: [
      adminUsersFetchProvider.overrideWithValue(({String? cursor, String? status}) async =>
          Page(data: [
            AdminUserRow(id: 'u1', nickname: '지수', email: 'a@x', role: UserRole.learner, status: 'ACTIVE'),
          ], limit: 20)),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: DpTheme.light(), home: const AdminUsersPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('지수'), findsOneWidget);
    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();
    expect(find.text('영구 밴'), findsOneWidget); // 제재 패널
  });
}
