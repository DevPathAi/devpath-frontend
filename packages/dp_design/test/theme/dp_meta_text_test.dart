import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시안 `.meta`·`.ex` 는 `font-size` 만 덮고 `line-height` 를 덮지 않는다 —
/// `body{line-height:1.6}` 을 그대로 물려받는다. 그래서 시안의 12px 보조 문구
/// 행간은 19.2 이고, `labelMedium`(12 / 16)은 **다른 용도**(한 줄 상태·태그·
/// 표 머리)의 토큰이다. 이 테스트가 그 둘을 갈라 둔다.
void main() {
  late BuildContext ctx;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: DpTheme.light(),
      home: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  testWidgets('dpMeta 는 시안 .meta — 12px 에 body 의 행간 1.6', (tester) async {
    await pump(tester);
    final meta = ctx.dpMeta;
    expect(meta.fontSize, 12);
    expect(meta.height, 1.6);
    expect(meta.fontFamily, DpTypography.family);
    expect(meta.fontWeight, isNot(FontWeight.w600), reason: '보조 문구는 강조가 아니다');
  });

  testWidgets('dpMeta 는 labelMedium 과 다른 스타일이다', (tester) async {
    await pump(tester);
    final labelMedium = Theme.of(ctx).textTheme.labelMedium!;
    expect(labelMedium.fontSize, 12);
    expect(labelMedium.height, 16 / 12, reason: '토큰 계약 2.0.0 값 — 바꾸지 않는다');
    expect(ctx.dpMeta.height, isNot(labelMedium.height));
  });

  testWidgets('dpBody 는 크기만 바꾸고 나머지는 본문 토큰을 잇는다', (tester) async {
    await pump(tester);
    final body = Theme.of(ctx).textTheme.bodyMedium!;
    final small = ctx.dpBody(11);
    expect(small.fontSize, 11);
    expect(small.height, body.height);
    expect(small.fontFamily, body.fontFamily);
  });
}
