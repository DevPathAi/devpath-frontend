import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class Features extends StatelessComponent {
  const Features({super.key});

  static const _items = [
    ('맞춤 경로', 'GitHub 분석으로 약점을 매핑해 12주 경로를 생성합니다.'),
    ('코드 샌드박스', '브라우저에서 바로 작성·실행하고 AI 리뷰를 받습니다.'),
    ('AI 멘토', '막힌 부분을 실시간 스트리밍으로 질문하세요.'),
  ];

  @override
  Component build(BuildContext context) {
    return section(classes: 'features', [
      for (final (title, desc) in _items)
        div(classes: 'feature', [
          h3([.text(title)]),
          p([.text(desc)]),
        ]),
    ]);
  }
}
