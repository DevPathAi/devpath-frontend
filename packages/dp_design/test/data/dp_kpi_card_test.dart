import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DpKpiCard: 라벨·카운트업 최종값·suffix 렌더', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: DpKpiCard(
            label: '연속 학습',
            value: 7,
            suffix: '일',
            icon: Icons.local_fire_department,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(); // 카운트업 애니메이션 종료까지

    expect(find.text('연속 학습'), findsOneWidget);
    expect(find.text('7일'), findsOneWidget);
  });

  testWidgets('DpKpiCard: progress 슬롯 지정 시 진행바 렌더', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: DpKpiCard(label: '진척', value: 3, progress: 0.5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
