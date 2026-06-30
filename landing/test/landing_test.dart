import 'package:jaspr_test/jaspr_test.dart';

import 'package:devpath_landing/components/app.dart';
import 'package:devpath_landing/components/hero.dart';

void main() {
  group('landing', () {
    testComponents('Hero는 헤드라인과 CTA 링크를 렌더한다', (tester) async {
      tester.pumpComponent(const Hero());
      expect(find.text('무료로 시작하기'), findsOneComponent);
      expect(find.tag('a'), findsOneComponent); // CTA <a>
    });

    testComponents('App은 Hero·Features·Footer를 포함한다', (tester) async {
      tester.pumpComponent(const App());
      expect(find.text('GitHub를 분석해 12주 학습 경로를 만들어요'), findsOneComponent);
      expect(find.text('AI 멘토'), findsOneComponent);
      expect(find.textContaining('DevPath AI'), findsOneComponent); // footer
    });
  });
}
