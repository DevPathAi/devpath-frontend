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
    expect(widget.style?.fontWeight, FontWeight.w600);
    expect(widget.style?.height, 32 / 24);
  });

  testWidgets('설명·액션·필터 슬롯을 렌더', (tester) async {
    await tester.pumpWidget(
      _host(
        const DpPageHeader(
          title: '사용자 관리',
          description: '가입 승인과 제재를 처리합니다',
          actions: [Text('액션')],
          filters: [Text('필터')],
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

  // DpChromeBar에서 실제로 확인된 것과 같은 결함 패턴: Row에서 제목만 Expanded이고
  // actions의 Wrap이 non-flex 자식이면 무한 주축 제약으로 측정돼 줄바꿈하지 않고
  // 오버플로한다. actions의 Wrap도 Flexible로 감싸야 좁은 폭에서 실제로 줄바꿈된다.
  testWidgets('좁은 폭 + 넓은 액션 여러 개에서도 오버플로 없이 렌더된다', (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        DpPageHeader(
          title: List.filled(20, '가').join(),
          actions: List.generate(
            3,
            (i) => const SizedBox(width: 160, child: Text('액션 하나')),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  // Flexible 회귀: Expanded(제목)와 Flexible(액션)이 둘 다 기본 flex:1이라
  // 자유 공간을 1:1로 나눠 액션이 헤더 한가운데쯤 뜨고 오른쪽이 텅 빈다.
  // 액션은 상한 폭만 갖고 flex 자식이 아니어야 Expanded가 남는 공간을 전부
  // 흡수해 액션이 우측 끝에 붙는다.
  testWidgets('넉넉한 폭에서 좁은 액션 하나는 헤더 우측 끝에 붙는다', (tester) async {
    tester.view.physicalSize = const Size(1000, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const DpPageHeader(
          title: '대시보드',
          actions: [
            SizedBox(width: 100, key: ValueKey('act'), child: Text('실습')),
          ],
        ),
      ),
    );

    final headerRight = tester.getRect(find.byType(DpPageHeader)).right;
    final actionRight = tester.getRect(find.byKey(const ValueKey('act'))).right;
    // 헤더의 우측 패딩(DpSpacing.lg = 16)만큼만 떨어져 있어야 한다.
    expect(headerRight - actionRight, closeTo(16, 1.0));
  });
}
