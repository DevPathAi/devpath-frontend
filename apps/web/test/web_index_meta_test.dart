import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// web/index.html은 정적 파일이라 위젯 트리로 검증할 수 없다.
/// 크롤러와 링크 미리보기가 보는 것은 이 파일의 `<head>`이므로 직접 읽어 단언한다.
void main() {
  final html = File('web/index.html').readAsStringSync();

  group('앱 진입 HTML 메타', () {
    test('문서 언어를 한국어로 선언한다', () {
      expect(html, contains('<html lang="ko">'));
    });

    test('브랜드 제목을 쓴다', () {
      expect(html, contains('<title>Leva — 학습 로드맵</title>'));
    });

    test('앱이 무엇인지 설명한다', () {
      expect(html, contains('적응형 진단 결과에서 시작하는 맞춤 학습 로드맵'));
    });

    // 본문이 캔버스에 그려져 HTML에는 텍스트가 없다. 빈 페이지가 색인되면
    // 사이트 품질 신호에 불리하다. 검색 유입은 홈페이지가 전담한다.
    test('검색 색인을 막는다', () {
      expect(html, contains('<meta name="robots" content="noindex"'));
    });

    test('링크 미리보기용 OG 태그를 갖춘다', () {
      for (final property in [
        'og:type',
        'og:site_name',
        'og:title',
        'og:description',
        'og:url',
        'og:image',
        'og:locale',
      ]) {
        expect(html, contains('property="$property"'), reason: '$property 누락');
      }
    });
  });

  group('회귀 가드', () {
    test('Flutter 기본 템플릿 문자열이 되돌아오지 않는다', () {
      expect(html, isNot(contains('A new Flutter project.')));
      expect(html, isNot(contains('<title>devpath_web</title>')));
    });

    // 메타를 정리하다 광고 배선을 지우는 사고를 막는다.
    test('애드센스 스크립트와 퍼블리셔 ID가 그대로 있다', () {
      expect(html, contains('adsbygoogle.js'));
      expect(html, contains('ca-pub-2785578834914321'));
    });

    // 빌드가 치환하는 자리표시자다. 실수로 값을 박아 넣으면 배포 경로가 깨진다.
    test('base href 자리표시자를 유지한다', () {
      expect(html, contains(r'<base href="$FLUTTER_BASE_HREF">'));
    });
  });
}
