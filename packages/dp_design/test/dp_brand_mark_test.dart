import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DpBrandMark는 "DevPath" 텍스트를 렌더한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DpBrandMark()));
    expect(find.text('DevPath'), findsOneWidget);
  });
}
