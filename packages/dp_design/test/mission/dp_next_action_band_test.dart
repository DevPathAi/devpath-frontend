import 'dart:ui' as ui;

import 'package:dp_design/dp_design.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  ThemeData? theme,
  Size size = const Size(840, 700),
  double textScale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: theme ?? DpTheme.light(),
  themeAnimationDuration: Duration.zero,
  home: MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

DpNextActionBand _band({
  DpNextActionState state = DpNextActionState.ready,
  DpNextActionBandVariant variant = DpNextActionBandVariant.inline,
  ValueChanged<String>? onPressed,
  FocusNode? focusNode,
}) => DpNextActionBand(
  actionId: 'open-sandbox',
  label: '이 맥락으로 실습 시작',
  expectedOutcome: '현재 과제와 starter code가 실습으로 이어집니다.',
  state: state,
  variant: variant,
  pendingLabel: '실습을 준비하는 중',
  disabledReason: state == DpNextActionState.disabled
      ? '현재 과제를 먼저 열어야 합니다.'
      : null,
  onPressed: onPressed,
  focusNode: focusNode,
  subordinateActionId: 'back-to-path',
  subordinateLabel: '경로로 돌아가기',
  onSubordinatePressed: (_) {},
);

void main() {
  testWidgets(
    'ready action relates its label to the expected outcome and returns ID',
    (tester) async {
      String? action;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(_band(onPressed: (id) => action = id)));

      expect(
        find.bySemanticsLabel(
          '이 맥락으로 실습 시작, 예상 결과: 현재 과제와 starter code가 실습으로 이어집니다.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('이 맥락으로 실습 시작'));
      expect(action, 'open-sandbox');
      expect(
        tester
            .getSize(find.byKey(const ValueKey('dp-next-action-primary')))
            .height,
        greaterThanOrEqualTo(44),
      );
      semantics.dispose();
    },
  );

  testWidgets('screen reader activation invokes the primary intent', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? activated;
    await tester.pumpWidget(
      _host(
        DpNextActionBand(
          actionId: 'open-task',
          label: '미션 시작',
          expectedOutcome: '첫 과제를 엽니다',
          state: DpNextActionState.ready,
          onPressed: (id) => activated = id,
        ),
      ),
    );

    final action = tester.getSemantics(
      find.bySemanticsLabel('미션 시작, 예상 결과: 첫 과제를 엽니다'),
    );
    expect(action.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    tester.platformDispatcher.onSemanticsActionEvent!(
      ui.SemanticsActionEvent(
        type: ui.SemanticsAction.tap,
        viewId: tester.view.viewId,
        nodeId: action.id,
      ),
    );
    await tester.pump();
    expect(activated, 'open-task');
    semantics.dispose();
  });

  testWidgets('primary action contributes exactly one keyboard tab stop', (
    tester,
  ) async {
    final primaryFocus = FocusNode();
    final afterFocus = FocusNode();
    addTearDown(primaryFocus.dispose);
    addTearDown(afterFocus.dispose);
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            DpNextActionBand(
              actionId: 'open-task',
              label: '미션 시작',
              expectedOutcome: '첫 과제를 엽니다',
              state: DpNextActionState.ready,
              focusNode: primaryFocus,
              onPressed: (_) {},
            ),
            TextButton(
              focusNode: afterFocus,
              onPressed: () {},
              child: const Text('다음 포커스'),
            ),
          ],
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(primaryFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(afterFocus.hasFocus, isTrue);
  });

  testWidgets('ready/pending/disabled/retry/completed states are explicit', (
    tester,
  ) async {
    for (final entry in <DpNextActionState, String>{
      DpNextActionState.ready: '이 맥락으로 실습 시작',
      DpNextActionState.pending: '실습을 준비하는 중',
      DpNextActionState.disabled: '현재 과제를 먼저 열어야 합니다.',
      DpNextActionState.retry: '다시 시도',
      DpNextActionState.completed: '완료됨',
    }.entries) {
      await tester.pumpWidget(
        _host(_band(state: entry.key, onPressed: (_) {})),
      );
      expect(find.text(entry.value), findsOneWidget, reason: entry.key.name);
    }
  });

  testWidgets(
    'pending rebuild retains primary focus while suppressing activation',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      var calls = 0;
      await tester.pumpWidget(
        _host(_band(onPressed: (_) => calls++, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.pumpWidget(
        _host(
          _band(
            state: DpNextActionState.pending,
            onPressed: (_) => calls++,
            focusNode: focusNode,
          ),
        ),
      );
      expect(focusNode.hasFocus, isTrue);
      await tester.tap(find.byKey(const ValueKey('dp-next-action-primary')));
      expect(calls, 0);
    },
  );

  testWidgets('focus ring is 2px primaryText in light and dark', (
    tester,
  ) async {
    for (final entry in [
      (DpTheme.light(), DpColors.light),
      (DpTheme.dark(), DpColors.dark),
    ]) {
      final focusNode = FocusNode();
      await tester.pumpWidget(
        _host(
          _band(onPressed: (_) {}, focusNode: focusNode),
          theme: entry.$1,
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      final animated = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('dp-next-action-primary-surface')),
      );
      final decoration = animated.decoration as BoxDecoration;
      expect(decoration.border!.top.width, 2);
      expect(decoration.border!.top.color, entry.$2.primaryText);
      focusNode.dispose();
    }
  });

  testWidgets('hover keeps primary-action fill semantics', (tester) async {
    await tester.pumpWidget(_host(_band(onPressed: (_) {})));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('dp-next-action-primary'))),
    );
    await tester.pump();

    final animated = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('dp-next-action-primary-surface')),
    );
    final decoration = animated.decoration as BoxDecoration;
    expect(
      decoration.color,
      Color.alphaBlend(
        DpColors.light.onPrimary.withValues(alpha: 0.08),
        DpColors.light.primary,
      ),
    );
    expect(decoration.color, isNot(DpColors.light.primaryText));
  });

  testWidgets(
    'sticky-safe variant uses SafeArea and never competes with escape action',
    (tester) async {
      await tester.pumpWidget(
        _host(
          _band(variant: DpNextActionBandVariant.stickySafe, onPressed: (_) {}),
        ),
      );
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsOneWidget);
    },
  );

  testWidgets(
    'four width boundaries at 200% text reflow and reduced motion is immediate',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final width in [320.0, 600.0, 840.0, 1240.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          _host(
            _band(onPressed: (_) {}),
            size: Size(width, 900),
            textScale: 2,
            disableAnimations: true,
          ),
        );
        expect(tester.takeException(), isNull, reason: 'width=$width');
        final animated = tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('dp-next-action-primary-surface')),
        );
        expect(animated.duration, Duration.zero);
      }
    },
  );

  test('invalid actionable/disabled inputs fail fast', () {
    expect(
      () => DpNextActionBand(
        actionId: 'open',
        label: '열기',
        expectedOutcome: '열립니다.',
        state: DpNextActionState.ready,
      ),
      throwsAssertionError,
    );
    expect(
      () => DpNextActionBand(
        actionId: 'open',
        label: '열기',
        expectedOutcome: '열립니다.',
        state: DpNextActionState.disabled,
      ),
      throwsAssertionError,
    );
  });
}
