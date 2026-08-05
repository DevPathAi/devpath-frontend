import 'dart:ui' as ui;

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

  // Important 1: 다크 레일 위에서 brand·account에 무스타일 위젯을 넣으면
  // railBg와 같은 색(#1A1815 = textPrimary)으로 렌더돼 완전히 묻힌다.
  // 레일이 자기 배경에 맞는 전경색을 기본값으로 공급해야 한다.
  testWidgets('brand·account 슬롯은 각각 railText·railMuted를 기본 전경색으로 제공', (
    tester,
  ) async {
    Color? brandTextColor;
    Color? accountIconColor;
    await tester.pumpWidget(
      _host(
        DpNavRail(
          destinations: _dests,
          selectedIndex: 0,
          onSelect: (_) {},
          brand: Builder(
            builder: (context) {
              brandTextColor = DefaultTextStyle.of(context).style.color;
              return const Text('DevPath');
            },
          ),
          account: Builder(
            builder: (context) {
              accountIconColor = IconTheme.of(context).color;
              return const Icon(Icons.person);
            },
          ),
        ),
      ),
    );
    expect(brandTextColor, DpColors.light.railText);
    expect(accountIconColor, DpColors.light.railMuted);
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

  testWidgets('레일 배경·우측 경계선 색이 토큰과 배선된다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpNavRail(destinations: _dests, selectedIndex: 0, onSelect: (_) {}),
      ),
    );
    final root = tester.widget<Container>(
      find.byKey(const ValueKey('rail-root')),
    );
    final deco = root.decoration! as BoxDecoration;
    expect(deco.color, DpColors.light.railBg);
    expect((deco.border! as Border).right.color, DpColors.light.railBorder);
  });

  testWidgets('섹션 레이블과 목적지 라벨 색이 토큰과 배선된다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpNavRail(destinations: _dests, selectedIndex: 1, onSelect: (_) {}),
      ),
    );

    final sectionLabel = tester.widget<Text>(find.text('학습'));
    expect(sectionLabel.style?.color, DpColors.light.railFaint);

    final inactiveLabel = tester.widget<Text>(find.text('대시보드'));
    expect(inactiveLabel.style?.color, DpColors.light.railMuted);

    final activeLabel = tester.widget<Text>(find.text('학습 경로'));
    expect(activeLabel.style?.color, DpColors.light.railText);
  });

  testWidgets('접힘 상태 항목에 접근 가능한 툴팁이 있다', (tester) async {
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
    expect(find.byType(Tooltip), findsNWidgets(_dests.length));
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).first);
    expect(tooltip.message, _dests.first.label);
  });

  testWidgets('활성 항목은 44px 이상 탭 타깃과 selected 시맨틱스를 갖는다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        DpNavRail(destinations: _dests, selectedIndex: 1, onSelect: (_) {}),
      ),
    );

    final size = tester.getSize(find.byKey(const ValueKey('rail-item-1')));
    expect(size.height, greaterThanOrEqualTo(44));

    final activeSemantics = tester.getSemantics(
      find.byKey(const ValueKey('rail-item-semantics-1')),
    );
    expect(activeSemantics.flagsCollection.isSelected, ui.Tristate.isTrue);

    final inactiveSemantics = tester.getSemantics(
      find.byKey(const ValueKey('rail-item-semantics-0')),
    );
    expect(
      inactiveSemantics.flagsCollection.isSelected,
      isNot(ui.Tristate.isTrue),
    );

    handle.dispose();
  });
}
