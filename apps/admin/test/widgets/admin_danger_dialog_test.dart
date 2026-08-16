import 'package:devpath_admin/src/widgets/admin_danger_dialog.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failure keeps the confirmation open and announces the error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showAdminDangerDialog(
                context: context,
                title: '광고 삭제',
                impact: '선택한 광고 2개가 운영 노출에서 즉시 제거됩니다.',
                confirmLabel: '2개 삭제',
                onConfirm: () async => throw const ApiException(
                  code: ApiErrorCode.unknown,
                  message: '삭제하지 못했어요',
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('선택한 광고 2개가 운영 노출에서 즉시 제거됩니다.'), findsOneWidget);

    await tester.tap(find.text('2개 삭제'));
    await tester.pumpAndSettle();

    expect(find.text('광고 삭제'), findsOneWidget);
    expect(find.text('삭제하지 못했어요'), findsOneWidget);
    final liveRegion = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(liveRegion.properties.liveRegion, isTrue);
  });
}
