import 'package:dp_design/dp_design.dart';
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

const _steps = [
  DpProgressStep(
    id: 'promise',
    label: '학습 목표 확인',
    state: DpProgressStepState.completed,
  ),
  DpProgressStep(
    id: 'practice',
    label: '현재 미션 실습',
    state: DpProgressStepState.current,
  ),
  DpProgressStep(
    id: 'review',
    label: '리뷰와 다음 보정',
    state: DpProgressStepState.upcoming,
  ),
  DpProgressStep(
    id: 'locked',
    label: '아직 사용할 수 없음',
    state: DpProgressStepState.unavailable,
  ),
];

void main() {
  testWidgets(
    'vertical/horizontal/text layouts preserve the same ordered semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final layout in DpProgressSpineLayout.values) {
        await tester.pumpWidget(
          _host(
            DpProgressSpine(
              steps: _steps,
              currentStepId: 'practice',
              layout: layout,
            ),
          ),
        );
        expect(find.text('학습 목표 확인'), findsOneWidget);
        expect(
          find.bySemanticsLabel('1/4 학습 목표 확인, 완료'),
          findsOneWidget,
          reason: layout.name,
        );
        expect(
          find.bySemanticsLabel('2/4 현재 미션 실습, 현재 단계'),
          findsOneWidget,
          reason: layout.name,
        );
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'steps become keyboard targets only when navigation intent is supplied',
    (tester) async {
      await tester.pumpWidget(
        _host(const DpProgressSpine(steps: _steps, currentStepId: 'practice')),
      );
      expect(find.byType(FocusableActionDetector), findsNothing);

      String? selected;
      await tester.pumpWidget(
        _host(
          DpProgressSpine(
            steps: _steps,
            currentStepId: 'practice',
            onStepPressed: (id) => selected = id,
          ),
        ),
      );
      expect(find.byType(FocusableActionDetector), findsNWidgets(3));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focusSurface = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('dp-progress-step-surface-promise')),
      );
      final focusDecoration = focusSurface.decoration as BoxDecoration;
      expect(focusDecoration.border!.top.width, 2);
      expect(focusDecoration.border!.top.color, DpColors.light.primaryText);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(selected, 'promise');
      selected = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(selected, 'promise');
      await tester.tap(find.text('아직 사용할 수 없음'));
      expect(selected, 'promise');
    },
  );

  testWidgets('each navigable step contributes one keyboard tab stop', (
    tester,
  ) async {
    final afterFocus = FocusNode();
    addTearDown(afterFocus.dispose);
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            DpProgressSpine(
              steps: _steps,
              currentStepId: 'practice',
              onStepPressed: (_) {},
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

    for (var index = 0; index < 4; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(afterFocus.hasFocus, isTrue);
  });

  testWidgets(
    'horizontal spine reflows at four width boundaries and 200% text',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final width in [320.0, 600.0, 840.0, 1240.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          _host(
            const DpProgressSpine(
              steps: _steps,
              currentStepId: 'practice',
              layout: DpProgressSpineLayout.horizontal,
            ),
            size: Size(width, 900),
            textScale: 2,
          ),
        );
        expect(tester.takeException(), isNull, reason: 'width=$width');
      }
    },
  );

  testWidgets(
    'horizontal spine uses a narrow nested panel constraint, not screen width',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              child: DpProgressSpine(
                steps: _steps,
                currentStepId: 'practice',
                layout: DpProgressSpineLayout.horizontal,
              ),
            ),
          ),
          size: const Size(1240, 900),
          textScale: 2,
        ),
      );

      expect(tester.takeException(), isNull);
      for (final surface
          in find
              .byWidgetPredicate(
                (widget) =>
                    widget is AnimatedContainer &&
                    widget.key is ValueKey<String> &&
                    (widget.key! as ValueKey<String>).value.startsWith(
                      'dp-progress-step-surface-',
                    ),
              )
              .evaluate()) {
        expect(tester.getSize(find.byWidget(surface.widget)).width, 200);
      }
    },
  );

  testWidgets(
    'state transition becomes immediate when reduced motion is enabled',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const DpProgressSpine(steps: _steps, currentStepId: 'practice'),
          disableAnimations: true,
        ),
      );
      final animated = tester.widgetList<AnimatedContainer>(
        find.byKey(const ValueKey('dp-progress-step-indicator')),
      );
      expect(animated, isNotEmpty);
      expect(
        animated.every((widget) => widget.duration == Duration.zero),
        isTrue,
      );
    },
  );

  testWidgets(
    'dark theme maps current/completed states to dark semantic tokens',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const DpProgressSpine(steps: _steps, currentStepId: 'practice'),
          theme: DpTheme.dark(),
        ),
      );
      final indicators = tester.widgetList<AnimatedContainer>(
        find.byKey(const ValueKey('dp-progress-step-indicator')),
      );
      final completed = indicators.elementAt(0).decoration as BoxDecoration;
      final current = indicators.elementAt(1).decoration as BoxDecoration;
      expect(completed.border!.top.color, DpColors.dark.success);
      expect(current.color, DpColors.dark.primary);
      final currentLabel = tester.widget<Text>(find.text('현재 미션 실습'));
      expect(currentLabel.style?.color, DpColors.dark.primaryTextStrong);
    },
  );

  testWidgets('currentStepId must match exactly one current state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DpProgressSpine(steps: _steps, currentStepId: 'promise')),
    );
    expect(tester.takeException(), isA<AssertionError>());

    await tester.pumpWidget(
      _host(const DpProgressSpine(steps: [], currentStepId: '')),
    );
    expect(tester.takeException(), isA<AssertionError>());
  });
}
