import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TextField 는 밀도 토큰으로 30px 근처의 한 줄 컨트롤이 된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: TextField(
                decoration: InputDecoration(hintText: '검색  Ctrl K'),
              ),
            ),
          ),
        ),
      ),
    );
    final height = tester.getSize(find.byType(TextField)).height;
    expect(
      height,
      inInclusiveRange(DpDensity.controlHeight, DpDensity.controlHeight + 6),
    );
  });

  testWidgets('IconButton 은 30x30 이며 24px 최소 타깃을 넘는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: Center(
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.search),
              tooltip: '검색',
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, DpDensity.controlHeight);
    expect(size.height, DpDensity.controlHeight);
    expect(size.shortestSide, greaterThanOrEqualTo(DpDensity.minTarget));
  });
}
