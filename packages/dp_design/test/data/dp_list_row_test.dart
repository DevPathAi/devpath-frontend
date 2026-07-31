import 'package:dp_design/dp_design.dart';
import 'package:flutter/gestures.dart';
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
        home: Scaffold(
          body: DpListRow(title: '글', onTap: () {}),
        ),
      ),
    );
    expect(find.byType(FocusableActionDetector), findsWidgets);
  });

  testWidgets('DpListRow: preview 지정 시 hover로 미리보기 등장', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: Center(
            child: DpListRow(title: '제목 행', preview: '본문 미리보기 요약 텍스트'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('본문 미리보기 요약 텍스트'), findsNothing); // 초기 미표시

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('제목 행')));
    await tester.pumpAndSettle();

    expect(find.text('본문 미리보기 요약 텍스트'), findsOneWidget); // hover 후 등장
  });
}
