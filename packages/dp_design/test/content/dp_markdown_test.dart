import 'package:dp_design/src/content/dp_markdown.dart';
import 'package:dp_design/src/theme/dp_colors.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:dp_design/src/theme/dp_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';

void main() {
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
