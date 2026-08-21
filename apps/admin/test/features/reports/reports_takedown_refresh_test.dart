import 'package:devpath_admin/src/features/reports/application/reports_controller.dart';
import 'package:devpath_admin/src/features/reports/data/report.dart';
import 'package:devpath_admin/src/features/reports/data/reports_source.dart';
import 'package:devpath_admin/src/features/reports/presentation/reports_page.dart';
import 'package:devpath_admin/src/features/reports/state/reports_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 내리기 성공 뒤 목록 재조회 계약. 재조회가 없으면 내린 카드가 계속 `내리기` 를 내밀고,
/// 다시 확정하면 같은 대상에 재요청 → 404 다. 재조회하면 isTargetGone 이 버튼을 감춘다.
AdminReport _r() => const AdminReport(
  id: 1,
  targetType: 'POST',
  targetId: 10,
  targetTitle: '스팸 글',
  targetExcerpt: '본문 일부…',
  targetPath: '/community/post/10',
  category: 'AD',
  reason: '광고글입니다',
  reportCount: 1,
  status: 'OPEN',
  createdAt: '2026-08-02T09:00:00Z',
);

class _CountingFake extends ReportsController {
  _CountingFake(this.initial);
  final List<AdminReport> initial;
  int loads = 0;
  String? lastStatus;

  @override
  ReportsState build() => ReportsLoaded(initial);

  @override
  Future<void> load({String? status = 'OPEN'}) async {
    loads++;
    lastStatus = status;
    state = ReportsLoaded(initial, status: status);
  }
}

void main() {
  testWidgets('내리기 성공 후 목록을 재조회한다', (tester) async {
    final fake = _CountingFake([_r()]);
    final c = ProviderContainer(
      overrides: [
        reportsProvider.overrideWith(() => fake),
        contentTakedownProvider.overrideWithValue((type, id) async {}),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const ReportsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('takedown-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-danger-confirmation-input')),
      '글 #10',
    );
    await tester.pump();
    await tester.tap(find.text('내리기 확정'));
    await tester.pumpAndSettle();

    expect(fake.loads, 1, reason: '성공 후 재조회가 없으면 같은 대상 재확정이 404 를 만든다');
  });
}
