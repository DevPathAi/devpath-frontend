import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

EdgeInsets _outerPaddingOf(WidgetTester tester) {
  final padding = tester.widget<Padding>(
    find
        .descendant(
          of: find.byType(DpPageHeader),
          matching: find.byType(Padding),
        )
        .first,
  );
  return padding.padding.resolve(TextDirection.ltr);
}

void main() {
  testWidgets('기본값은 좌우 패딩을 주지 않는다 — 셸이 이미 준다', (tester) async {
    await tester.pumpWidget(_host(const DpPageHeader(title: '오늘')));

    // 시안 `.ph` 에는 패딩이 없다 — 좌우 여백은 `.main` 의 24 한 겹이고,
    // `DpWebShell` 이 그 값을 준다. 여기서 또 주면 두 겹이 된다.
    final p = _outerPaddingOf(tester);
    expect(p.left, 0);
    expect(p.right, 0);
    expect(p.top, DpSpacing.xxl);
  });

  testWidgets('gutter: true 면 좌우 패딩을 스스로 준다 — 셸이 안 주는 admin 용', (tester) async {
    await tester.pumpWidget(
      _host(const DpPageHeader(title: '대시보드', gutter: true)),
    );

    final p = _outerPaddingOf(tester);
    expect(p.left, DpSpacing.xl);
    expect(p.right, DpSpacing.xl);
  });

  testWidgets('제목만 주면 설명·액션·필터는 렌더하지 않는다', (tester) async {
    await tester.pumpWidget(_host(const DpPageHeader(title: '대시보드')));
    expect(find.text('대시보드'), findsOneWidget);
    expect(find.byKey(const ValueKey('page-header-description')), findsNothing);
    expect(find.byKey(const ValueKey('page-header-filters')), findsNothing);
  });

  testWidgets('제목은 headlineSmall 스케일을 쓴다', (tester) async {
    await tester.pumpWidget(_host(const DpPageHeader(title: '대시보드')));
    final widget = tester.widget<Text>(find.text('대시보드'));
    expect(widget.style?.fontSize, 28);
    expect(widget.style?.fontWeight, FontWeight.w700);
    expect(widget.style?.height, 36 / 28);
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
    // 기본값(gutter: false)에서는 헤더 자신이 좌우 패딩을 주지 않으므로 액션이
    // 헤더의 우측 끝에 정확히 붙는다. 거터는 셸이 본문 전체에 준다.
    expect(headerRight - actionRight, closeTo(0, 1.0));
  });

  testWidgets('gutter: true 면 액션이 헤더의 우측 패딩만큼 떨어진다', (tester) async {
    tester.view.physicalSize = const Size(1000, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const DpPageHeader(
          title: '대시보드',
          gutter: true,
          actions: [
            SizedBox(width: 100, key: ValueKey('act'), child: Text('실습')),
          ],
        ),
      ),
    );

    final headerRight = tester.getRect(find.byType(DpPageHeader)).right;
    final actionRight = tester.getRect(find.byKey(const ValueKey('act'))).right;
    expect(headerRight - actionRight, closeTo(DpSpacing.xl, 1.0));
  });

  testWidgets('제목은 언제나 헤더이며 메뉴 버튼이 되지 않는다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const DpPageHeader(title: 'Q/A', description: '막힌 곳을 질문하세요.')),
    );

    // 시안에 제목 메뉴가 없다. 게시판 이동은 셸 헤더 메뉴만 담당한다.
    expect(find.byKey(const ValueKey('page-header-title-menu')), findsNothing);
    expect(
      tester.getSemantics(find.text('Q/A')),
      matchesSemantics(label: 'Q/A', isHeader: true),
    );
    handle.dispose();
  });
}
