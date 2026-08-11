import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

Color _iconColor(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon).first).color!;

void main() {
  // 서비스 상태는 사용자 잘못도 위험도 아니다 → 경고색이 아니라 중립을 쓴다.
  // 액센트(앰버)와 warning 의 계열 충돌도 이 재배치로 해소된다.
  testWidgets('DpKillSwitch 아이콘은 중립색', (tester) async {
    await tester.pumpWidget(_wrap(const DpKillSwitch()));
    expect(_iconColor(tester), DpColors.light.textSecondary);
  });

  testWidgets('DpQuota 아이콘은 중립색', (tester) async {
    // 생성자 실측: DpQuota({super.key, required this.retryAfterSeconds, this.onUpgrade})
    await tester.pumpWidget(_wrap(const DpQuota(retryAfterSeconds: 60)));
    expect(_iconColor(tester), DpColors.light.textSecondary);
  });

  testWidgets('DpSandboxUnavailable 아이콘은 중립색', (tester) async {
    await tester.pumpWidget(_wrap(const DpSandboxUnavailable()));
    expect(_iconColor(tester), DpColors.light.textSecondary);
  });

  testWidgets('DpOfflineBanner 는 중립 배경과 중립 아이콘', (tester) async {
    await tester.pumpWidget(_wrap(const DpOfflineBanner()));
    expect(_iconColor(tester), DpColors.light.textSecondary);
    final box = tester.widget<Container>(find.byType(Container).first);
    // 설치된 Flutter SDK(container.dart)는 color 를 decoration 에 접지 않고
    // Container.color 필드로 별도 보관한다(실측 확인, decoration==null) → color 로 단언.
    expect(box.color, DpColors.light.surfaceMuted);
  });
}
