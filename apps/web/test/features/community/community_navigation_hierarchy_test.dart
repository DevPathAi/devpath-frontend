import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void main() {
  test('커뮤니티는 헤더 드롭다운이고 세 게시판이 그 자식이다', () {
    final community = kWebNavItems.firstWhere(
      (item) => item.id == '/community',
    );

    expect(community.children.map((child) => child.label), [
      '자유게시판',
      'Q/A',
      '피드백',
    ]);
    expect(community.children.map((child) => child.id), [
      '/community?board=FREE',
      '/community?board=QNA',
      '/community?board=FEEDBACK',
    ]);
  });

  test('URL의 board 값이 게시판 선택 상태를 결정한다', () {
    expect(webNavSelectedIdFor('/community'), '/community?board=FREE');
    expect(
      webNavSelectedIdFor('/community?board=FREE'),
      '/community?board=FREE',
    );
    expect(webNavSelectedIdFor('/community?board=QNA'), '/community?board=QNA');
    expect(
      webNavSelectedIdFor('/community?board=FEEDBACK'),
      '/community?board=FEEDBACK',
    );
  });

  // 커뮤니티 밖(/dashboard)에서 연다 — 커뮤니티 안에서 열면 브레드크럼이 같은
  // 라벨('커뮤니티'·현재 게시판)을 함께 내어 finder 가 두 개를 잡는다(실측).
  // 드롭다운이 세 게시판을 노출하는지는 위치와 무관한 성질이다.
  testWidgets('데스크톱: 커뮤니티 드롭다운을 열면 세 게시판이 모두 보인다', (tester) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(DpWebHeader),
        matching: find.text('커뮤니티'),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['자유게시판', 'Q/A', '피드백']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('데스크톱: 자식 게시판이 현재면 커뮤니티 항목에 밑줄이 간다', (tester) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      _host(
        const AppShellView(location: '/community?board=QNA', child: Text('본문')),
      ),
    );

    final header = tester.widget<DpWebHeader>(find.byType(DpWebHeader));
    expect(header.selectedId, '/community?board=QNA');
    expect(
      find.byKey(const ValueKey('web-header-current-/community')),
      findsOneWidget,
    );
  });

  testWidgets('390 폭: 하단 내비가 아니라 헤더의 접힌 메뉴가 세 게시판을 펼쳐 둔다', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(
      _host(
        const AppShellView(
          location: '/community?board=FEEDBACK',
          child: Text('본문'),
        ),
      ),
    );

    expect(find.byType(DpMobileNavigation), findsNothing);

    await tester.tap(find.byKey(const ValueKey('web-header-burger')));
    await tester.pumpAndSettle();

    final menu = find.byKey(const ValueKey('web-header-collapsed-menu'));
    for (final label in ['자유게시판', 'Q/A', '피드백']) {
      expect(
        find.descendant(of: menu, matching: find.text(label)),
        findsOneWidget,
        reason: '$label 이 접힘 메뉴에 없으면 폰에서 그 게시판에 도달할 방법이 사라진다',
      );
    }
  });
}
