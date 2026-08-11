import 'package:devpath_web/src/features/dashboard/presentation/widgets/progress_donut.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ProgressDonut: 중앙에 퍼센트 라벨 렌더', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: Center(child: ProgressDonut(percent: 62))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('62%'), findsOneWidget);
  });
}
