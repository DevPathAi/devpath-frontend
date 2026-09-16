import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _desktop = <DpDestination>[
  DpDestination(icon: Icons.home, label: '홈'),
  DpDestination(icon: Icons.forum, label: '자유게시판'),
  DpDestination(icon: Icons.question_answer, label: 'Q/A'),
  DpDestination(icon: Icons.feedback, label: '피드백'),
];

const _compact = <DpDestination>[
  DpDestination(icon: Icons.home, label: '홈'),
  DpDestination(icon: Icons.groups, label: '커뮤니티'),
];

Widget _host({int? compactSelectedIndex = 1}) => MaterialApp(
  theme: DpTheme.light(),
  home: DpAppShell(
    destinations: _desktop,
    selectedIndex: 2,
    onSelect: (_) {},
    compactDestinations: _compact,
    compactSelectedIndex: compactSelectedIndex,
    onCompactSelect: (_) {},
    body: const Text('본문'),
  ),
);

void main() {
  testWidgets('compact 전용 목적지는 하단 내비에만 적용된다', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());

    final nav = tester.widget<DpMobileNavigation>(
      find.byType(DpMobileNavigation),
    );
    expect(nav.destinations, _compact);
    expect(nav.selectedIndex, 1);
  });

  testWidgets('비-compact에서는 기본 목적지와 선택 상태를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());

    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.destinations, _desktop);
    expect(rail.selectedIndex, 2);
  });

  testWidgets('compact 선택이 없으면 desktop index로 잘못 폴백하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(compactSelectedIndex: null));

    final nav = tester.widget<DpMobileNavigation>(
      find.byType(DpMobileNavigation),
    );
    expect(nav.destinations, _compact);
    expect(nav.selectedIndex, isNull);
  });
}
