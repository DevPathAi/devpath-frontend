import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('다크에서 레일 배경이 본문 배경과 구별된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: Scaffold(
          body: DpNavRail(
            destinations: const [
              DpDestination(icon: Icons.home, label: '대시보드'),
            ],
            selectedIndex: 0,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('rail-root')),
    );
    final decoration = container.decoration! as BoxDecoration;

    // 레일이 본문 배경과 같은 계열이면 「잉크 레일」의 분리감이 사라진다.
    expect(decoration.color, isNot(DpColors.dark.bg));
    expect(decoration.color, DpColors.dark.railBg);
    // v2 셸은 본문보다 더 짙은 네이비로 레일을 분리한다.
    expect(
      DpColors.dark.railBg.computeLuminance(),
      lessThan(DpColors.dark.bg.computeLuminance()),
    );
  });

  testWidgets('다크에서 선택 항목 배경이 레일 배경과 구별된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: Scaffold(
          body: DpNavRail(
            destinations: const [
              DpDestination(icon: Icons.home, label: '대시보드'),
              DpDestination(icon: Icons.map, label: '학습 경로'),
            ],
            selectedIndex: 0,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    final selected = tester.widget<Container>(
      find.byKey(const ValueKey('rail-item-0')),
    );
    final decoration = selected.decoration! as BoxDecoration;
    expect(decoration.color, DpColors.dark.railActive);
    expect(decoration.color, isNot(DpColors.dark.railBg));

    // 값이 다르기만 해서는 부족하다 — 육안으로 구별돼야 한다.
    final lumActive = DpColors.dark.railActive.computeLuminance();
    final lumBg = DpColors.dark.railBg.computeLuminance();
    final contrast = (lumActive > lumBg
        ? (lumActive + 0.05) / (lumBg + 0.05)
        : (lumBg + 0.05) / (lumActive + 0.05));
    expect(contrast, greaterThan(1.2));
  });
}
