import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../config.dart' show kWebAppUrl;

class Hero extends StatelessComponent {
  const Hero({super.key});

  @override
  Component build(BuildContext context) {
    return section(classes: 'hero', [
      h1([.text('GitHub를 분석해 12주 학습 경로를 만들어요')]),
      p(classes: 'sub', [
        .text('진단 → AI 경로 생성 → 코드 샌드박스 → AI 멘토까지, 한 곳에서.'),
      ]),
      a(href: kWebAppUrl, classes: 'cta', [.text('무료로 시작하기')]),
    ]);
  }
}
