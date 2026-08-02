import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// `<em>...</em>` 만 인식하는 화이트리스트 패턴. 게으른 수량자라 가장 가까운 닫는 태그와 짝짓는다.
final _emPattern = RegExp('<em>(.*?)</em>', dotAll: true);

/// ES 하이라이트 문자열을 [TextSpan] 으로 분해한다.
///
/// ★보안 계약: **ES 하이라이터는 매칭 토큰만 `<em>` 으로 감쌀 뿐, 사용자가 쓴 본문의
/// `<`·`>` 를 이스케이프하지 않는다.** 어떤 글의 본문에 `<img src=x onerror=alert(1)>` 이
/// 있고 그 글이 검색에 걸리면 그 마크업이 그대로 `highlight` 에 실려 온다.
///
/// 그래서 이 함수는 `<em>` 만 강조로 인식하고 **나머지는 전부 평문으로 취급**한다. 태그처럼
/// 생긴 문자열은 해석되지 않고 문자 그대로 남는다. 이 문자열을 HTML 로 해석해 렌더하는
/// 방식(`flutter_html` 등)으로 바꾸지 말 것 — 그 순간 취약점이 된다.
List<InlineSpan> highlightSpans(String raw, {required TextStyle emphasis}) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in _emPattern.allMatches(raw)) {
    if (m.start > last) {
      spans.add(TextSpan(text: raw.substring(last, m.start)));
    }
    spans.add(TextSpan(text: m.group(1), style: emphasis));
    last = m.end;
  }
  if (last < raw.length) {
    spans.add(TextSpan(text: raw.substring(last)));
  }
  return spans.isEmpty ? [const TextSpan(text: '')] : spans;
}

/// 검색 결과의 매칭 구간을 강조해 보여주는 텍스트. 자세한 계약은 [highlightSpans] 참조.
class SearchHighlightText extends StatelessWidget {
  const SearchHighlightText(this.raw, {super.key, this.maxLines = 2});

  final String raw;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final base = Theme.of(context).textTheme.bodySmall;
    return Text.rich(
      TextSpan(
        children: highlightSpans(
          raw,
          emphasis: TextStyle(fontWeight: FontWeight.w700, color: c.primary),
        ),
      ),
      style: base?.copyWith(color: c.textSecondary),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
