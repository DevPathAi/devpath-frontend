import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, ThemeData theme) => MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('배경은 tagBg, 전경은 tagText다', (tester) async {
    await tester.pumpWidget(
      host(const DpTag(label: '#flutter'), DpTheme.light()),
    );

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('dp-tag')),
    );
    expect(
      (container.decoration! as BoxDecoration).color,
      DpColors.light.tagBg,
    );

    final text = tester.widget<Text>(find.text('#flutter'));
    expect(text.style!.color, DpColors.light.tagText);
  });

  testWidgets('tone이 주어지면 전경만 덮고 배경은 tagBg를 유지한다', (tester) async {
    await tester.pumpWidget(
      host(DpTag(label: '스팸', tone: DpColors.light.danger), DpTheme.light()),
    );

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('dp-tag')),
    );
    expect(
      (container.decoration! as BoxDecoration).color,
      DpColors.light.tagBg,
    );

    final text = tester.widget<Text>(find.text('스팸'));
    expect(text.style!.color, DpColors.light.danger);
  });

  testWidgets('다크에서도 tagBg/tagText를 쓴다', (tester) async {
    await tester.pumpWidget(host(const DpTag(label: '#dart'), DpTheme.dark()));

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('dp-tag')),
    );
    expect((container.decoration! as BoxDecoration).color, DpColors.dark.tagBg);

    final text = tester.widget<Text>(find.text('#dart'));
    expect(text.style!.color, DpColors.dark.tagText);
  });
}
