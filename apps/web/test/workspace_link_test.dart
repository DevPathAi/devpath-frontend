import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('apps/web가 workspace 멤버 dp_design을 cross-import해 렌더한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DpBrandMark()));
    expect(find.text('DevPath'), findsOneWidget); // dp_design 심볼이 실제로 해석됨
  });
}
