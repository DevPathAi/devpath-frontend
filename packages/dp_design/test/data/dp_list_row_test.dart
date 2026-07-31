import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DpListRow: 제목·뱃지·trailing 렌더 + onTap 콜백', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpListRow(
            title: 'Riverpod 3 마이그레이션 질문',
            accentColor: const Color(0xFF4F6EF7),
            badges: const [Text('Q&A')],
            trailing: const Text('답변 3'),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riverpod 3 마이그레이션 질문'), findsOneWidget);
    expect(find.text('Q&A'), findsOneWidget);
    expect(find.text('답변 3'), findsOneWidget);

    await tester.tap(find.text('Riverpod 3 마이그레이션 질문'));
    expect(tapped, isTrue);
  });

  testWidgets('DpListRow: hover/focus 베이스(FocusableActionDetector) 존재', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(body: DpListRow(title: '글', onTap: () {})),
      ),
    );
    expect(find.byType(FocusableActionDetector), findsWidgets);
  });
}
