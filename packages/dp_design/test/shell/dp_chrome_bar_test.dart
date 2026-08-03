import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _crumbs = <DpCrumb>[
  (label: '커뮤니티', path: null),
  (label: '게시판', path: '/community'),
  (label: '게시글', path: null),
];

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('모든 세그먼트를 렌더한다', (tester) async {
    await tester.pumpWidget(_host(const DpChromeBar(breadcrumb: _crumbs)));
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('게시판'), findsOneWidget);
    expect(find.text('게시글'), findsOneWidget);
  });

  testWidgets('path 있는 세그먼트만 탭 시 경로 통지', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onCrumbTap: (p) => tapped = p)),
    );
    await tester.tap(find.text('게시판'));
    expect(tapped, '/community');

    tapped = null;
    await tester.tap(find.text('커뮤니티'));
    expect(tapped, isNull, reason: 'path가 null인 세그먼트는 비클릭이다');
  });

  testWidgets('검색 필드 탭은 onSearchTap을 호출', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onSearchTap: () => opened = true)),
    );
    await tester.tap(find.byKey(const ValueKey('chrome-search')));
    expect(opened, isTrue);
  });

  testWidgets('compact은 마지막 세그먼트만 + 검색 아이콘', (tester) async {
    await tester.pumpWidget(
      _host(const DpChromeBar(breadcrumb: _crumbs, compact: true)),
    );
    expect(find.text('게시글'), findsOneWidget);
    expect(find.text('커뮤니티'), findsNothing);
    expect(find.byKey(const ValueKey('chrome-search-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('chrome-search')), findsNothing);
  });

  testWidgets('actions·account 슬롯을 렌더', (tester) async {
    await tester.pumpWidget(
      _host(
        const DpChromeBar(
          breadcrumb: _crumbs,
          actions: [Text('액션')],
          account: Text('계정'),
        ),
      ),
    );
    expect(find.text('액션'), findsOneWidget);
    expect(find.text('계정'), findsOneWidget);
  });
}
