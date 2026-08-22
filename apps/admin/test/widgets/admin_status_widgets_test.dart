import 'package:devpath_admin/src/design/admin_status_catalog.dart';
import 'package:devpath_admin/src/widgets/admin_status_widgets.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('status text shows both the localized label and raw wire code', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: AdminStatusText(
            domain: AdminStatusDomain.support,
            wire: 'ESCALATED',
          ),
        ),
      ),
    );

    expect(find.text('알 수 없는 상태'), findsOneWidget);
    expect(find.text('(ESCALATED)'), findsOneWidget);
  });

  testWidgets('responsive filter returns the exact selected wire at 320/200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: AdminStatusFilter(
            domain: AdminStatusDomain.ad,
            selectedWire: null,
            onSelected: (wire) => selected = wire,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일시 중지 (PAUSED)').last);
    await tester.pumpAndSettle();

    expect(selected, 'PAUSED');
    expect(tester.takeException(), isNull);
  });
}
