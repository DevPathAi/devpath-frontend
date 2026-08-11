import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('좁은 폭에서 filters가 줄바꿈해 오버플로하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpPageHeader(
            title: '사용자 관리',
            filters: [
              const Text('상태:'),
              for (final s in [
                '전체',
                'ACTIVE',
                'BETA_PENDING',
                'SUSPENDED',
                'DELETED',
              ])
                ChoiceChip(label: Text(s), selected: false, onSelected: (_) {}),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
