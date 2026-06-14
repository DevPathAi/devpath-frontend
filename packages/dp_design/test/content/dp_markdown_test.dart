import 'package:dp_design/src/content/dp_markdown.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
