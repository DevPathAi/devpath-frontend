import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required int actionCount, required List<DpCrumb> crumbs}) =>
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpChromeBar(
            breadcrumb: crumbs,
            onSearchTap: () {},
            actions: [
              for (var i = 0; i < actionCount; i++)
                DpChromeAction(
                  icon: Icons.star,
                  label: '액션 $i',
                  onPressed: (_) {},
                ),
            ],
            account: const Icon(Icons.person),
          ),
        ),
      );

  // 실제 앱 crumbs 길이를 쓴다. 값을 늘려 조건을 피해 가지 않는다.
  const crumbs = <DpCrumb>[
    (label: '커뮤니티', path: null),
    (label: '게시판', path: '/community'),
  ];

  for (final width in [500.0, 700.0, 1000.0, 1400.0]) {
    testWidgets('폭 $width에서 액션 8개를 줘도 오버플로하지 않는다', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(actionCount: 8, crumbs: crumbs));

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('액션이 폭을 넘기면 오버플로 메뉴로 접힌다', (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(actionCount: 8, crumbs: crumbs));

    expect(
      find.byKey(const ValueKey('chrome-actions-overflow')),
      findsOneWidget,
    );
  });

  testWidgets('계정은 오버플로 메뉴로 가지 않고 항상 바에 남는다', (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(actionCount: 8, crumbs: crumbs));

    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('액션이 적으면 오버플로 메뉴가 없다', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(actionCount: 1, crumbs: crumbs));

    expect(find.byKey(const ValueKey('chrome-actions-overflow')), findsNothing);
  });
}
