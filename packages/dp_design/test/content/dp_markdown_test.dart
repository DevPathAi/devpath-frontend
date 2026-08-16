import 'package:dp_design/src/content/dp_markdown.dart';
import 'package:dp_design/src/theme/dp_colors.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:dp_design/src/theme/dp_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';

void main() {
  test('최신 overflow 알림이 오래된 예정 상태를 취소한다', () {
    var transition = resolveDpMarkdownOverflowTransition(
      committed: false,
      pending: null,
      next: true,
    );
    expect(transition, (pending: true, shouldSchedule: true));

    transition = resolveDpMarkdownOverflowTransition(
      committed: false,
      pending: transition.pending,
      next: false,
    );
    expect(transition, (pending: null, shouldSchedule: false));

    transition = resolveDpMarkdownOverflowTransition(
      committed: true,
      pending: false,
      next: true,
    );
    expect(transition, (pending: null, shouldSchedule: false));
  });

  testWidgets('마크다운 텍스트와 코드 블록을 렌더한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: DpMarkdown(
              data: '# 제목\n\n본문 텍스트\n\n```dart\nvoid main() {}\n```',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('제목'), findsWidgets);
    expect(find.byType(DpMarkdown), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dp-markdown-code-focus-target')),
      findsNothing,
    );
  });

  testWidgets('스크롤되는 코드 블록에 키보드 포커스 대상을 제공한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: DpMarkdown(
              data:
                  '```dart\nFuture<int> answer() async => 42; // horizontal overflow\n```',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(DpMarkdown),
      matching: find.byType(Scrollable),
    );
    final focusTarget = find.byKey(
      const ValueKey('dp-markdown-code-focus-target'),
    );

    expect(scrollable, findsOneWidget);
    expect(focusTarget, findsOneWidget);

    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    final initialFocused = tester
        .getSemantics(focusTarget)
        .flagsCollection
        .isFocused
        .toBoolOrNull();
    expect(initialFocused, isNotNull, reason: '키보드 포커스 가능 플래그가 필요하다.');
    expect(initialFocused, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(focusTarget)).hasFocus, isTrue);

    final beforeArrow = position.pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(beforeArrow));
  });

  testWidgets('같은 프레임의 오래된 overflow 알림을 포커스 상태에 반영하지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: DpMarkdown(data: '```dart\n42\n```')),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(DpMarkdown),
      matching: find.byType(Scrollable),
    );
    final context = tester.element(scrollable);
    final metricsListener = tester
        .widget<NotificationListener<ScrollMetricsNotification>>(
          find.byKey(const ValueKey('dp-markdown-code-scroll-metrics')),
        );
    FixedScrollMetrics metrics(double maxScrollExtent) => FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: maxScrollExtent,
      pixels: 0,
      viewportDimension: 100,
      axisDirection: AxisDirection.right,
      devicePixelRatio: 1,
    );

    metricsListener.onNotification!(
      ScrollMetricsNotification(metrics: metrics(100), context: context),
    );
    metricsListener.onNotification!(
      ScrollMetricsNotification(metrics: metrics(0), context: context),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('dp-markdown-code-focus-target')),
      findsNothing,
    );
  });

  testWidgets('학습 본문 읽기 폭과 명시적 타이포그래피 계약을 적용한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 1200,
            child: DpMarkdown(
              data: '# 제목\n\n본문과 `inline` 코드\n\n```java\nclass Main {}\n```',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final markdown = tester.widget<MarkdownBlock>(find.byType(MarkdownBlock));
    final config = markdown.config!;
    final preDecoration = config.pre.decoration as BoxDecoration;

    expect(tester.getSize(find.byType(MarkdownBlock)).width, 720);
    expect(config.p.textStyle.fontFamily, DpTypography.family);
    expect(config.p.textStyle.fontSize, 16);
    expect(config.p.textStyle.height, 1.6);
    expect(config.p.textStyle.color, DpColors.light.textPrimary);
    expect(config.h1.style.fontFamily, DpTypography.family);
    expect(config.h1.style.color, DpColors.light.textPrimary);
    expect(config.code.style.fontFamily, DpTypography.codeFamily);
    expect(config.code.style.backgroundColor, DpColors.light.surfaceMuted);
    expect(config.pre.textStyle.fontFamily, DpTypography.codeFamily);
    expect(config.pre.textStyle.color, DpColors.light.codeText);
    expect(preDecoration.color, DpColors.light.codeEditorBg);
    expect(config.a.style.color, DpColors.light.primaryText);
    expect(config.hr.color, DpColors.light.border);
  });

  testWidgets('다크 모드에서도 토큰 색과 좁은 화면 폭을 유지한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: const Scaffold(body: DpMarkdown(data: '본문과 `code`')),
      ),
    );
    await tester.pumpAndSettle();

    final markdown = tester.widget<MarkdownBlock>(find.byType(MarkdownBlock));
    final config = markdown.config!;
    final preDecoration = config.pre.decoration as BoxDecoration;

    expect(tester.getSize(find.byType(MarkdownBlock)).width, 320);
    expect(config.p.textStyle.color, DpColors.dark.textPrimary);
    expect(config.code.style.backgroundColor, DpColors.dark.surfaceMuted);
    expect(config.pre.textStyle.color, DpColors.dark.codeText);
    expect(preDecoration.color, DpColors.dark.codeEditorBg);
    expect(config.a.style.color, DpColors.dark.primaryText);
    expect(config.blockquote.textColor, DpColors.dark.textSecondary);
  });
}
