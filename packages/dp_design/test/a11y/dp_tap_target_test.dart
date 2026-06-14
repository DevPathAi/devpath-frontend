import 'package:dp_design/src/a11y/dp_tap_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('작은 child도 44x44 이상 탭 영역을 보장한다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DpTapTarget(
              semanticLabel: '닫기',
              onTap: () => tapped = true,
              child: const Icon(Icons.close, size: 16),
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(DpTapTarget));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));

    await tester.tap(find.byType(DpTapTarget));
    expect(tapped, isTrue);
    expect(find.bySemanticsLabel('닫기'), findsOneWidget);
  });
}
