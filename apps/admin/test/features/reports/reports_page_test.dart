import 'package:devpath_admin/src/features/reports/application/reports_controller.dart';
import 'package:devpath_admin/src/features/reports/data/report.dart';
import 'package:devpath_admin/src/features/reports/presentation/reports_page.dart';
import 'package:devpath_admin/src/features/reports/state/reports_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake extends ReportsController {
  @override
  build() => ReportsLoaded([
        const Report(id: 'r1', type: 'POST', targetTitle: '스팸 글', reason: '광고', status: 'OPEN'),
      ]);
}

void main() {
  testWidgets('신고 목록 렌더 + 처리 버튼', (tester) async {
    final c = ProviderContainer(overrides: [
      reportsProvider.overrideWith(() => _Fake()),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: DpTheme.light(), home: const ReportsPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('스팸 글'), findsOneWidget);
    expect(find.text('처리'), findsWidgets);
  });
}
