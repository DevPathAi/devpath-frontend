import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(int? selectedIndex) => MaterialApp(
    theme: DpTheme.light(),
    home: DpAppShell(
      destinations: const [
        DpDestination(icon: Icons.home, label: '대시보드'),
        DpDestination(icon: Icons.map, label: '학습 경로'),
      ],
      selectedIndex: selectedIndex,
      onSelect: (_) {},
      body: const SizedBox(),
    ),
  );

  testWidgets('compact에서 selectedIndex가 null이면 어떤 항목도 강조되지 않는다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(null));

    final bar = tester.widget<DpMobileNavigation>(
      find.byType(DpMobileNavigation),
    );
    expect(bar.selectedIndex, isNull);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('compact에서 selectedIndex를 제품 전용 하단바가 그대로 표현한다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(1));

    final bar = tester.widget<DpMobileNavigation>(
      find.byType(DpMobileNavigation),
    );
    expect(bar.selectedIndex, 1);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
