import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import 'components/app.dart';

void main() {
  // 정적(SSG) 사이트 — @client 컴포넌트가 없어 기본 ServerOptions로 충분.
  // (jaspr_options.dart codegen은 client 옵션 생성용 — 정적 전용이라 불필요.)
  Jaspr.initializeApp();

  runApp(
    Document(
      lang: 'ko', // <html lang="ko"> — SEO/접근성 (jaspr 0.23 Document.lang)
      title: 'DevPath AI — 개발자를 위한 AI 학습 플랫폼',
      charset: 'utf-8',
      viewport: 'width=device-width, initial-scale=1.0',
      meta: {
        'description':
            '한국 개발자를 위한 AI 학습 경로·코드 샌드박스·AI 멘토. GitHub 분석으로 12주 맞춤 경로를 만드세요.',
        'og:title': 'DevPath AI',
        'og:description': 'AI가 만드는 맞춤 학습 경로 — 진단부터 멘토까지.',
        'og:type': 'website',
      },
      head: [
        link(rel: 'stylesheet', href: 'styles.css'),
      ],
      body: const App(),
    ),
  );
}
