import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void main() {
  testWidgets('Ctrl+K로 팔레트가 열리고 명령 필터·실행', (tester) async {
    String invoked = '';
    await tester.pumpWidget(
      _host(
        DpCommandPalette(
          commands: [
            (
              id: 'dash',
              label: '대시보드로 이동',
              icon: DpIcons.dashboard,
              onInvoke: () => invoked = 'dash',
            ),
            (
              id: 'mentor',
              label: '멘토로 이동',
              icon: DpIcons.mentor,
              onInvoke: () => invoked = 'mentor',
            ),
          ],
          child: const Scaffold(body: Text('앱 본문')),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    // 검색 뷰가 열려 두 명령 모두 노출
    expect(find.text('대시보드로 이동'), findsOneWidget);
    expect(find.text('멘토로 이동'), findsOneWidget);

    // 타이핑으로 필터
    await tester.enterText(find.byType(TextField).last, '멘토');
    await tester.pumpAndSettle();
    expect(find.text('대시보드로 이동'), findsNothing);

    // 선택 → onInvoke
    await tester.tap(find.text('멘토로 이동'));
    await tester.pumpAndSettle();
    expect(invoked, 'mentor');
  });

  testWidgets('OpenCommandPaletteIntent로도 오픈', (tester) async {
    await tester.pumpWidget(
      _host(
        DpCommandPalette(
          commands: [
            (id: 'a', label: '항목 A', icon: DpIcons.star, onInvoke: () {}),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: IconButton(
                  icon: const Icon(DpIcons.search),
                  onPressed: () =>
                      Actions.invoke(context, const OpenCommandPaletteIntent()),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(DpIcons.search));
    await tester.pumpAndSettle();
    expect(find.text('항목 A'), findsOneWidget);
  });
}
