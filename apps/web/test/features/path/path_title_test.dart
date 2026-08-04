import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('본문에 화면 제목을 반복하지 않는다 — 헤더가 제목을 갖는다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: Column(
            children: const [
              DpPageHeader(title: '학습 경로'),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 헤더에만 있어야 한다.
    expect(find.text('학습 경로'), findsOneWidget);
  });
}
