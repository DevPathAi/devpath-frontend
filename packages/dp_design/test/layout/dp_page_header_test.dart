import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('제목만 주면 설명·액션·필터는 렌더하지 않는다', (tester) async {
    await tester.pumpWidget(_host(const DpPageHeader(title: '대시보드')));
    expect(find.text('대시보드'), findsOneWidget);
    expect(find.byKey(const ValueKey('page-header-description')), findsNothing);
    expect(find.byKey(const ValueKey('page-header-filters')), findsNothing);
  });

  testWidgets('제목은 headlineSmall 스케일을 쓴다', (tester) async {
    await tester.pumpWidget(_host(const DpPageHeader(title: '대시보드')));
    final widget = tester.widget<Text>(find.text('대시보드'));
    expect(widget.style?.fontSize, 24);
  });

  testWidgets('설명·액션·필터 슬롯을 렌더', (tester) async {
    await tester.pumpWidget(
      _host(
        const DpPageHeader(
          title: '사용자 관리',
          description: '가입 승인과 제재를 처리합니다',
          actions: [Text('액션')],
          filters: Text('필터'),
        ),
      ),
    );
    expect(find.text('가입 승인과 제재를 처리합니다'), findsOneWidget);
    expect(find.text('액션'), findsOneWidget);
    expect(find.text('필터'), findsOneWidget);
  });

  // 색 토큰이 실제로 배선됐는지 — 제목/설명이 뒤바뀌지 않았음을 증명한다.
  testWidgets('제목은 textPrimary, 설명은 textSecondary 토큰을 쓴다(뒤바뀌지 않음)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DpPageHeader(title: '대시보드', description: '요약 설명')),
    );
    final title = tester.widget<Text>(find.text('대시보드'));
    expect(title.style?.color, DpColors.light.textPrimary);

    final description = tester.widget<Text>(find.text('요약 설명'));
    expect(description.style?.color, DpColors.light.textSecondary);
  });
}
