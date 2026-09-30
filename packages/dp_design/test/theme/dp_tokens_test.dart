import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:dp_design/src/theme/dp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('테마는 AppTokens.standard를 주입한다', (tester) async {
    late AppTokens t;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Builder(
          builder: (ctx) {
            t = ctx.appTokens;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(t.contentMaxWidth, 1120);
    expect(t.readableMaxWidth, 760);
    expect(t.railWidth, 280);
    expect(t.railCollapsedWidth, 80);
    expect(t.panelRadius, 8);
    expect(t.headerHeight, 56);
  });

  testWidgets('다크 테마도 동일 레이아웃 토큰(밝기 무관)', (tester) async {
    late AppTokens t;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: Builder(
          builder: (ctx) {
            t = ctx.appTokens;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(t.railWidth, 280);
  });

  test('lerp는 동일 타입을 반환한다(ThemeExtension 계약)', () {
    final mixed = AppTokens.standard.lerp(AppTokens.standard, 0.5);
    expect(mixed, isA<AppTokens>());
  });
}
