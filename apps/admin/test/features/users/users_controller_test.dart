import 'package:devpath_admin/src/features/users/application/users_controller.dart';
import 'package:devpath_admin/src/features/users/data/admin_user_row.dart';
import 'package:devpath_admin/src/features/users/data/users_source.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdminUserRow _r(String id, String status) => AdminUserRow(
  id: id,
  nickname: id,
  email: '$id@x',
  role: UserRole.learner,
  status: status,
);

void main() {
  test('로드 + 상태 필터', () async {
    final c = ProviderContainer(
      overrides: [
        adminUsersFetchProvider.overrideWithValue(({
          String? cursor,
          String? status,
        }) async {
          final all = [_r('u1', 'ACTIVE'), _r('u2', 'SUSPENDED')];
          final data = status == null
              ? all
              : all.where((e) => e.status == status).toList();
          return Page(data: data, limit: 20);
        }),
      ],
    );
    addTearDown(c.dispose);

    await c.read(adminUsersProvider.notifier).load();
    expect(c.read(adminUsersProvider).rows, hasLength(2));

    await c.read(adminUsersProvider.notifier).setStatusFilter('SUSPENDED');
    final s = c.read(adminUsersProvider);
    expect(s.rows.map((e) => e.id), ['u2']);
    expect(s.statusFilter, 'SUSPENDED');

    await c.read(adminUsersProvider.notifier).setStatusFilter(null);
    expect(c.read(adminUsersProvider).statusFilter, isNull);
    expect(c.read(adminUsersProvider).rows, hasLength(2));
  });

  test(
    'sanction sends the existing action wire through its provider seam',
    () async {
      String? sentId;
      String? sentAction;
      final c = ProviderContainer(
        overrides: [
          adminUserSanctionProvider.overrideWithValue((id, action) async {
            sentId = id;
            sentAction = action;
          }),
        ],
      );
      addTearDown(c.dispose);

      await c.read(adminUsersProvider.notifier).sanction('u9', '영구 밴');
      expect((sentId, sentAction), ('u9', '영구 밴'));
    },
  );

  test('bulkApprove: 선택 id로 POST 후 재조회·선택 초기화', () async {
    List<int>? sentIds;
    final c = ProviderContainer(
      overrides: [
        adminUsersFetchProvider.overrideWithValue(
          ({cursor, status}) async => Page(
            data: [_r('1', 'BETA_PENDING'), _r('2', 'BETA_PENDING')],
            limit: 20,
          ),
        ),
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
}
