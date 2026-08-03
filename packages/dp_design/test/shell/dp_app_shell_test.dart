import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dests = <DpDestination>[
  DpDestination(icon: Icons.dashboard, label: '대시보드'),
  DpDestination(icon: Icons.map, label: '경로', badgeCount: 3),
];

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

DpAppShell _shell({bool? railExtended, VoidCallback? onToggleRail}) =>
    DpAppShell(
      destinations: _dests,
      selectedIndex: 0,
      onSelect: (_) {},
      railExtended: railExtended,
      onToggleRail: onToggleRail,
      body: const Text('본문'),
    );

void main() {
  testWidgets('compact(<600)은 NavigationBar', (tester) async {
    _setWidth(tester, 500);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('medium(600–839)은 접힌 NavigationRail(extended=false)', (
    tester,
  ) async {
    _setWidth(tester, 700);
    await tester.pumpWidget(_host(_shell()));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('expanded(≥840)은 펼친 NavigationRail(extended=true)', (
    tester,
  ) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell()));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('large(≥1240)은 본문을 DpMaxWidth로 제약', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(DpMaxWidth), findsOneWidget);
  });

  testWidgets('badgeCount>0 목적지는 Badge 표시', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(Badge), findsOneWidget); // '경로'만 badgeCount=3
  });

  testWidgets('목적지 선택 콜백은 index 전달', (tester) async {
    _setWidth(tester, 500);
    int? picked;
    await tester.pumpWidget(
      _host(
        DpAppShell(
          destinations: _dests,
          selectedIndex: 0,
          onSelect: (i) => picked = i,
          body: const Text('본문'),
        ),
      ),
    );
    await tester.tap(find.text('경로'));
    expect(picked, 1);
  });

  testWidgets('onToggleRail 지정 시 토글 버튼 노출·호출', (tester) async {
    _setWidth(tester, 1000);
    var toggled = false;
    await tester.pumpWidget(_host(_shell(onToggleRail: () => toggled = true)));
    final btn = find.byTooltip('메뉴 접기');
    expect(btn, findsOneWidget);
    await tester.tap(btn);
    expect(toggled, isTrue);
  });

  testWidgets('railExtended=false가 window class 기본을 오버라이드', (tester) async {
    _setWidth(tester, 1000); // 기본은 펼침
    await tester.pumpWidget(_host(_shell(railExtended: false)));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });
}
