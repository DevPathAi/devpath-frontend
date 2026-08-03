import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  group('DpError 보조 액션', () {
    testWidgets('onReport 가 없으면 문의하기 버튼이 없다 — 기존 호출부 무회귀', (tester) async {
      await tester.pumpWidget(
        _wrap(DpError(message: '문제가 생겼어요', onRetry: () {})),
      );

      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.text('문의하기'), findsNothing);
    });

    testWidgets('onReport 가 있으면 문의하기 버튼이 보이고 눌린다', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          DpError(
            message: '문제가 생겼어요',
            onRetry: () {},
            onReport: () => tapped++,
          ),
        ),
      );

      expect(find.text('문의하기'), findsOneWidget);
      await tester.tap(find.text('문의하기'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('onRetry 없이 onReport 만 있어도 보조 버튼이 보인다', (tester) async {
      await tester.pumpWidget(
        _wrap(DpError(message: '문제가 생겼어요', onReport: () {})),
      );

      expect(find.text('다시 시도'), findsNothing);
      expect(find.text('문의하기'), findsOneWidget);
    });
  });

  group('DpStateScaffold 보조 액션', () {
    testWidgets('보조 파라미터가 없으면 1차 행동만 렌더한다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DpStateScaffold(
            icon: DpIcons.empty,
            title: '비었어요',
            actionLabel: '새로고침',
            onAction: () {},
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('보조 파라미터가 둘 다 있어야 렌더한다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DpStateScaffold(
            icon: DpIcons.error,
            title: '오류',
            secondaryActionLabel: '문의하기',
            onSecondaryAction: () {},
          ),
        ),
      );

      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text('문의하기'), findsOneWidget);
    });
  });
}
