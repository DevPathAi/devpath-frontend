import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'SegmentedButton 세그먼트는 44px 이상의 터치 타깃을 가진다',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: DpTheme.light(),
          home: Scaffold(
            body: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('자유게시판')),
                ButtonSegment(value: 1, label: Text('Q/A')),
                ButtonSegment(value: 2, label: Text('피드백')),
              ],
              selected: const {0},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
      final height = tester.getSize(find.byType(SegmentedButton<int>)).height;
      expect(height, greaterThanOrEqualTo(44));
      // 데스크톱/웹 데스크톱은 기본 VisualDensity 가 compact 라 버튼이 44px 아래로 줄어든다.
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('TextButton 도 데스크톱 밀도에서 44px 을 유지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.code),
            label: const Text('실습'),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(44),
    );
  });
}
