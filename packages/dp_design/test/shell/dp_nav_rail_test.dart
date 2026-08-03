import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dests = <DpDestination>[
  DpDestination(icon: Icons.dashboard, label: '대시보드', section: '학습'),
  DpDestination(icon: Icons.map, label: '학습 경로', section: '학습'),
  DpDestination(
    icon: Icons.groups,
    label: '게시판',
    section: '커뮤니티',
    badgeCount: 2,
  ),
];

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: Row(children: [child])),
);

void main() {
  testWidgets('펼침 상태에서 섹션 레이블을 그룹마다 한 번씩 렌더', (tester) async {
    await tester.pumpWidget(
      _host(
        DpNavRail(destinations: _dests, selectedIndex: 0, onSelect: (_) {}),
      ),
    );
    expect(find.text('학습'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);
  });

  testWidgets('접힘 상태는 섹션 레이블 대신 구분선', (tester) async {
    await tester.pumpWidget(
      _host(
        DpNavRail(
          destinations: _dests,
          selectedIndex: 0,
          onSelect: (_) {},
          extended: false,
        ),
      ),
    );
    expect(find.text('학습'), findsNothing);
    expect(find.byKey(const ValueKey('rail-section-divider')), findsWidgets);
  });

  testWidgets('활성 항목만 railActive 배경을 갖는다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpNavRail(destinations: _dests, selectedIndex: 1, onSelect: (_) {}),
      ),
    );
    final active = tester.widget<Container>(
      find.byKey(const ValueKey('rail-item-1')),
    );
    final deco = active.decoration! as BoxDecoration;
    expect(deco.color, DpColors.light.railActive);
  });

  testWidgets('목적지 탭은 index를 통지', (tester) async {
    int? picked;
    await tester.pumpWidget(
      _host(
        DpNavRail(
          destinations: _dests,
          selectedIndex: 0,
          onSelect: (i) => picked = i,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('rail-item-2')));
    expect(picked, 2);
  });

  testWidgets('badgeCount>0 목적지는 Badge 표시', (tester) async {
    await tester.pumpWidget(
      _host(
        DpNavRail(destinations: _dests, selectedIndex: 0, onSelect: (_) {}),
      ),
    );
    expect(find.byType(Badge), findsOneWidget);
  });

  testWidgets('brand·account 슬롯을 렌더', (tester) async {
    await tester.pumpWidget(
      _host(
        DpNavRail(
          destinations: _dests,
          selectedIndex: 0,
          onSelect: (_) {},
          brand: const Text('DevPath'),
          account: const Text('김개발'),
        ),
      ),
    );
    expect(find.text('DevPath'), findsOneWidget);
    expect(find.text('김개발'), findsOneWidget);
  });

  testWidgets('onToggle 지정 시 토글 버튼 노출·호출', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      _host(
        DpNavRail(
          destinations: _dests,
          selectedIndex: 0,
          onSelect: (_) {},
          onToggle: () => toggled = true,
        ),
      ),
    );
    await tester.tap(find.byTooltip('메뉴 접기'));
    expect(toggled, isTrue);
  });
}
