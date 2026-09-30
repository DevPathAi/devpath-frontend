import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 셸의 헤더·브레드크럼은 **본문이 중첩 Navigator 일 때도** 시맨틱스 트리에 남아야 한다.
///
/// `apps/web` 은 `ShellRoute(builder: (_, _, child) => AppShell(child: child))` 로
/// 셸을 두르고, go_router 가 넘겨 주는 `child` 는 자체 Overlay 를 가진 **중첩
/// Navigator** 다. `ModalRoute` 는 언제나 `ModalBarrier` 를 함께 올리고
/// (`modal_barrier.dart`: `BlockSemantics(...)`), 그 차단은 **먼저 그려진 형제**의
/// 시맨틱스를 통째로 없앤다. `Column[header, Expanded(body), footer]` 에서 헤더와
/// (안쪽 Column 의) 브레드크럼은 본문보다 먼저 그려지므로 둘만 사라지고 푸터는 남는다
/// — 폰에서 스크린리더로 내비게이션에 **전혀** 도달할 수 없다는 뜻이다.
///
/// 차단은 시맨틱 경계에서 멈춘다(`rendering/object.dart`:
/// `if (configProvider.effective.isSemanticBoundary) return false;`), 그래서 셸은
/// 본문을 `Semantics(container: true)` 로 감싼다. 루트 Navigator 로 뜨는 진짜
/// 모달(`showDialog` 기본값)은 셸 **전체**보다 뒤에 그려지므로 여전히 정상으로 가린다.
void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _host() => MaterialApp(
  theme: DpTheme.light(),
  home: DpWebShell(
    brand: DpRailBrand(mark: const DpBrandMark(size: 24), wordmark: 'Leva'),
    items: const [DpWebNavItem(id: '/dashboard', label: '오늘')],
    selectedId: '/dashboard',
    onSelect: (_) {},
    accountEntries: [(label: '로그아웃', onSelect: () {})],
    footerNotice: '© 레바',
    footerLinks: [(label: '이용약관', onTap: () {})],
    breadcrumb: const [(label: '커뮤니티', path: '/community')],
    // ShellRoute 가 넘겨 주는 것과 같은 중첩 Navigator.
    body: Navigator(
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const Text('본문')),
    ),
  ),
);

void main() {
  testWidgets('compact: 중첩 Navigator 본문이어도 햄버거가 시맨틱스에 남는다', (tester) async {
    _setWidth(tester, 390);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('메뉴'), findsOneWidget);
    expect(find.bySemanticsLabel('본문'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('wide: 중첩 Navigator 본문이어도 주 메뉴와 브랜드가 시맨틱스에 남는다', (tester) async {
    _setWidth(tester, 1240);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('오늘'), findsWidgets);
    expect(find.bySemanticsLabel('Leva'), findsWidgets);
    handle.dispose();
  });

  testWidgets('브레드크럼도 본문보다 먼저 그려지지만 시맨틱스에 남는다', (tester) async {
    _setWidth(tester, 1240);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    // 브레드크럼 행은 '현재 위치' 라벨을 가진 한 노드로 합쳐진다.
    expect(find.bySemanticsLabel(RegExp('커뮤니티')), findsWidgets);
    handle.dispose();
  });
}
