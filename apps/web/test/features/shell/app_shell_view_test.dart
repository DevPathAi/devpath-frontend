import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P4a-A: MediaQuery를 MaterialApp 바깥에 두면 MaterialApp의 MediaQuery.fromView가
// 가려 폭이 무시된다(기본 800×600). 반드시 tester.view.physicalSize로 설정한다.
Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('좁은 폭(<840)은 NavigationBar', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('넓은 폭(≥840)은 NavigationRail', (tester) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('목적지 선택 시 해당 경로로 콜백', (tester) async {
    _setWidth(tester, 390);
    String? picked;
    await tester.pumpWidget(
      _host(
        AppShellView(
          location: '/dashboard',
          onSelect: (p) => picked = p,
          child: const Text('본문'),
        ),
      ),
    );
    await tester.tap(find.text('멘토'));
    expect(picked, '/mentor');
  });
}
