import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 800}) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void _noop() {}

void main() {
  testWidgets('DpInlineNotice는 메시지를 liveRegion으로 알린다', (tester) async {
    await tester.pumpWidget(
      _host(const DpInlineNotice(message: '완료를 저장하지 못했어요.')),
    );
    expect(find.text('완료를 저장하지 못했어요.'), findsOneWidget);
    final node = tester.getSemantics(
      find.byKey(const ValueKey('dp-inline-notice')),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('DpInlineNotice는 행동 라벨이 있을 때만 버튼을 렌더하고 호출한다', (tester) async {
    var acted = false;
    await tester.pumpWidget(
      _host(
        DpInlineNotice(
          message: '보조 학습 지표를 불러오지 못했어요.',
          tone: DpInlineNoticeTone.warning,
          actionLabel: '지표 다시 보기',
          onAction: () => acted = true,
        ),
      ),
    );
    await tester.tap(find.text('지표 다시 보기'));
    expect(acted, isTrue);
  });

  testWidgets('DpInlineNotice는 onAction이 null이면 버튼을 비활성으로 둔다', (tester) async {
    await tester.pumpWidget(
      _host(
        const DpInlineNotice(
          message: '진행률을 저장하지 못했어요.',
          actionLabel: '진행률 저장 다시 시도',
        ),
      ),
    );
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('DpInlineNotice는 좁은 폭에서 세로로 쌓이고 넓은 폭에서 가로로 놓인다', (tester) async {
    Widget notice() => const DpInlineNotice(
      message: '메시지',
      actionLabel: '다시 시도',
      onAction: _noop,
    );
    await tester.pumpWidget(_host(notice(), width: 360));
    final narrowMessage = tester.getTopLeft(find.text('메시지'));
    final narrowButton = tester.getTopLeft(find.text('다시 시도'));
    expect(narrowButton.dy, greaterThan(narrowMessage.dy));

    await tester.pumpWidget(_host(notice(), width: 800));
    final wideMessage = tester.getCenter(find.text('메시지'));
    final wideButton = tester.getCenter(find.text('다시 시도'));
    expect((wideButton.dy - wideMessage.dy).abs(), lessThan(24));
    expect(wideButton.dx, greaterThan(wideMessage.dx));
  });
}
