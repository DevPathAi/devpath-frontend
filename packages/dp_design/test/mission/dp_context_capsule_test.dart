import 'dart:ui' as ui;

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

const _fields = [
  DpContextFieldViewModel(
    id: 'goal',
    label: '학습 목표',
    valueSummary: 'Spring 백엔드 취업 준비',
    source: '활성 경로',
    sensitivity: DpContextSensitivity.low,
    inclusion: DpContextInclusion.included,
    editable: true,
  ),
  DpContextFieldViewModel(
    id: 'error',
    label: '최근 오류',
    valueSummary: 'LazyInitializationException',
    source: '최근 실행',
    sensitivity: DpContextSensitivity.potentiallySensitive,
    inclusion: DpContextInclusion.excluded,
  ),
  DpContextFieldViewModel(
    id: 'review',
    label: '기존 리뷰',
    valueSummary: '소유 관계를 다시 확인하세요',
    source: '리뷰 응답',
    sensitivity: DpContextSensitivity.medium,
    inclusion: DpContextInclusion.rejected,
  ),
];

void main() {
  testWidgets(
    'collapsed disclosure reports its name/state and only returns intent',
    (tester) async {
      var toggles = 0;
      await tester.pumpWidget(
        _host(
          DpContextCapsule(
            fields: _fields,
            mode: DpContextCapsuleMode.collapsed,
            onDisclosurePressed: () => toggles++,
          ),
        ),
      );

      expect(find.bySemanticsLabel('학습 맥락, 접힘'), findsOneWidget);
      expect(find.text('Spring 백엔드 취업 준비'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('dp-context-disclosure')));
      expect(toggles, 1);
      expect(find.text('Spring 백엔드 취업 준비'), findsNothing);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('dp-context-disclosure')))
            .height,
        greaterThanOrEqualTo(44),
      );
    },
  );

  testWidgets('screen reader can activate disclosure and field edit actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var disclosures = 0;
    String? editedField;
    await tester.pumpWidget(
      _host(
        DpContextCapsule(
          fields: _fields,
          mode: DpContextCapsuleMode.expanded,
          onDisclosurePressed: () => disclosures++,
          onFieldEditRequested: (id) => editedField = id,
        ),
      ),
    );

    final disclosure = tester.getSemantics(find.bySemanticsLabel('학습 맥락, 펼침'));
    expect(
      disclosure.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    tester.platformDispatcher.onSemanticsActionEvent!(
      ui.SemanticsActionEvent(
        type: ui.SemanticsAction.tap,
        viewId: tester.view.viewId,
        nodeId: disclosure.id,
      ),
    );
    await tester.pump();
    expect(disclosures, 1);

    final edit = tester.getSemantics(find.bySemanticsLabel('전송 전에 수정'));
    expect(edit.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    tester.platformDispatcher.onSemanticsActionEvent!(
      ui.SemanticsActionEvent(
        type: ui.SemanticsAction.tap,
        viewId: tester.view.viewId,
        nodeId: edit.id,
      ),
    );
    await tester.pump();
    expect(editedField, 'goal');
    semantics.dispose();
  });

  testWidgets('expanded fields announce source, inclusion and sensitivity', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const DpContextCapsule(
          fields: _fields,
          mode: DpContextCapsuleMode.expanded,
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        '학습 목표, Spring 백엔드 취업 준비, 출처 활성 경로, 포함됨, 낮은 민감도, 수정 가능',
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(
      find.bySemanticsLabel(
        '최근 오류, LazyInitializationException, 출처 최근 실행, 제외됨, 민감할 수 있음, 수정 불가',
      ),
      findsOneWidget,
    );
  });

  testWidgets('payload preview identifies the exact approved field count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DpContextCapsule(
          fields: _fields,
          mode: DpContextCapsuleMode.payloadPreview,
        ),
      ),
    );
    expect(find.text('전송 범위 미리보기'), findsOneWidget);
    expect(find.text('포함 1개 · 제외 또는 거절 2개'), findsOneWidget);
  });

  testWidgets('controlled expand rebuild keeps focus on the disclosure', (
    tester,
  ) async {
    final focusNode = FocusNode();
    var disclosureCalls = 0;
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      _host(
        DpContextCapsule(
          fields: _fields,
          mode: DpContextCapsuleMode.collapsed,
          disclosureFocusNode: focusNode,
          onDisclosurePressed: () => disclosureCalls++,
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    final focusSurface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('dp-context-disclosure-focus-surface')),
    );
    final focusDecoration = focusSurface.decoration as BoxDecoration;
    expect(focusDecoration.border!.top.width, 2);
    expect(focusDecoration.border!.top.color, DpColors.light.primaryText);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(disclosureCalls, 2);

    await tester.pumpWidget(
      _host(
        DpContextCapsule(
          fields: _fields,
          mode: DpContextCapsuleMode.expanded,
          disclosureFocusNode: focusNode,
          onDisclosurePressed: () => disclosureCalls++,
        ),
      ),
    );
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets(
    'loading/partial/error keep their applicable retained-data contract',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const DpContextCapsule(
            fields: [],
            mode: DpContextCapsuleMode.expanded,
            status: DpContextCapsuleStatus.loading,
          ),
        ),
      );
      expect(find.text('학습 맥락을 불러오는 중'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const DpContextCapsule(
            fields: _fields,
            mode: DpContextCapsuleMode.expanded,
            status: DpContextCapsuleStatus.partial,
            statusMessage: '최근 실행 맥락은 불러오지 못했습니다.',
          ),
        ),
      );
      expect(find.text('최근 실행 맥락은 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('Spring 백엔드 취업 준비'), findsOneWidget);

      var retried = false;
      await tester.pumpWidget(
        _host(
          DpContextCapsule(
            fields: _fields,
            mode: DpContextCapsuleMode.expanded,
            status: DpContextCapsuleStatus.error,
            statusMessage: '맥락을 새로 불러오지 못했습니다.',
            onRetry: () => retried = true,
          ),
        ),
      );
      expect(find.text('Spring 백엔드 취업 준비'), findsOneWidget);
      await tester.tap(find.text('다시 불러오기'));
      expect(retried, isTrue);
    },
  );

  testWidgets('all width boundaries at 200% text reflow expanded content', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final width in [320.0, 600.0, 840.0, 1240.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _host(
          const DpContextCapsule(
            fields: _fields,
            mode: DpContextCapsuleMode.expanded,
          ),
          size: Size(width, 1000),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });

  testWidgets(
    'dark theme uses dark surface/ink and reduced motion is immediate',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const DpContextCapsule(
            fields: _fields,
            mode: DpContextCapsuleMode.expanded,
          ),
          theme: DpTheme.dark(),
          disableAnimations: true,
        ),
      );
      final capsule = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('dp-context-capsule-surface')),
      );
      final decoration = capsule.decoration as BoxDecoration;
      expect(decoration.color, DpColors.dark.surface);
      final title = tester.widget<Text>(find.text('학습 맥락'));
      expect(title.style?.color, DpColors.dark.textPrimary);
      final animated = tester.widget<AnimatedSize>(
        find.byKey(const ValueKey('dp-context-capsule-content')),
      );
      expect(animated.duration, Duration.zero);
    },
  );
}
