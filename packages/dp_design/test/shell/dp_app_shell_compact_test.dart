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

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    // selectedIndex는 non-null int라 0으로 클램프될 수밖에 없다.
    // 강조는 인디케이터를 투명으로 만들어 지운다.
    final theme = NavigationBarTheme.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(theme.indicatorColor, Colors.transparent);
    expect(bar.selectedIndex, 0);
  });

  testWidgets('compact에서 selectedIndex가 있으면 인디케이터가 상위 테마 기본값을 따른다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(1));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
    // DpTheme.light()는 navigationBarTheme을 설정하지 않으므로 기본값은 null
    // (상위 ThemeData가 색을 정하지 않았다는 뜻 — 투명으로 강제 덮지 않았음을 뜻한다).
    final theme = NavigationBarTheme.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(theme.indicatorColor, isNull);
  });
}
