import 'dart:async';

import 'package:devpath_admin/src/features/users/application/users_controller.dart';
import 'package:devpath_admin/src/features/users/data/admin_user_row.dart';
import 'package:devpath_admin/src/features/users/data/users_source.dart';
import 'package:devpath_admin/src/features/users/state/users_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdminUserRow _user(String id, String status) => AdminUserRow(
  id: id,
  nickname: id,
  email: '$id@example.com',
  role: UserRole.learner,
  status: status,
);

void main() {
  test(
    'an older successful load cannot replace the latest user filter',
    () async {
      final active = Completer<Page<AdminUserRow>>();
      final suspended = Completer<Page<AdminUserRow>>();
      final requestedStatuses = <String?>[];
      final container = ProviderContainer(
        overrides: [
          adminUsersFetchProvider.overrideWithValue(({cursor, status}) {
            requestedStatuses.add(status);
            return switch (status) {
              'ACTIVE' => active.future,
              'SUSPENDED' => suspended.future,
              _ => throw StateError('unexpected user status: $status'),
            };
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(adminUsersProvider.notifier);
      final olderRequest = notifier.setStatusFilter('ACTIVE');
      final latestRequest = notifier.setStatusFilter('SUSPENDED');
      expect(requestedStatuses, ['ACTIVE', 'SUSPENDED']);

      suspended.complete(Page(data: [_user('latest', 'SUSPENDED')], limit: 20));
      await latestRequest;
      active.complete(Page(data: [_user('older', 'ACTIVE')], limit: 20));
      await olderRequest;

      final state = container.read(adminUsersProvider);
      expect(state.phase, UsersPhase.loaded);
      expect(state.statusFilter, 'SUSPENDED');
      expect(state.rows.single.id, 'latest');
    },
  );

  test(
    'an older load-more page cannot append into the latest user filter',
    () async {
      final olderPage = Completer<Page<AdminUserRow>>();
      final requested = <({String? cursor, String? status})>[];
      final container = ProviderContainer(
        overrides: [
          adminUsersFetchProvider.overrideWithValue(({cursor, status}) {
            requested.add((cursor: cursor, status: status));
            if (cursor == 'active-page-2' && status == 'ACTIVE') {
              return olderPage.future;
            }
            if (cursor == null && status == 'ACTIVE') {
              return Future.value(
                Page(
                  data: [_user('active-page-1', 'ACTIVE')],
                  limit: 20,
                  nextCursor: 'active-page-2',
                ),
              );
            }
            if (cursor == null && status == 'SUSPENDED') {
              return Future.value(
                Page(data: [_user('latest', 'SUSPENDED')], limit: 20),
              );
            }
            throw StateError('unexpected user request: $cursor / $status');
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(adminUsersProvider.notifier);
      await notifier.setStatusFilter('ACTIVE');
      final staleLoadMore = notifier.loadMore();
      final latestLoad = notifier.setStatusFilter('SUSPENDED');
      await latestLoad;

      olderPage.complete(
        Page(data: [_user('stale-page-2', 'ACTIVE')], limit: 20),
      );
      await staleLoadMore;

      expect(requested, [
        (cursor: null, status: 'ACTIVE'),
        (cursor: 'active-page-2', status: 'ACTIVE'),
        (cursor: null, status: 'SUSPENDED'),
      ]);
      final state = container.read(adminUsersProvider);
      expect(state.phase, UsersPhase.loaded);
      expect(state.statusFilter, 'SUSPENDED');
      expect(state.rows.map((row) => row.id), ['latest']);
    },
  );
}
