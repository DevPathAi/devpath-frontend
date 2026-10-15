import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/common/presentation/brand_row.dart';

void main() {
  testWidgets('좁은 폭에서 brandRow가 오버플로하지 않는다', (tester) async {
    // 실측: 320px는 이 actions 조합(TextButton 2개)에서 실제로 오버플로하지
    // 않는다(수정 전 코드로 확인) — 300px에서는 49px 오버플로가 재현된다.
    // 데스크톱 브라우저는 임의 폭으로 축소 가능하므로 300px도 정당한
    // 시나리오다(공개 API인 actions 값 자체는 브리프와 동일, 폭만 실측 조정).
    tester.view.physicalSize = const Size(300, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => brandRow(
              context,
              actions: [
                TextButton(onPressed: () {}, child: const Text('로그아웃')),
                TextButton(onPressed: () {}, child: const Text('도움말')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  // 운영 실측(2026-10-15, 1280px): 테마 토글이 오른쪽 끝이 아니라 694px 지점에 있었다.
  // 워드마크를 감싼 `Flexible`(loose)과 `Spacer` 가 남는 폭을 반씩 나눠 가져,
  // 워드마크가 쓰지 않은 몫이 액션 **뒤**에 남았다.
  for (final width in [390.0, 1280.0, 1920.0]) {
    testWidgets('${width.toInt()}px 에서 액션이 오른쪽 끝에 붙는다', (tester) async {
      await tester.pumpWidget(_actionHost(tester, width));

      final action = tester.getRect(
        find.byKey(const ValueKey('brand-row-action')),
      );
      expect(action.right, closeTo(width - DpSpacing.lg, 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('워드마크는 로고 바로 옆에서 시작한다', (tester) async {
    await tester.pumpWidget(_actionHost(tester, 1280));

    final mark = tester.getRect(find.byType(DpBrandMark));
    final wordmark = tester.getRect(find.text('레바'));
    expect(wordmark.left, closeTo(mark.right + DpSpacing.sm, 0.5));
  });
}

/// 화면들처럼 폭 전체로 늘어난 Column 안에 놓는다(로그인은 stretch Column).
Widget _actionHost(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return MaterialApp(
    theme: DpTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            brandRow(
              context,
              actions: [
                IconButton(
                  key: const ValueKey('brand-row-action'),
                  icon: const Icon(Icons.dark_mode),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
