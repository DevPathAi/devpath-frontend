import 'dart:async';

import 'package:devpath_admin/src/features/support/application/support_controller.dart';
import 'package:devpath_admin/src/features/support/data/support_request.dart';
import 'package:devpath_admin/src/features/support/data/support_source.dart';
import 'package:devpath_admin/src/features/support/state/support_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SupportRequestRow _row(
  int id, {
  String status = 'OPEN',
  String type = 'INQUIRY',
}) => SupportRequestRow(
  id: id,
  type: type,
  title: 'support-$id',
  status: status,
  failureCount: 0,
);

class _SupportWithoutInitialLoad extends SupportListController {
  @override
  SupportListState build() => const SupportListLoaded([], status: 'OPEN');
}

class _SupportWithOpenRow extends SupportListController {
  @override
  SupportListState build() =>
      SupportListLoaded([_row(7)], status: 'OPEN', type: 'INQUIRY');
}

void main() {
  test(
    'an older successful load cannot replace the latest support filters',
    () async {
      final inquiries = Completer<List<SupportRequestRow>>();
      final errors = Completer<List<SupportRequestRow>>();
      final requestedFilters = <({String? status, String? type})>[];
      final container = ProviderContainer(
        overrides: [
          supportListProvider.overrideWith(_SupportWithoutInitialLoad.new),
          supportListFetchProvider.overrideWithValue(({
            status,
            type,
            required limit,
          }) {
            requestedFilters.add((status: status, type: type));
            return switch ((status, type)) {
              ('OPEN', 'INQUIRY') => inquiries.future,
              ('RESOLVED', 'ERROR') => errors.future,
              _ => throw StateError(
                'unexpected support filters: $status/$type',
              ),
            };
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(supportListProvider.notifier);
      final olderRequest = notifier.load(status: 'OPEN', type: 'INQUIRY');
      final latestRequest = notifier.load(status: 'RESOLVED', type: 'ERROR');
      expect(requestedFilters, [
        (status: 'OPEN', type: 'INQUIRY'),
        (status: 'RESOLVED', type: 'ERROR'),
      ]);

      errors.complete([_row(2, status: 'RESOLVED', type: 'ERROR')]);
      await latestRequest;
      inquiries.complete([_row(1)]);
      await olderRequest;

      final state = container.read(supportListProvider);
      expect(state, isA<SupportListLoaded>());
      expect((state.status, state.type), ('RESOLVED', 'ERROR'));
      expect((state as SupportListLoaded).rows.single.id, 2);
    },
  );

  test(
    'mutation-triggered reload retains filters selected meanwhile',
    () async {
      final update = Completer<void>();
      final requestedFilters = <({String? status, String? type})>[];
      var fetchCount = 0;
      final container = ProviderContainer(
        overrides: [
          supportListProvider.overrideWith(_SupportWithOpenRow.new),
          supportStatusUpdateProvider.overrideWithValue(
            (id, status, {adminNote}) => update.future,
          ),
          supportListFetchProvider.overrideWithValue(({
            status,
            type,
            required limit,
          }) async {
            requestedFilters.add((status: status, type: type));
            fetchCount++;
            return [
              _row(
                10 + fetchCount,
                status: status ?? 'OPEN',
                type: type ?? 'INQUIRY',
              ),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(supportListProvider.notifier);
      final mutation = notifier.updateStatus(7, 'IN_PROGRESS');
      await notifier.load(status: 'RESOLVED', type: 'ERROR');
      update.complete();
      expect(await mutation, isNull);

      final state = container.read(supportListProvider);
      expect(
        requestedFilters,
        [
          (status: 'RESOLVED', type: 'ERROR'),
          (status: 'RESOLVED', type: 'ERROR'),
        ],
        reason: 'the post-mutation refresh must use the current filters',
      );
      expect((state.status, state.type), ('RESOLVED', 'ERROR'));
      expect((state as SupportListLoaded).rows.single.status, 'RESOLVED');
    },
  );
}
