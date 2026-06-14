import 'package:dp_design/src/theme/dp_colors.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('라이트 테마는 DpColors.light을 주입한다', (tester) async {
    late DpColors c;
    await tester.pumpWidget(MaterialApp(
      theme: DpTheme.light(),
      home: Builder(builder: (ctx) {
        c = ctx.dpColors;
        return const SizedBox();
      }),
    ));
    expect(c.primary, const Color(0xFF6366F1));      // fill 전용(DD1)
    expect(c.primaryText, const Color(0xFF4F46E5));   // 텍스트/링크 ≥4.5:1
    expect(c.bg, const Color(0xFFF8FAFC));
  });

  testWidgets('다크 테마는 DpColors.dark을 주입한다', (tester) async {
    late DpColors c;
    await tester.pumpWidget(MaterialApp(
      theme: DpTheme.dark(),
      home: Builder(builder: (ctx) {
        c = ctx.dpColors;
        return const SizedBox();
      }),
    ));
    expect(c.bg, const Color(0xFF0F172A));
    expect(c.primaryText, const Color(0xFFA5B4FC)); // 다크 위 링크
  });

  test('lerp는 동일 타입을 반환한다(ThemeExtension 계약)', () {
    final mixed = DpColors.light.lerp(DpColors.dark, 0.5);
    expect(mixed, isA<DpColors>());
  });
}
