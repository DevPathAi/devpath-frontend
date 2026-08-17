import 'package:devpath_admin/src/features/reports/data/report.dart';
import 'package:devpath_admin/src/features/reports/data/reports_source.dart';
import 'package:devpath_admin/src/features/reports/presentation/reports_page.dart';
import 'package:devpath_admin/src/features/reports/application/reports_controller.dart';
import 'package:devpath_admin/src/features/reports/state/reports_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _row = AdminReport(
  id: 47,
  targetType: 'POST',
  targetId: 99,
  targetTitle: '삭제 여부를 신중하게 판단해야 하는 긴 신고 제목',
  targetExcerpt: '신고 대상 본문',
  targetPath: '/community/post/99',
  category: 'SPAM',
  reason: '반복 게시',
  reportCount: 4,
  status: 'OPEN',
  createdAt: null,
);

class _FilteredReports extends ReportsController {
  @override
  ReportsState build() => const ReportsLoaded([_row], status: 'VENDOR_REVIEW');
}

void main() {
  testWidgets(
    'failed report decision retains row/filter/dialog/confirmation input',
    (tester) async {
      late ProviderContainer container;
      container = ProviderContainer(
        overrides: [
          reportsProvider.overrideWith(_FilteredReports.new),
          reportDecisionProvider.overrideWithValue(
            (id, action) async => throw const ApiException(
              code: ApiErrorCode.unknown,
              message: '판정 저장 실패',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: DpTheme.light(), home: const ReportsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('기각'));
      await tester.pumpAndSettle();
      expect(find.text('신고 기각'), findsOneWidget);
      expect(find.textContaining('판정은 즉시 반영'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('admin-danger-confirmation-input')),
        '신고 #47',
      );
      await tester.pump();
      await tester.tap(find.text('기각 확정'));
      await tester.pumpAndSettle();

      expect(find.text('판정 저장 실패'), findsOneWidget);
      expect(find.text('신고 #47'), findsOneWidget);
      expect(find.text(_row.targetTitle!), findsOneWidget);
      expect(container.read(reportsProvider).status, 'VENDOR_REVIEW');
      expect(tester.takeException(), isNull);
    },
  );
}
