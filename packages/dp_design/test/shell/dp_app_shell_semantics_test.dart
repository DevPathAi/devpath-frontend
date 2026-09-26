import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 레일·크롬바는 **본문이 중첩 Navigator 일 때도** 시맨틱스 트리에 남아야 한다.
///
/// `apps/admin` 은 `ShellRoute(builder: (_, _, child) => AdminShellView(child: child))`
/// 로 셸을 두르고, go_router 가 넘겨 주는 `child` 는 자체 Overlay 를 가진 **중첩
/// Navigator** 다. `ModalRoute` 는 언제나 `ModalBarrier` 를 함께 올리고
/// (`modal_barrier.dart`: `BlockSemantics(...)`), 그 차단은 **먼저 그려진 형제**의
/// 시맨틱스를 통째로 없앤다. `DpAppShell` 은 `Row[DpNavRail, Expanded(Column[
/// DpChromeBar, Expanded(content)])]` 이므로 레일도 크롬바도 본문보다 먼저
/// 그려진다 — 감싸지 않으면 **둘 다** 사라지고 본문만 남는다(`DpWebShell` 은
/// 푸터가 본문 뒤에 그려져 살아남지만, 여기는 살아남는 형제가 하나도 없다).
///
/// 차단은 시맨틱 경계에서 멈춘다(`rendering/object.dart`:
/// `if (configProvider.effective.isSemanticBoundary) return false;`), 그래서 셸은
/// 본문을 `Semantics(container: true)` 로 감싼다. 루트 Navigator 로 뜨는 진짜
/// 모달(`showDialog` 기본값)은 셸 **전체**보다 뒤에 그려지므로 여전히 정상으로 가린다.
///
/// 같은 결함을 `DpWebShell` 에서 고친 테스트가 `dp_web_shell_semantics_test.dart` 다.
const _dests = <DpDestination>[
  DpDestination(icon: Icons.dashboard, label: '대시보드'),
  DpDestination(icon: Icons.people, label: '회원'),
];

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _host() => MaterialApp(
  theme: DpTheme.light(),
  home: DpAppShell(
    destinations: _dests,
    selectedIndex: 0,
    onSelect: (_) {},
    brand: DpRailBrand(mark: const DpBrandMark(size: 22), wordmark: '운영 콘솔'),
    account: TextButton(onPressed: () {}, child: const Text('계정')),
    breadcrumb: const [(label: '회원 관리', path: null)],
    // ShellRoute 가 넘겨 주는 것과 같은 중첩 Navigator.
    body: Navigator(
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const Text('본문')),
    ),
  ),
);

void main() {
  testWidgets('large: 중첩 Navigator 본문이어도 레일의 브랜드·목적지가 시맨틱스에 남는다', (
    tester,
  ) async {
    _setWidth(tester, 1240);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('운영 콘솔'), findsWidgets);
    // 펼친 레일 항목의 노드 라벨은 '대시보드\n대시보드' 다 — `DpNavRail` 이
    // `Semantics(label:)` 과 보이는 `Text` 를 함께 두어 병합된다(이 결함과 무관한
    // 기존 거동이라 여기서는 정규식으로 받는다).
    expect(find.bySemanticsLabel(RegExp('대시보드')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('회원(?! 관리)')), findsWidgets);
    expect(find.bySemanticsLabel('본문'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('large: 레일 하단의 계정도 본문보다 먼저 그려지지만 시맨틱스에 남는다', (tester) async {
    _setWidth(tester, 1240);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('계정'), findsWidgets);
    handle.dispose();
  });

  testWidgets('large: 크롬바의 브레드크럼이 시맨틱스에 남는다', (tester) async {
    _setWidth(tester, 1240);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('회원 관리')), findsWidgets);
    handle.dispose();
  });

  testWidgets('compact: 크롬바의 브랜드·계정이 시맨틱스에 남는다', (tester) async {
    _setWidth(tester, 390);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('운영 콘솔'), findsWidgets);
    expect(find.bySemanticsLabel('계정'), findsWidgets);
    handle.dispose();
  });
}
