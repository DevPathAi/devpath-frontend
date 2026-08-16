import 'package:devpath_admin/src/features/ads/data/ads_source.dart';
import 'package:devpath_admin/src/features/ads/presentation/ads_page.dart';
import 'package:devpath_admin/src/features/reports/application/reports_controller.dart';
import 'package:devpath_admin/src/features/reports/presentation/reports_page.dart';
import 'package:devpath_admin/src/features/reports/state/reports_state.dart';
import 'package:devpath_admin/src/features/support/application/support_controller.dart';
import 'package:devpath_admin/src/features/support/presentation/support_page.dart';
import 'package:devpath_admin/src/features/support/state/support_state.dart';
import 'package:devpath_admin/src/features/users/data/users_source.dart';
import 'package:devpath_admin/src/features/users/presentation/users_page.dart';
import 'package:devpath_admin/src/widgets/bulk_action_bar.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reports extends ReportsController {
  @override
  ReportsState build() => const ReportsLoaded([]);

  @override
  Future<void> load({String? status = 'OPEN'}) async {}
}

class _Support extends SupportListController {
  @override
  SupportListState build() => const SupportListLoaded([]);

  @override
  Future<void> load({String? status = 'OPEN', String? type}) async {}
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(320, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Widget _app(Widget home, Widget Function(Widget child) withScope) => withScope(
  MaterialApp(
    theme: DpTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
      child: child!,
    ),
    home: home,
  ),
);

void main() {
  testWidgets('users filters and pre-approval action reflow at 320/200%', (
    tester,
  ) async {
    await _pump(
      tester,
      _app(
        const AdminUsersPage(),
        (child) => ProviderScope(
          overrides: [
            adminUsersFetchProvider.overrideWithValue(
              ({cursor, status}) async => Page(data: const [], limit: 20),
            ),
          ],
          child: child,
        ),
      ),
    );
  });

  testWidgets('reports four-way status filter reflows at 320/200%', (
    tester,
  ) async {
    await _pump(
      tester,
      _app(
        const ReportsPage(),
        (child) => ProviderScope(
          overrides: [reportsProvider.overrideWith(_Reports.new)],
          child: child,
        ),
      ),
    );
  });

  testWidgets('support four-way status filter reflows at 320/200%', (
    tester,
  ) async {
    await _pump(
      tester,
      _app(
        const SupportPage(),
        (child) => ProviderScope(
          overrides: [supportListProvider.overrideWith(_Support.new)],
          child: child,
        ),
      ),
    );
  });

  testWidgets('ads filters and header actions reflow at 320/200%', (
    tester,
  ) async {
    await _pump(
      tester,
      _app(
        const AdminAdsPage(),
        (child) => ProviderScope(
          overrides: [
            adsListProvider.overrideWithValue(({slot, status}) async => []),
            adSettingsGetProvider.overrideWithValue(() async => false),
            adSlotConfigListProvider.overrideWithValue(() async => []),
          ],
          child: child,
        ),
      ),
    );
  });

  testWidgets('bulk actions stack without overflow at 320/200%', (
    tester,
  ) async {
    await _pump(
      tester,
      _app(
        BulkActionBar(
          count: 24,
          actionLabel: '선택 항목 삭제',
          onAction: () {},
          onClear: () {},
        ),
        (child) => child,
      ),
    );
  });
}
