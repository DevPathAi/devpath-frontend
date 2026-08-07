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
}
