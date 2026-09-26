import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _host({List<DpCrumb> breadcrumb = const []}) => MaterialApp(
  theme: DpTheme.light(),
  home: DpWebShell(
    brand: DpRailBrand(mark: const DpBrandMark(size: 24), wordmark: 'Leva'),
    items: const [DpWebNavItem(id: '/dashboard', label: '오늘')],
    selectedId: '/dashboard',
    onSelect: (_) {},
    accountEntries: [(label: '로그아웃', onSelect: () {})],
    footerNotice: '© 레바',
    footerLinks: [(label: '이용약관', onTap: () {})],
    breadcrumb: breadcrumb,
    body: const Text('본문'),
  ),
);

void main() {
  testWidgets('헤더 · 본문 · 푸터를 세로로 쌓는다 — 레일과 하단 내비는 없다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host());

    expect(find.byType(DpWebHeader), findsOneWidget);
    expect(find.text('본문'), findsOneWidget);
    expect(find.byType(DpWebFooter), findsOneWidget);
    expect(find.byType(DpNavRail), findsNothing);
    expect(find.byType(DpMobileNavigation), findsNothing);
    expect(find.byType(DpChromeBar), findsNothing);
  });

  testWidgets('푸터는 헤더보다 아래, 본문보다 아래다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host());

    final header = tester.getRect(find.byType(DpWebHeader));
    final footer = tester.getRect(find.byType(DpWebFooter));
    expect(footer.top, greaterThan(header.bottom));
  });

  testWidgets('compact 에서도 푸터는 보인다(사용자 결정: 셸 하단 고정)', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(_host());
    expect(find.byType(DpWebFooter), findsOneWidget);
  });

  testWidgets('본문은 contentMaxWidth 로 중앙 정렬된다 — large 뿐 아니라 모든 폭에서', (
    tester,
  ) async {
    for (final width in [900.0, 1600.0]) {
      _setWidth(tester, width);
      await tester.pumpWidget(_host());
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('web-shell-main')),
          matching: find.byType(DpMaxWidth),
        ),
        findsOneWidget,
        reason:
            '폭 $width 에서 본문 최대폭 제약이 없다 — 시안의 .main{max-width:1120px} 은 무조건이다',
      );
    }
  });

  testWidgets('브레드크럼은 본문 위, 헤더 아래에 놓인다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(
      _host(
        breadcrumb: const [
          (label: '커뮤니티', path: '/community'),
          (label: 'Q/A', path: null),
        ],
      ),
    );

    final crumb = tester.getRect(find.byType(DpBreadcrumb));
    final header = tester.getRect(find.byType(DpWebHeader));
    final body = tester.getRect(find.text('본문'));
    expect(crumb.top, greaterThanOrEqualTo(header.bottom));
    expect(crumb.bottom, lessThanOrEqualTo(body.top));
  });

  testWidgets('브레드크럼이 비면 자리를 차지하지 않는다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host());
    expect(find.byType(DpBreadcrumb), findsOneWidget);
    expect(tester.getSize(find.byType(DpBreadcrumb)).height, 0);
  });
}
