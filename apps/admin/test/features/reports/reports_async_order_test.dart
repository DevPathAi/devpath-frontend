import 'dart:async';

import 'package:devpath_admin/src/features/reports/application/reports_controller.dart';
import 'package:devpath_admin/src/features/reports/data/report.dart';
import 'package:devpath_admin/src/features/reports/data/reports_source.dart';
import 'package:devpath_admin/src/features/reports/state/reports_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdminReport _report(int id, {String status = 'OPEN'}) => AdminReport(
  id: id,
  targetType: 'POST',
  targetId: id,
  targetTitle: 'report-$id',
  targetExcerpt: 'excerpt-$id',
  targetPath: '/community/post/$id',
  category: 'SPAM',
  reason: 'reason-$id',
  reportCount: 1,
  status: status,
  createdAt: null,
);

class _ReportsWithoutInitialLoad extends ReportsController {
  @override
  ReportsState build() => const ReportsLoaded([], status: 'OPEN');
}

class _ReportsWithOpenRow extends ReportsController {
  @override
  ReportsState build() => ReportsLoaded([_report(7)], status: 'OPEN');
}

void main() {
  test(
    'an older successful load cannot replace the latest report filter',
    () async {
      final open = Completer<List<AdminReport>>();
      final resolved = Completer<List<AdminReport>>();
      final requestedStatuses = <String?>[];
      final container = ProviderContainer(
        overrides: [
          reportsProvider.overrideWith(_ReportsWithoutInitialLoad.new),
          reportsListFetchProvider.overrideWithValue(({
            status,
            required page,
            required size,
          }) {
            requestedStatuses.add(status);
            return switch (status) {
              'OPEN' => open.future,
              'RESOLVED' => resolved.future,
              _ => throw StateError('unexpected report status: $status'),
            };
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reportsProvider.notifier);
      final olderRequest = notifier.load(status: 'OPEN');
      final latestRequest = notifier.load(status: 'RESOLVED');
      expect(requestedStatuses, ['OPEN', 'RESOLVED']);

      resolved.complete([_report(2, status: 'RESOLVED')]);
      await latestRequest;
      open.complete([_report(1)]);
      await olderRequest;

      final state = container.read(reportsProvider);
      expect(
        state,
        isA<ReportsLoaded>(),
        reason:
            'the last-completed older request must not replace the latest load',
      );
      expect(state.status, 'RESOLVED');
      expect((state as ReportsLoaded).reports.single.id, 2);
    },
  );

  test(
    'an older failed load cannot replace the latest report success',
    () async {
      final open = Completer<List<AdminReport>>();
      final rejected = Completer<List<AdminReport>>();
      final container = ProviderContainer(
        overrides: [
          reportsProvider.overrideWith(_ReportsWithoutInitialLoad.new),
          reportsListFetchProvider.overrideWithValue(
            ({status, required page, required size}) => switch (status) {
              'OPEN' => open.future,
              'REJECTED' => rejected.future,
              _ => throw StateError('unexpected report status: $status'),
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reportsProvider.notifier);
      final olderRequest = notifier.load(status: 'OPEN');
      final latestRequest = notifier.load(status: 'REJECTED');

      rejected.complete([_report(3, status: 'REJECTED')]);
      await latestRequest;
      open.completeError(
        const ApiException(
          code: ApiErrorCode.unknown,
          message: 'stale failure',
        ),
      );
      await olderRequest;

      final state = container.read(reportsProvider);
      expect(
        state,
        isA<ReportsLoaded>(),
        reason: 'a stale failure must not hide a newer successful result',
      );
      expect(state.status, 'REJECTED');
      expect((state as ReportsLoaded).reports.single.id, 3);
    },
  );

  test(
    'decision-triggered reload retains the filter selected meanwhile',
    () async {
      final decision = Completer<void>();
      final requestedStatuses = <String?>[];
      var fetchCount = 0;
      final container = ProviderContainer(
        overrides: [
          reportsProvider.overrideWith(_ReportsWithOpenRow.new),
          reportDecisionProvider.overrideWithValue(
            (id, action) => decision.future,
          ),
          reportsListFetchProvider.overrideWithValue(({
            status,
            required page,
            required size,
          }) async {
            requestedStatuses.add(status);
            fetchCount++;
            return [_report(10 + fetchCount, status: status ?? 'OPEN')];
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reportsProvider.notifier);
      final mutation = notifier.resolve(7, 'RESOLVE');
      await notifier.load(status: 'REJECTED');
      decision.complete();
      expect(await mutation, isNull);

      final state = container.read(reportsProvider);
      expect(
        requestedStatuses,
        ['REJECTED', 'REJECTED'],
        reason: 'the post-decision refresh must use the current filter',
      );
      expect(state.status, 'REJECTED');
      expect((state as ReportsLoaded).reports.single.status, 'REJECTED');
    },
  );
}
