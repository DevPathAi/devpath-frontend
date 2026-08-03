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
      _host(
        DpChromeBar(breadcrumb: _crumbs, compact: true, onSearchTap: () {}),
      ),
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

  // Minor: onSearchTap 부재 시 compact 여부와 무관하게 검색 UI가 렌더되지 않아야
  // 일관적이다(비-compact은 이미 그렇다).
  testWidgets('onSearchTap이 없으면 compact에서도 검색 아이콘이 없다', (tester) async {
    await tester.pumpWidget(
      _host(const DpChromeBar(breadcrumb: _crumbs, compact: true)),
    );
    expect(find.byKey(const ValueKey('chrome-search-icon')), findsNothing);
    expect(find.byKey(const ValueKey('chrome-search')), findsNothing);
  });

  // Important 1: 세그먼트 Text가 Row(mainAxisSize.min) 아래에서 자기 폭 제약이
  // 없으면 ellipsis가 발동하지 않고 RenderFlex 오버플로가 난다.
  testWidgets('좁은 폭 + 긴 라벨에서도 오버플로 없이 렌더된다', (tester) async {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final longCrumbs = <DpCrumb>[
      (label: List.filled(45, '가').join(), path: null),
      (label: List.filled(45, '나').join(), path: '/x'),
    ];

    await tester.pumpWidget(_host(DpChromeBar(breadcrumb: longCrumbs)));

    expect(tester.takeException(), isNull);
  });

  // Important 2: DESIGN.md §6 — 터치 타깃 ≥44×44. 클릭 가능한 세그먼트와
  // 검색 필드 모두 히트 영역이 44px 이상이어야 한다.
  testWidgets('클릭 가능한 브레드크럼 세그먼트의 탭 영역이 44px 이상', (tester) async {
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onCrumbTap: (_) {})),
    );
    final finder = find.ancestor(
      of: find.text('게시판'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
  });

  testWidgets('검색 필드의 탭 영역이 44px 이상(시각적 상자는 28px 유지)', (tester) async {
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onSearchTap: () {})),
    );
    final size = tester.getSize(find.byKey(const ValueKey('chrome-search')));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  // Important 3: 색 토큰이 실제로 배선됐는지 — 지금까지의 5테스트는 텍스트·키
  // 존재와 탭 콜백만 확인해 textFaint/textSecondary를 바꿔치기해도 통과했다.
  testWidgets('바 배경·아래 경계가 surface/border 토큰을 쓴다', (tester) async {
    await tester.pumpWidget(_host(const DpChromeBar(breadcrumb: _crumbs)));
    final container = tester.widget<Container>(
      find.byKey(const ValueKey('chrome-bar-root')),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, DpColors.light.surface);
    expect(decoration.border!.bottom.color, DpColors.light.border);
  });

  testWidgets('세그먼트 라벨과 구분자가 서로 다른 색 토큰을 쓴다(뒤바뀌지 않음)', (tester) async {
    await tester.pumpWidget(_host(const DpChromeBar(breadcrumb: _crumbs)));
    final segment = tester.widget<Text>(find.text('게시판'));
    expect(segment.style?.color, DpColors.light.textSecondary);

    final separator = tester.widget<Text>(find.text('·').first);
    expect(separator.style?.color, DpColors.light.textFaint);
  });

  // Important 1: 밝은 surface 배경 위이므로 actions·account에 무스타일
  // 위젯을 넣어도 textSecondary가 기본 전경색으로 공급돼야 한다(대비 확보).
  testWidgets('actions·account 슬롯은 textSecondary를 기본 전경색으로 제공', (tester) async {
    Color? actionsIconColor;
    Color? accountTextColor;
    await tester.pumpWidget(
      _host(
        DpChromeBar(
          breadcrumb: _crumbs,
          actions: [
            Builder(
              builder: (context) {
                actionsIconColor = IconTheme.of(context).color;
                return const Icon(Icons.notifications);
              },
            ),
          ],
          account: Builder(
            builder: (context) {
              accountTextColor = DefaultTextStyle.of(context).style.color;
              return const Text('계정');
            },
          ),
        ),
      ),
    );
    expect(actionsIconColor, DpColors.light.textSecondary);
    expect(accountTextColor, DpColors.light.textSecondary);
  });

  testWidgets('검색 필드 배경은 surfaceMuted를 쓴다', (tester) async {
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onSearchTap: () {})),
    );
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('chrome-search')),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, DpColors.light.surfaceMuted);
  });
}
