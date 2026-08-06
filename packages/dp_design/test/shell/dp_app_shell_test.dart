import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dests = <DpDestination>[
  DpDestination(icon: Icons.dashboard, label: '대시보드', section: '학습'),
  DpDestination(icon: Icons.map, label: '경로', section: '학습', badgeCount: 3),
];

const _crumbs = <DpCrumb>[
  (label: '학습', path: null),
  (label: '대시보드', path: null),
];

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

DpAppShell _shell({
  bool? railExtended,
  VoidCallback? onToggleRail,
  List<DpCrumb> breadcrumb = _crumbs,
  Widget? account,
}) => DpAppShell(
  destinations: _dests,
  selectedIndex: 0,
  onSelect: (_) {},
  railExtended: railExtended,
  onToggleRail: onToggleRail,
  breadcrumb: breadcrumb,
  account: account,
  body: const Text('본문'),
);

void main() {
  testWidgets('compact(<600)은 NavigationBar, 레일 없음', (tester) async {
    _setWidth(tester, 500);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(DpNavRail), findsNothing);
  });

  testWidgets('medium(600–839)은 접힌 DpNavRail', (tester) async {
    _setWidth(tester, 700);
    await tester.pumpWidget(_host(_shell()));
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('expanded(≥840)은 펼친 DpNavRail', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell()));
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('large(≥1240)은 본문을 DpMaxWidth로 제약', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(DpMaxWidth), findsOneWidget);
  });

  testWidgets('breadcrumb이 비면 크롬바를 렌더하지 않는다', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell(breadcrumb: const [])));
    expect(find.byType(DpChromeBar), findsNothing);
  });

  testWidgets('breadcrumb이 있으면 크롬바를 렌더한다', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(DpChromeBar), findsOneWidget);
  });

  testWidgets('account는 expanded에서 레일에, compact에서 크롬바에 배치', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell(account: const Text('계정'))));
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.account, isNotNull);
    var chrome = tester.widget<DpChromeBar>(find.byType(DpChromeBar));
    expect(chrome.account, isNull);

    _setWidth(tester, 500);
    await tester.pumpWidget(_host(_shell(account: const Text('계정'))));
    chrome = tester.widget<DpChromeBar>(find.byType(DpChromeBar));
    expect(chrome.account, isNotNull);
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

  testWidgets('onToggleRail 지정 시 레일에 전달', (tester) async {
    _setWidth(tester, 1000);
    var toggled = false;
    await tester.pumpWidget(_host(_shell(onToggleRail: () => toggled = true)));
    await tester.tap(find.byTooltip('메뉴 접기'));
    expect(toggled, isTrue);
  });

  testWidgets('railExtended=false가 window class 기본을 오버라이드', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell(railExtended: false)));
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('badgeCount>0 목적지는 Badge 표시', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(Badge), findsOneWidget);
  });

  // Important 2: 크롬바가 breadcrumb 유무만으로 렌더 여부를 정하면,
  // compact + 빈 breadcrumb 조합에서 account(크롬바로 배치됨)가 어디에도
  // 도달하지 못하고 조용히 사라진다.
  testWidgets('compact + 빈 breadcrumb + account 지정 시 account가 렌더된다', (
    tester,
  ) async {
    _setWidth(tester, 500);
    await tester.pumpWidget(
      _host(
        DpAppShell(
          destinations: _dests,
          selectedIndex: 0,
          onSelect: (_) {},
          breadcrumb: const [],
          account: const Text('계정'),
          body: const Text('본문'),
        ),
      ),
    );
    expect(find.byType(DpChromeBar), findsOneWidget);
    expect(find.text('계정'), findsOneWidget);
  });

  // 같은 결함이 chromeActions에도 적용된다(non-compact에서도 breadcrumb이
  // 비면 발생) — DpNavRail에는 chromeActions를 넘길 슬롯이 없기 때문이다.
  testWidgets('non-compact + 빈 breadcrumb + chromeActions 지정 시 actions가 렌더된다', (
    tester,
  ) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(
      _host(
        DpAppShell(
          destinations: _dests,
          selectedIndex: 0,
          onSelect: (_) {},
          breadcrumb: const [],
          chromeActions: [
            DpChromeAction(icon: Icons.star, label: '액션', onPressed: (_) {}),
          ],
          body: const Text('본문'),
        ),
      ),
    );
    expect(find.byType(DpChromeBar), findsOneWidget);
    expect(find.byTooltip('액션'), findsOneWidget);
  });
}
