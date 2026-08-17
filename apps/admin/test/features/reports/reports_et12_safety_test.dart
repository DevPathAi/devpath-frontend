import 'dart:async';

import 'package:devpath_admin/src/features/reports/application/reports_controller.dart';
import 'package:devpath_admin/src/features/reports/data/report.dart';
import 'package:devpath_admin/src/features/reports/data/reports_source.dart';
import 'package:devpath_admin/src/features/reports/state/reports_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _report = AdminReport(
  id: 3,
  targetType: 'POST',
  targetId: 9,
  targetTitle: '검토 대상',
  targetExcerpt: '본문',
  targetPath: '/community/post/9',
  category: 'SPAM',
  reason: '반복 게시',
  reportCount: 2,
  status: 'OPEN',
  createdAt: null,
);

void main() {
  test(
    'decision failure returns error and retains rows and exact filter',
    () async {
      final container = ProviderContainer(
        overrides: [
          reportsListFetchProvider.overrideWithValue(
            ({status, required page, required size}) async => const [_report],
          ),
          reportDecisionProvider.overrideWithValue(
            (id, action) async => throw const ApiException(
              code: ApiErrorCode.unknown,
              message: '판정 저장 실패',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(reportsProvider.notifier)
          .load(status: 'VENDOR_REVIEW');
      final before = container.read(reportsProvider);
      expect(before.status, 'VENDOR_REVIEW');

      expect(
        await container.read(reportsProvider.notifier).resolve(3, 'REJECT'),
        '판정 저장 실패',
      );
      expect(container.read(reportsProvider), same(before));
      expect((container.read(reportsProvider) as ReportsLoaded).reports, [
        _report,
      ]);
    },
  );

  test(
    'loading and failed states retain the exact requested filter for retry',
    () async {
      final pending = Completer<List<AdminReport>>();
      final container = ProviderContainer(
        overrides: [
          reportsListFetchProvider.overrideWithValue(
            ({status, required page, required size}) => pending.future,
          ),
        ],
      );
      addTearDown(container.dispose);

      final request = container
          .read(reportsProvider.notifier)
          .load(status: 'VENDOR_REVIEW');
      expect(container.read(reportsProvider).status, 'VENDOR_REVIEW');
      pending.completeError(
        const ApiException(code: ApiErrorCode.unknown, message: '조회 실패'),
      );
      await request;
      expect(container.read(reportsProvider), isA<ReportsFailed>());
      expect(container.read(reportsProvider).status, 'VENDOR_REVIEW');
    },
  );
}
