import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('medium 폭에서 레일을 펼칠 수 있다', (tester) async {
    // medium(600~840): 기본 접힘. 2단계에서는 onToggleRail을 넘기지 않아
    // 사용자가 펼칠 방법이 없었다.
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const AppShellView(location: '/dashboard', child: SizedBox()),
      ),
    );

    final railRoot = find.byKey(const ValueKey('rail-root'));

    // 접힘 상태에서는 라벨이 안 보인다. '오늘'은 브레드크럼에도 등장하는
    // 문자열이라 레일 안으로 범위를 좁힌다.
    expect(
      find.descendant(of: railRoot, matching: find.text('오늘')),
      findsNothing,
    );

    await tester.tap(find.byTooltip('메뉴 펼치기'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: railRoot, matching: find.text('오늘')),
      findsOneWidget,
    );
  });
}
