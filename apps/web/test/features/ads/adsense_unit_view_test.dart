import 'package:devpath_web/src/features/ads/presentation/adsense_unit_view.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('VM(stub)에서는 아무것도 그리지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: AdSenseUnitView(slotId: '1234567890')),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(AdSenseUnitView));
    expect(size.height, 0);
  });
}
