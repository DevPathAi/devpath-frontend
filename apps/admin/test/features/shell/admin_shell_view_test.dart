import 'package:devpath_admin/src/features/shell/presentation/admin_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Large 폭은 펼친 NavigationRail(extended)', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/dashboard', child: Text('본문'))),
    );
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('운영 콘솔'), findsOneWidget);
  });

  testWidgets('compact 폭은 NavigationBar', (tester) async {
    _setWidth(tester, 500);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('목적지 선택 시 경로 콜백', (tester) async {
    _setWidth(tester, 500);
    String? picked;
    await tester.pumpWidget(
      _host(
        AdminShellView(
          location: '/dashboard',
          onSelect: (p) => picked = p,
          child: const Text('본문'),
        ),
      ),
    );
    await tester.tap(find.text('광고'));
    expect(picked, '/ads');
  });
}
