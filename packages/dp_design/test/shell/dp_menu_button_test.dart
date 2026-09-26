import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required List<DpMenuEntry> entries}) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(
    body: DpMenuButton(
      entries: entries,
      builder: (context, buttonFocus, toggle, isOpen) => TextButton(
        key: const ValueKey('opener'),
        focusNode: buttonFocus,
        onPressed: toggle,
        child: Text(isOpen ? '열림' : '닫힘'),
      ),
    ),
  ),
);

void main() {
  testWidgets('열면 첫 항목으로 focus 가 간다 — 웹에서 Escape 가 닿으려면 필요하다', (tester) async {
    await tester.pumpWidget(
      _host(
        entries: [
          (label: '첫째', onSelect: () {}),
          (label: '둘째', onSelect: () {}),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('opener')));
    await tester.pumpAndSettle();

    expect(find.text('첫째'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'dp-menu-button-first-item',
      reason: '첫 항목에 focus 가 없으면 웹에서 DOM focus 가 body 로 빠져 Escape 가 안 먹는다',
    );
  });

  testWidgets('항목을 고르면 콜백이 불리고 메뉴가 닫힌다', (tester) async {
    var picked = 0;
    await tester.pumpWidget(
      _host(entries: [(label: '첫째', onSelect: () => picked++)]),
    );

    await tester.tap(find.byKey(const ValueKey('opener')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('첫째'));
    await tester.pumpAndSettle();

    expect(picked, 1);
    expect(
      find.text('첫째'),
      findsNothing,
      reason: '메뉴가 열린 채 남으면 다음 화면 위에 떠 있는다',
    );
  });

  testWidgets('열린 상태는 builder 에 전달된다', (tester) async {
    await tester.pumpWidget(_host(entries: [(label: '첫째', onSelect: () {})]));

    expect(find.text('닫힘'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('opener')));
    await tester.pumpAndSettle();
    expect(find.text('열림'), findsOneWidget);
  });

  testWidgets('한 번 더 누르면 닫힌다', (tester) async {
    await tester.pumpWidget(_host(entries: [(label: '첫째', onSelect: () {})]));

    await tester.tap(find.byKey(const ValueKey('opener')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('opener')));
    await tester.pumpAndSettle();

    expect(find.text('첫째'), findsNothing);
  });
}
