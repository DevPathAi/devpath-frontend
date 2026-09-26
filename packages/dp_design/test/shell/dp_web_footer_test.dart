import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _host({void Function(String)? onTap, double? textScale}) => MaterialApp(
  theme: DpTheme.light(),
  builder: (context, child) => textScale == null
      ? child!
      : MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
  home: Scaffold(
    body: Column(
      children: [
        const Spacer(),
        DpWebFooter(
          notice: '© 레바 · 사업자등록번호 796-76-00732',
          links: [
            for (final label in ['이용약관', '개인정보 처리방침', '오류 신고·문의', '업데이트 소식'])
              (label: label, onTap: () => onTap?.call(label)),
          ],
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('사업자 표기와 링크 4종을 낸다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host());

    expect(find.text('© 레바 · 사업자등록번호 796-76-00732'), findsOneWidget);
    for (final label in ['이용약관', '개인정보 처리방침', '오류 신고·문의', '업데이트 소식']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('링크를 누르면 콜백이 불린다', (tester) async {
    _setWidth(tester, 1240);
    String? tapped;
    await tester.pumpWidget(_host(onTap: (label) => tapped = label));

    await tester.tap(find.text('오류 신고·문의'));
    expect(tapped, '오류 신고·문의');
  });

  // Review Focus 5
  testWidgets('링크의 시맨틱 박스는 최소 타깃 24 이상이다', (tester) async {
    // 해제는 본문 끝에서 명시적으로 한다 — 핸들 검증이 tearDown 보다 먼저 돈다.
    final handle = tester.ensureSemantics();

    _setWidth(tester, 1240);
    await tester.pumpWidget(_host());

    for (final label in ['이용약관', '개인정보 처리방침', '오류 신고·문의', '업데이트 소식']) {
      final rect = tester.getSemantics(find.text(label)).rect;
      expect(
        rect.height,
        greaterThanOrEqualTo(DpDensity.minTarget),
        reason:
            '$label 의 시맨틱 박스 높이가 ${rect.height} — 12px 글자에 패딩이 없으면 2.5.8 을 깬다',
      );
    }
    handle.dispose();
  });

  // Review Focus 4
  testWidgets('390 폭 · 텍스트 200% 에서 줄바꿈으로 흡수하고 오버플로하지 않는다', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(_host(textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('안쪽 내용은 contentMaxWidth 로 중앙 정렬된다', (tester) async {
    _setWidth(tester, 1600);
    await tester.pumpWidget(_host());

    expect(
      find.descendant(
        of: find.byType(DpWebFooter),
        matching: find.byType(DpMaxWidth),
      ),
      findsOneWidget,
    );
  });
}
