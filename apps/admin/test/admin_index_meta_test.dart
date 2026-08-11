import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 관리자 도구는 링크 공유 대상이 아니므로 OG는 두지 않는다.
/// 검색 색인만 확실히 막고 기본 템플릿 문자열을 걷어낸다.
void main() {
  final html = File('web/index.html').readAsStringSync();

  group('관리자 진입 HTML 메타', () {
    test('문서 언어를 한국어로 선언한다', () {
      expect(html, contains('<html lang="ko">'));
    });

    test('브랜드 제목을 쓴다', () {
      expect(html, contains('<title>Leva 관리자</title>'));
    });

    test('무엇을 위한 화면인지 설명한다', () {
      expect(html, contains('Leva 서비스 운영을 위한 관리자 도구입니다.'));
    });

    test('검색 색인을 막는다', () {
      expect(html, contains('<meta name="robots" content="noindex"'));
    });
  });

  group('회귀 가드', () {
    test('Flutter 기본 템플릿 문자열이 되돌아오지 않는다', () {
      expect(html, isNot(contains('A new Flutter project.')));
      expect(html, isNot(contains('<title>devpath_admin</title>')));
    });

    test('base href 자리표시자를 유지한다', () {
      expect(html, contains(r'<base href="$FLUTTER_BASE_HREF">'));
    });
  });
}
