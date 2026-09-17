import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('titleMenu 가 없으면 제목은 메뉴 버튼이 아닌 일반 헤더다', (tester) async {
    await tester.pumpWidget(_host(const DpPageHeader(title: '자유게시판')));

    expect(find.text('자유게시판'), findsOneWidget);
    expect(find.byKey(const ValueKey('page-header-title-menu')), findsNothing);
  });

  testWidgets('titleMenu 가 있으면 제목을 눌러 형제 페이지를 고른다', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(
      _host(
        DpPageHeader(
          title: '자유게시판',
          titleMenuTooltip: '게시판 바꾸기',
          titleMenu: [
            (
              label: '자유게시판',
              selected: true,
              onSelect: () => picked.add('FREE'),
            ),
            (label: 'Q/A', selected: false, onSelect: () => picked.add('QNA')),
          ],
        ),
      ),
    );

    // 닫힌 상태: 제목만 보이고 항목은 아직 없다.
    expect(find.text('Q/A'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('page-header-title-menu')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(MenuItemButton, 'Q/A'), findsOneWidget);
    // 현재 페이지만 선택 표시를 단다.
    expect(
      find.descendant(
        of: find.widgetWithText(MenuItemButton, '자유게시판'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(MenuItemButton, 'Q/A'),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(MenuItemButton, 'Q/A'));
    await tester.pumpAndSettle();
    expect(picked, ['QNA']);
  });

  testWidgets('제목은 순수 헤더로 남고 메뉴는 44px 이상의 별도 버튼이다', (tester) async {
    // 헤더와 버튼을 한 노드로 합치면 웹에서 `<h2>게시판 바꾸기\n피드백</h2>` 가 되어
    // 제목 텍스트가 오염되고 버튼 역할이 사라진다(브라우저 UX 게이트 실측).
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        DpPageHeader(
          title: '피드백',
          titleMenuTooltip: '게시판 바꾸기',
          titleMenu: [(label: '피드백', selected: true, onSelect: () {})],
        ),
      ),
    );

    // 헤더 노드는 자식이 없어야 한다 — 웹 엔진은 자식이 있는 헤더를 `<h2>` 로 내지 않아
    // 옆의 버튼이 헤더 노드 밑으로 들어가면 제목이 heading 목록에서 사라진다(실측).
    expect(
      tester.getSemantics(find.text('피드백')),
      matchesSemantics(isHeader: true, label: '피드백', children: const []),
    );
    final button = find.byKey(const ValueKey('page-header-title-menu'));
    // 위젯 크기가 아니라 보조기술·포인터가 보는 시맨틱 박스로 잰다(위젯은 패딩 포함 48, 박스는 40 이었다).
    expect(
      tester.getSemantics(button).rect.shortestSide,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSemantics(button),
      isSemantics(isButton: true, tooltip: '게시판 바꾸기'),
    );
    handle.dispose();
  });

  testWidgets('제목 글자를 눌러도 메뉴가 열린다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpPageHeader(
          title: '자유게시판',
          titleMenu: [(label: 'Q/A', selected: false, onSelect: () {})],
        ),
      ),
    );
    await tester.tap(find.text('자유게시판'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Q/A'), findsOneWidget);
  });

  testWidgets('메뉴가 열리면 focus 가 첫 항목으로 가고 Escape 로 닫으면 버튼으로 돌아온다', (
    tester,
  ) async {
    // 웹 시맨틱스에서는 메뉴 안에 focus 받은 노드가 없으면 DOM focus 가 body 로 빠져
    // Escape·화살표가 어디에도 닿지 않는다(브라우저 UX 게이트 실측).
    await tester.pumpWidget(
      _host(
        DpPageHeader(
          title: '자유게시판',
          titleMenu: [
            (label: '자유게시판', selected: true, onSelect: () {}),
            (label: 'Q/A', selected: false, onSelect: () {}),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('page-header-title-menu')));
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'page-header-title-menu-first-item',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Q/A'), findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'page-header-title-menu',
    );
  });
}
