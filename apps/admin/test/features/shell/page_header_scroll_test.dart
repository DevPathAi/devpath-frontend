import 'package:devpath_admin/src/features/dashboard/application/dashboard_controller.dart';
import 'package:devpath_admin/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:devpath_admin/src/features/dashboard/state/dashboard_state.dart';
import 'package:devpath_admin/src/features/reports/application/reports_controller.dart';
import 'package:devpath_admin/src/features/reports/data/report.dart';
import 'package:devpath_admin/src/features/reports/presentation/reports_page.dart';
import 'package:devpath_admin/src/features/reports/state/reports_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 문서형 화면은 헤더가 본문과 함께 스크롤된다(DESIGN.md §9).
/// admin의 `users`·`ads`·`support`는 `DpDataTable`(data_table_2)이 자체 뷰포트를
/// 갖는 뷰포트 고정형이라 전환 대상이 아니다 — 여기서 다루지 않는다.
///
/// 헤더가 뷰포트 밖으로 충분히 나가면 sliver가 위젯을 트리에서 걷어내
/// findsNothing이 된다 — 이 경우도 "스크롤과 함께 사라짐"의 유효한 증거다.
void _expectHeaderScrolledAway(WidgetTester tester) {
  final headerFinder = find.byType(DpPageHeader);
  if (headerFinder.evaluate().isEmpty) return;
  expect(tester.getBottomLeft(headerFinder).dy, lessThanOrEqualTo(0));
}

/// 드래그 **전에** 헤더가 실제로 보이는지 고정한다.
/// 이 사전 조건이 없으면 「헤더가 아예 렌더되지 않는」 회귀를
/// [_expectHeaderScrolledAway]가 findsNothing 경로로 조용히 통과시킨다.
void _expectHeaderVisible(WidgetTester tester) {
  expect(find.byType(DpPageHeader), findsOneWidget);
  expect(tester.getBottomLeft(find.byType(DpPageHeader)).dy, greaterThan(0));
}

void main() {
  testWidgets('운영 대시보드에서 헤더가 스크롤과 함께 사라진다', (tester) async {
    tester.view.physicalSize = const Size(800, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // ET12는 서버의 임의 키를 카드로 만들지 않고 네 개의 canonical KPI만
    // 렌더한다. 800px는 medium(2열)이므로 네 카드가 2행이 된다. 300px 높이는
    // maxScrollExtent가 헤더 높이보다 커지게 해 완전 이탈 조건도 성립시킨다.
    final c = ProviderContainer(
      overrides: [
        adminDashProvider.overrideWith(
          () => _FixedDashController(const {
            'dau': 100,
            'newUsers': 20,
            'openReports': 3,
            'aiCalls': 400,
          }),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AdminDashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('운영 대시보드'), findsWidgets);
    _expectHeaderVisible(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();

    _expectHeaderScrolledAway(tester);
  });

  testWidgets('신고 처리 화면에서 헤더가 스크롤과 함께 사라진다', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // reports_page_test.dart의 _Fake 컨트롤러 관용구를 승계한다.
    final c = ProviderContainer(
      overrides: [
        reportsProvider.overrideWith(
          () => _FixedReportsController([for (var i = 1; i <= 8; i++) _r(i)]),
        ),
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

    expect(find.text('신고 처리'), findsWidgets);
    _expectHeaderVisible(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();

    _expectHeaderScrolledAway(tester);
  });
}

AdminReport _r(int id) => AdminReport(
  id: id,
  targetType: 'POST',
  targetId: id,
  targetTitle: '스팸 글 $id',
  targetExcerpt: '본문 일부…',
  targetPath: '/community/post/$id',
  category: 'AD',
  reason: '광고글입니다',
  reportCount: 1,
  status: 'OPEN',
  createdAt: '2026-08-02T09:00:00Z',
);

class _FixedDashController extends AdminDashController {
  _FixedDashController(this._stats);
  final Map<String, int> _stats;

  @override
  AdminDashState build() => AdminDashLoaded(_stats);

  @override
  Future<void> load() async {}
}

class _FixedReportsController extends ReportsController {
  _FixedReportsController(this._reports);
  final List<AdminReport> _reports;

  @override
  ReportsState build() => ReportsLoaded(_reports);

  @override
  Future<void> load({String? status = 'OPEN'}) async {}
}
