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

  // S3-P2 로 `apps/web` 이 이 셸을 떠난 뒤 남은 소비처는 `apps/admin` 뿐이고,
  // admin 은 compact 전용 목적지를 넘기지 않는다 — `destinations` 가 그대로
  // 하단 내비가 되는 이 경로가 admin 의 compact 동작 전부다.
  testWidgets('compact에서 destinations 가 그대로 하단 내비로 전달된다(admin 경로)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(1));

    final bar = tester.widget<DpMobileNavigation>(
      find.byType(DpMobileNavigation),
    );
    expect(bar.destinations.map((d) => d.label), ['대시보드', '학습 경로']);
  });
}
