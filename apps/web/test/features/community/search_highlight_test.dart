import 'package:devpath_web/src/features/community/presentation/widgets/search_highlight.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ES 하이라이터가 돌려주는 `highlight` 문자열의 렌더 계약을 고정한다.
///
/// ★핵심: ES 는 매칭 토큰만 `<em>` 으로 감쌀 뿐 **사용자 본문의 `<`·`>` 를 이스케이프하지
/// 않는다.** 따라서 본문에 마크업이 있으면 그대로 응답에 실려 온다. `<em>` 만 화이트리스트로
/// 인식하고 나머지는 전부 평문으로 취급해야 한다.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: DpTheme.light(),
    home: Scaffold(body: child),
  );

  test('em 구간만 강조 스팬으로 분리하고 나머지는 평문이다', () {
    final spans = highlightSpans(
      '앞부분 <em>검색어</em> 뒷부분',
      emphasis: const TextStyle(fontWeight: FontWeight.bold),
    );

    expect(spans.map((s) => (s as TextSpan).text).toList(), [
      '앞부분 ',
      '검색어',
      ' 뒷부분',
    ]);
    expect((spans[1] as TextSpan).style?.fontWeight, FontWeight.bold);
    expect((spans[0] as TextSpan).style, isNull);
  });

  test('em 이 없으면 전체가 평문 한 스팬이다', () {
    final spans = highlightSpans(
      '강조 없는 본문',
      emphasis: const TextStyle(fontWeight: FontWeight.bold),
    );

    expect(spans.length, 1);
    expect((spans.single as TextSpan).text, '강조 없는 본문');
    expect((spans.single as TextSpan).style, isNull);
  });

  test('★em 이 아닌 태그는 해석하지 않고 문자 그대로 남긴다', () {
    const raw = '위험 <img src=x onerror=alert(1)> 그리고 <em>매칭</em>';
    final spans = highlightSpans(
      raw,
      emphasis: const TextStyle(fontWeight: FontWeight.bold),
    );

    // <img ...> 는 강조 대상이 아니라 평문 — 즉 마크업이 사라지지도, 해석되지도 않는다.
    expect(
      (spans.first as TextSpan).text,
      '위험 <img src=x onerror=alert(1)> 그리고 ',
    );
    expect((spans[1] as TextSpan).text, '매칭');
  });

  test('닫히지 않은 em 은 평문으로 취급한다(크래시 없음)', () {
    final spans = highlightSpans(
      '<em>열리기만 함',
      emphasis: const TextStyle(fontWeight: FontWeight.bold),
    );

    expect(spans.length, 1);
    expect((spans.single as TextSpan).text, '<em>열리기만 함');
  });

  testWidgets('★SearchHighlightText: 스크립트 문자열이 위젯을 만들지 않는다', (tester) async {
    await tester.pumpWidget(
      host(
        const SearchHighlightText('<img src=x onerror=alert(1)> <em>키워드</em>'),
      ),
    );
    await tester.pumpAndSettle();

    // 문자 그대로 렌더돼야 한다.
    expect(
      find.textContaining('<img src=x onerror=alert(1)>', findRichText: true),
      findsOneWidget,
    );
    // 태그가 해석돼 이미지가 생기면 안 된다.
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('SearchHighlightText: em 태그 자체는 화면에 노출되지 않는다', (tester) async {
    await tester.pumpWidget(
      host(const SearchHighlightText('본문 <em>키워드</em> 끝')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('<em>', findRichText: true), findsNothing);
    expect(find.textContaining('키워드', findRichText: true), findsOneWidget);
  });
}
