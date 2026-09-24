import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'SegmentedButton 세그먼트는 30px 컨트롤 높이(±4)이며 24px 최소 타깃을 넘는다',
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
      expect(height, greaterThanOrEqualTo(DpDensity.minTarget));
      expect(
        height,
        inInclusiveRange(DpDensity.controlHeight, DpDensity.controlHeight + 4),
      );
      // 계약 2.0.0(스펙 §5.4-1): 포인터 밀도. 44px 터치 기준은 2026-09-19 에 24px(WCAG 2.2 AA 2.5.8)로 옮겼다.
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('TextButton 은 30px 컨트롤이고 한 줄 라벨을 자르지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: Center(
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.code),
              label: const Text('실습으로 돌아가기'),
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(TextButton));
    expect(size.height, DpDensity.controlHeight);
    expect(tester.takeException(), isNull); // 오버플로 없음
  });

  testWidgets('FilledButton 은 30px 이고 인접 버튼과 8px 이상 떨어지면 2.5.8 간격 예외를 만족한다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: Row(
            children: [
              FilledButton(onPressed: () {}, child: const Text('실습 시작하기')),
              const SizedBox(width: DpSpacing.sm),
              OutlinedButton(onPressed: () {}, child: const Text('취소')),
            ],
          ),
        ),
      ),
    );
    final filled = tester.getRect(find.byType(FilledButton));
    final outlined = tester.getRect(find.byType(OutlinedButton));
    expect(filled.height, DpDensity.controlHeight);
    expect(outlined.height, DpDensity.controlHeight);
    expect(outlined.left - filled.right, greaterThanOrEqualTo(DpSpacing.sm));
  });
}
