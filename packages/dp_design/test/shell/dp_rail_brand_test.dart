import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter의 effectiveTextStyle을 재현한다 — Text는 style.inherit==true일 때
/// DefaultTextStyle.of(context).style.merge(style)로 최종 스타일을 만든다.
/// merge는 인자 쪽 non-null을 취하므로, 앱이 색을 실은 스타일을 넘기면
/// 컴포넌트가 깐 railText가 진다. 2단계에서 이 결함이 319/319 green으로
/// 통과했다(라이트 textPrimary == railBg → 대비 1.00:1).
Color effectiveColorOf(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  final widget = tester.widget<Text>(finder);
  final base = DefaultTextStyle.of(element).style;
  return base.merge(widget.style).color!;
}

void main() {
  Widget host(DpColors colors, ThemeData theme, {required bool extended}) =>
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: DpNavRail(
            destinations: const [
              DpDestination(icon: Icons.home, label: '대시보드'),
            ],
            selectedIndex: 0,
            onSelect: (_) {},
            extended: extended,
            brand: DpRailBrand(
              mark: const SizedBox(
                key: ValueKey('brand-mark'),
                width: 22,
                height: 22,
              ),
              wordmark: 'DevPath',
            ),
          ),
        ),
      );

  testWidgets('펼침에서 워드마크 실효색이 railText다 (라이트)', (tester) async {
    final theme = DpTheme.light();
    await tester.pumpWidget(host(DpColors.light, theme, extended: true));

    final color = effectiveColorOf(tester, find.text('DevPath'));
    expect(color, DpColors.light.railText);
  });

  testWidgets('펼침에서 워드마크 실효색이 railText다 (다크)', (tester) async {
    final theme = DpTheme.dark();
    await tester.pumpWidget(host(DpColors.dark, theme, extended: true));

    final color = effectiveColorOf(tester, find.text('DevPath'));
    // 주의: 다크 팔레트는 textPrimary == railText(#EAE7E2)라 이 단언은
    // 현재 가드로서 무력하다 — 함정이 재발해도 통과한다. 라이트 분기가
    // 실질 가드다. 다크 팔레트에서 두 값이 갈리면 이 주석을 지워라.
    expect(color, DpColors.dark.railText);
  });

  testWidgets('접힘에서 마크는 남고 워드마크는 사라진다', (tester) async {
    await tester.pumpWidget(
      host(DpColors.light, DpTheme.light(), extended: false),
    );

    expect(find.byKey(const ValueKey('brand-mark')), findsOneWidget);
    expect(find.text('DevPath'), findsNothing);
  });
}
