import 'package:devpath_admin/src/features/users/data/admin_user_row.dart';
import 'package:devpath_admin/src/features/users/data/users_source.dart';
import 'package:devpath_admin/src/features/users/presentation/users_page.dart';
import 'package:devpath_admin/src/features/users/application/users_controller.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _active = AdminUserRow(
  id: 'u1',
  nickname: '운영 대상',
  email: 'operator-target@example.com',
  role: UserRole.learner,
  status: 'ACTIVE',
);

const _pending = AdminUserRow(
  id: '1',
  nickname: '승인 대기 사용자',
  email: 'pending@example.com',
  role: UserRole.learner,
  status: 'BETA_PENDING',
);

const _unknown = AdminUserRow(
  id: '3',
  nickname: '외부 상태 사용자',
  email: 'unknown@example.com',
  role: UserRole.learner,
  status: 'VENDOR_ESCALATED',
);

Widget _app({AdminUserSanction? sanction, AdminUserPreApprove? preApprove}) =>
    ProviderScope(
      overrides: [
        adminUsersFetchProvider.overrideWithValue(
          ({cursor, status}) async => const Page(data: [_active], limit: 20),
        ),
        if (sanction != null)
          adminUserSanctionProvider.overrideWithValue(sanction),
        if (preApprove != null)
          adminUserPreApproveProvider.overrideWithValue(preApprove),
      ],
      child: MaterialApp(theme: DpTheme.light(), home: const AdminUsersPage()),
    );

void main() {
  testWidgets('sanction shows impact and failure remains in confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        sanction: (id, action) async => throw const ApiException(
          code: ApiErrorCode.unknown,
          message: '제재 저장 실패',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(DpIcons.moreVert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('영구 밴'));
    await tester.pumpAndSettle();

    expect(find.text('영구 밴 적용'), findsOneWidget);
    expect(find.textContaining('계정 사용에 즉시 영향'), findsOneWidget);
    await tester.tap(find.text('조치 적용'));
    await tester.pumpAndSettle();

    expect(find.text('제재 저장 실패'), findsOneWidget);
    expect(find.text('운영 대상'), findsOneWidget);
  });

  testWidgets('pre-approval failure keeps the entered email', (tester) async {
    tester.view.physicalSize = const Size(1240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        preApprove: (email) async => throw const ApiException(
          code: ApiErrorCode.unknown,
          message: '허용 목록 저장 실패',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'keep@example.com');
    await tester.tap(find.text('허용리스트 추가'));
    await tester.pumpAndSettle();

    expect(find.text('허용 목록 저장 실패'), findsOneWidget);
    expect(find.text('keep@example.com'), findsOneWidget);
  });

  testWidgets(
    'only BETA_PENDING rows are selectable and bulk approval confirms impact',
    (tester) async {
      late ProviderContainer container;
      container = ProviderContainer(
        overrides: [
          adminUsersFetchProvider.overrideWithValue(
            ({cursor, status}) async =>
                const Page(data: [_pending, _active, _unknown], limit: 20),
          ),
          adminUsersBulkApproveProvider.overrideWithValue(
            (ids) async => throw const ApiException(
              code: ApiErrorCode.unknown,
              message: '일괄 승인 실패',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: DpTheme.light(),
            home: const AdminUsersPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes[1].onChanged, isNotNull);
      expect(checkboxes[2].onChanged, isNull);
      expect(checkboxes[3].onChanged, isNull);

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '승인'));
      await tester.pumpAndSettle();

      expect(find.text('선택한 사용자 1명 승인'), findsOneWidget);
      expect(find.textContaining('베타 접근 권한'), findsOneWidget);
      await tester.tap(find.text('1명 승인'));
      await tester.pumpAndSettle();

      expect(find.text('일괄 승인 실패'), findsOneWidget);
      expect(container.read(adminUsersProvider).selectedIds, {'1'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'single approval failure stays in impact dialog without throwing',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminUsersFetchProvider.overrideWithValue(
              ({cursor, status}) async =>
                  const Page(data: [_pending], limit: 20),
            ),
            adminUsersApproveProvider.overrideWithValue(
              (id) async => throw const ApiException(
                code: ApiErrorCode.unknown,
                message: '승인 저장 실패',
              ),
            ),
          ],
          child: MaterialApp(
            theme: DpTheme.light(),
            home: const AdminUsersPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(DpIcons.moreVert));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, '승인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('승인 확정'));
      await tester.pumpAndSettle();

      expect(find.text('승인 저장 실패'), findsOneWidget);
      expect(find.text('승인 대기 사용자'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
