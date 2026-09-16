import 'package:dp_design/src/theme/dp_colors.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('라이트 테마는 DpColors.light을 주입한다', (tester) async {
    late DpColors c;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Builder(
          builder: (ctx) {
            c = ctx.dpColors;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(c.primary, const Color(0xFF5653E7));
    expect(c.primaryText, const Color(0xFF4338CA));
    expect(c.bg, const Color(0xFFF6F7FB));
  });

  testWidgets('다크 테마는 DpColors.dark을 주입한다', (tester) async {
    late DpColors c;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: Builder(
          builder: (ctx) {
            c = ctx.dpColors;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(c.bg, const Color(0xFF0D0F15));
    expect(c.primaryText, const Color(0xFFB9B8FF));
  });

  test('lerp는 동일 타입을 반환한다(ThemeExtension 계약)', () {
    final mixed = DpColors.light.lerp(DpColors.dark, 0.5);
    expect(mixed, isA<DpColors>());
  });
}
