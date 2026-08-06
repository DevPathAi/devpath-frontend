import 'package:devpath_admin/src/features/shell/presentation/admin_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Large 폭은 펼친 DpNavRail + 브랜드', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/dashboard', child: Text('본문'))),
    );
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.extended, isTrue);
    expect(find.text('운영 콘솔'), findsOneWidget);
  });

  testWidgets('admin 브레드크럼은 단일 세그먼트', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/users', child: Text('본문'))),
    );
    final chrome = tester.widget<DpChromeBar>(find.byType(DpChromeBar));
    expect(chrome.breadcrumb, const [(label: '사용자 관리', path: null)]);
    // 브레드크럼도 화면 헤더와 같은 단일 출처를 쓴다(어긋나면 red).
    expect(chrome.breadcrumb, [
      (label: adminHeaderTitleFor('/users'), path: null),
    ]);
  });

  testWidgets('compact 폭은 NavigationBar', (tester) async {
    _setWidth(tester, 500);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(DpNavRail), findsNothing);
  });

  testWidgets('검색 진입점 배선 — large 폭엔 크롬바 검색 필드가 렌더된다', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/dashboard', child: Text('본문'))),
    );
    final chrome = tester.widget<DpChromeBar>(find.byType(DpChromeBar));
    expect(chrome.onSearchTap, isNotNull);
    expect(find.byKey(const ValueKey('chrome-search')), findsOneWidget);
  });

  testWidgets('검색 진입점 배선 — compact 폭엔 크롬바 검색 아이콘이 렌더된다', (tester) async {
    _setWidth(tester, 500);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byKey(const ValueKey('chrome-search-icon')), findsOneWidget);
  });

  testWidgets('목적지 선택 시 경로 콜백', (tester) async {
    _setWidth(tester, 500);
    String? picked;
    await tester.pumpWidget(
      _host(
        AdminShellView(
          location: '/dashboard',
          onSelect: (p) => picked = p,
          child: const Text('본문'),
        ),
      ),
    );
    await tester.tap(find.text('광고'));
    expect(picked, '/ads');
  });

  // 3단계(DpRailBrand)부터는 앱이 Text를 직접 만들지 않는다 — brand:에
  // DpRailBrand(mark:, wordmark:)를 넘기면 워드마크 Text는 DpNavRail 내부에서
  // color: c.railText를 명시해 만들어진다(dp_nav_rail.dart). 즉 이 회귀는
  // 이제 dp_design 쪽에서 구조적으로 막혀 있다(dp_rail_brand_test.dart·
  // dp_nav_rail_test.dart). 여기서는 admin 셸이 실제로 DpRailBrand를 통해
  // 배선했는지(과거처럼 raw Text/Widget을 brand:에 직접 넘기는 회귀가
  // 없는지)를 앱 레벨에서 고정한다 — Text 위젯의 "실효 색"(DefaultTextStyle과의
  // 병합 결과, Flutter Text가 실제로 렌더할 색)을 단언한다.
  Color? effectiveTextColor(WidgetTester tester, Finder finder) {
    final widget = tester.widget<Text>(finder);
    final context = tester.element(finder);
    final ambient = DefaultTextStyle.of(context).style;
    final effective = widget.style == null
        ? ambient
        : ambient.merge(widget.style);
    return effective.color;
  }

  testWidgets('레일 브랜드 텍스트의 실효 색은 라이트에서 railText다(레일 배경에 묻히지 않음)', (
    tester,
  ) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/dashboard', child: Text('본문'))),
    );

    final finder = find.descendant(
      of: find.byType(DpNavRail),
      matching: find.text('운영 콘솔'),
    );
    expect(
      effectiveTextColor(tester, finder),
      DpColors.light.railText,
      reason:
          'titleSmall이 이미 textPrimary를 품고 있어 color를 명시하지 않으면 '
          'railText 대신 textPrimary로 렌더돼 라이트에서 railBg와 같은 색이 된다',
    );
  });

  testWidgets('레일 브랜드 텍스트의 실효 색은 다크에서도 railText다', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: const AdminShellView(location: '/dashboard', child: Text('본문')),
      ),
    );

    final finder = find.descendant(
      of: find.byType(DpNavRail),
      matching: find.text('운영 콘솔'),
    );
    expect(effectiveTextColor(tester, finder), DpColors.dark.railText);
  });
}
