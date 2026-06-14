import 'package:dp_design/src/states/dp_empty.dart';
import 'package:dp_design/src/states/dp_error.dart';
import 'package:dp_design/src/states/dp_loading.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('DpEmpty는 카피 + 1차 행동을 노출한다', (tester) async {
    var acted = false;
    await tester.pumpWidget(
      _host(
        DpEmpty(
          title: '첫 질문을 남겨보세요',
          actionLabel: '질문 작성',
          onAction: () => acted = true,
        ),
      ),
    );
    expect(find.text('첫 질문을 남겨보세요'), findsOneWidget);
    await tester.tap(find.text('질문 작성'));
    expect(acted, isTrue);
  });

  testWidgets('DpError는 재시도를 호출한다', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _host(DpError(message: '문제가 발생했어요', onRetry: () => retried = true)),
    );
    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
  });

  testWidgets('DpLoading은 진행 표시를 렌더한다', (tester) async {
    await tester.pumpWidget(_host(const DpLoading()));
    expect(find.byType(DpLoading), findsOneWidget);
  });
}
