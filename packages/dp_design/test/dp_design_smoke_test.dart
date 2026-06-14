import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('barrel로 테마·상태위젯이 노출된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: DpEmpty(title: '비어 있음')),
      ),
    );
    expect(find.text('비어 있음'), findsOneWidget);
    expect(DpColors.light.primary, const Color(0xFF6366F1));
  });
}
