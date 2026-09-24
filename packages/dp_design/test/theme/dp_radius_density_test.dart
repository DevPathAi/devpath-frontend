import 'package:dp_design/dp_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DpRadius 2.0.0 — 웹 문법 반경(칩 4·버튼 6·카드 8·입력 6·다이얼로그 12)', () {
    expect(DpRadius.chip, 4);
    expect(DpRadius.button, 6);
    expect(DpRadius.card, 8);
    expect(DpRadius.input, 6);
    expect(DpRadius.dialog, 12);
  });

  test('DpDensity — 포인터 밀도(컨트롤 30·행 여백 8·최소 타깃 24 = WCAG 2.2 AA 2.5.8)', () {
    expect(DpDensity.controlHeight, 30);
    expect(DpDensity.rowPadding, 8);
    expect(DpDensity.minTarget, 24);
    expect(DpDensity.minTarget, lessThan(DpDensity.controlHeight));
  });

  test('AppTokens.standard — 웹 레이아웃 폭·헤더 높이, panelRadius 는 카드 반경과 같다', () {
    expect(AppTokens.standard.contentMaxWidth, 1120);
    expect(AppTokens.standard.readableMaxWidth, 760);
    expect(AppTokens.standard.headerHeight, 56);
    expect(AppTokens.standard.panelRadius, DpRadius.card);
    // apps/admin 의 DpAppShell·DpNavRail 이 아직 쓰는 레일 폭은 P2 까지 그대로 둔다.
    expect(AppTokens.standard.railWidth, 280);
    expect(AppTokens.standard.railCollapsedWidth, 80);
  });

  test('AppTokens.copyWith/lerp 는 headerHeight 를 함께 다룬다', () {
    final taller = AppTokens.standard.copyWith(headerHeight: 64);
    expect(taller.headerHeight, 64);
    expect(taller.contentMaxWidth, AppTokens.standard.contentMaxWidth);
    final lerped = AppTokens.standard.lerp(taller, 1);
    expect(lerped, isA<AppTokens>());
    expect((lerped as AppTokens).headerHeight, 64);
  });
}
