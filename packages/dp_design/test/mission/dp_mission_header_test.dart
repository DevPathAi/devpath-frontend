import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
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

DpMissionHeader _header({
  DpMissionHeaderVariant variant = DpMissionHeaderVariant.standard,
  DpMissionHeaderStatus status = DpMissionHeaderStatus.active,
  FocusNode? headingFocusNode,
}) => DpMissionHeader(
  eyebrow: '3주차 · 미션 2',
  title: 'JPA 연관관계의 주인을 설명하고 안전하게 매핑하기',
  why: '이전 실습에서 생긴 중복 쿼리를 줄이기 위한 미션입니다.',
  completionCriterion: '테스트 3개가 통과하면 완료',
  progressValue: 0.5,
  progressLabel: '이번 주 진행',
  variant: variant,
  status: status,
  headingFocusNode: headingFocusNode,
);

void main() {
  testWidgets(
    'standard mission ledger exposes ordered heading and progress semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(_header()));

      expect(find.text('3주차 · 미션 2'), findsOneWidget);
      expect(find.text('완료 조건 · 테스트 3개가 통과하면 완료'), findsOneWidget);
      final heading = tester.getSemantics(
        find.byKey(const ValueKey('dp-mission-header-title')),
      );
      expect(heading.flagsCollection.isHeader, isTrue);
      expect(find.bySemanticsLabel('이번 주 진행, 50%'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('compact and standard variants use distinct contract spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_header(variant: DpMissionHeaderVariant.compact)),
    );
    final compact = tester.widget<Padding>(
      find.byKey(const ValueKey('dp-mission-header-padding')),
    );
    expect(compact.padding, const EdgeInsets.all(DpSpacing.md));

    await tester.pumpWidget(_host(_header()));
    final standard = tester.widget<Padding>(
      find.byKey(const ValueKey('dp-mission-header-padding')),
    );
    expect(standard.padding, const EdgeInsets.all(DpSpacing.xl));
  });

  testWidgets(
    'loading, stale, active and completed are explicit presentation states',
    (tester) async {
      for (final entry in <DpMissionHeaderStatus, String>{
        DpMissionHeaderStatus.loading: '미션 정보를 불러오는 중',
        DpMissionHeaderStatus.stale: '마지막으로 확인한 미션',
        DpMissionHeaderStatus.active: '진행 중',
        DpMissionHeaderStatus.completed: '완료됨',
      }.entries) {
        await tester.pumpWidget(_host(_header(status: entry.key)));
        expect(find.text(entry.value), findsOneWidget, reason: entry.key.name);
      }
    },
  );

  testWidgets(
    'heading is programmatically focusable but skipped in tab traversal',
    (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(_host(_header(headingFocusNode: node)));

      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      final focus = tester.widget<Focus>(
        find.byKey(const ValueKey('dp-mission-header-heading-focus')),
      );
      expect(focus.skipTraversal, isTrue);
    },
  );

  testWidgets(
    '320px at 200% text and all four width boundaries do not overflow',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final width in [320.0, 600.0, 840.0, 1240.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          _host(_header(), size: Size(width, 900), textScale: 2),
        );
        expect(tester.takeException(), isNull, reason: 'width=$width');
      }
    },
  );

  testWidgets('light and dark themes use their semantic surface/ink tokens', (
    tester,
  ) async {
    for (final entry in [
      (DpTheme.light(), DpColors.light),
      (DpTheme.dark(), DpColors.dark),
    ]) {
      await tester.pumpWidget(_host(_header(), theme: entry.$1));
      final box = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('dp-mission-header-surface')),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, entry.$2.surface);
      final title = tester.widget<Text>(
        find.byKey(const ValueKey('dp-mission-header-title')),
      );
      expect(title.style?.color, entry.$2.textPrimary);
    }
  });
}
