import 'package:dp_design/src/interaction/dp_interactive_card.dart';
import 'package:dp_design/src/theme/dp_colors.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('탭하면 onTap을 호출한다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        DpInteractiveCard(onTap: () => tapped = true, child: const Text('카드')),
      ),
    );
    await tester.tap(find.text('카드'));
    expect(tapped, isTrue);
  });

  testWidgets('키보드 접근성을 위해 FocusableActionDetector와 InkWell을 포함', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(DpInteractiveCard(onTap: () {}, child: const Text('카드'))),
    );
    expect(find.byType(FocusableActionDetector), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('onTap이 null이면 InkWell은 비활성(탭 무동작)', (tester) async {
    await tester.pumpWidget(_host(const DpInteractiveCard(child: Text('정적'))));
    final inkwell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkwell.onTap, isNull);
  });

  testWidgets('focus ring은 2px primaryText 고대비 토큰을 쓴다', (tester) async {
    await tester.pumpWidget(
      _host(DpInteractiveCard(onTap: () {}, child: const Text('카드'))),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).last);
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.border!.top.width, 2);
    expect(decoration.border!.top.color, DpColors.light.primaryText);
  });

  testWidgets('카드는 Tab 정지가 하나뿐이고 Enter 로 onTap 을 호출한다', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              DpInteractiveCard(
                key: const Key('card-1'),
                onTap: () => taps.add('1'),
                child: const Text('첫 카드'),
              ),
              DpInteractiveCard(
                key: const Key('card-2'),
                onTap: () => taps.add('2'),
                child: const Text('둘째 카드'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focusContext = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.ancestor(
        of: find.byElementPredicate((element) => element == focusContext),
        matching: find.byKey(const Key('card-2')),
      ),
      findsOneWidget,
      reason: '두 번째 Tab 은 두 번째 카드에 닿아야 한다(카드당 정지 1개)',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, ['2']);
  });
}
