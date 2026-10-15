import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// web/index.html은 정적 파일이라 위젯 트리로 검증할 수 없다.
/// 크롤러와 링크 미리보기가 보는 것은 이 파일의 `<head>`이므로 직접 읽어 단언한다.
void main() {
  final html = File('web/index.html').readAsStringSync();

  group('앱 진입 HTML 메타', () {
    test('문서 언어를 한국어로 선언한다', () {
      expect(html, contains('<html lang="ko">'));
    });

    // 브랜드 표기 규칙(2026-10-15): 한국어 제목은 「레바」, 영문 병기는 첫 등장만.
    test('브랜드 제목을 쓴다', () {
      expect(html, contains('<title>레바 — 학습 로드맵</title>'));
    });

    test('링크 미리보기와 홈 화면 이름도 레바 표기를 쓴다', () {
      expect(html, contains('<meta property="og:site_name" content="레바" />'));
      expect(
        html,
        contains('<meta property="og:title" content="레바 — 학습 로드맵" />'),
      );
      expect(
        html,
        contains('<meta name="apple-mobile-web-app-title" content="레바">'),
      );
      expect(html, contains('AI 멘토를 제공하는 레바(Leva) 앱입니다.'));
      expect(html, isNot(contains('content="Leva')));
    });

    // 점검 A-3: og:image 가 랜딩의 해시 없는 경로(leva.ai.kr/assets/og-image.png)를
    // 가리켜 404 였다 — 랜딩 빌드는 자산 파일명에 해시를 붙인다. 앱이 직접 서빙한다.
    test('링크 미리보기 이미지는 앱이 직접 서빙한다', () {
      expect(
        html,
        contains(
          '<meta property="og:image" content="https://app.leva.ai.kr/og-image.png" />',
        ),
      );
      expect(html, isNot(contains('leva.ai.kr/assets/og-image')));
      final png = File('web/og-image.png').readAsBytesSync();
      // PNG 시그니처 + IHDR 폭·높이(1200×630, 미리보기 권장 비율).
      expect(png.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      final ihdr = ByteData.sublistView(png, 16, 24);
      expect([ihdr.getUint32(0), ihdr.getUint32(4)], [1200, 630]);
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

    test('초대 fragment를 외부 스크립트보다 먼저 세션으로 옮기고 주소에서 지운다', () {
      final inviteBootstrap = html.indexOf('leva.mentor.invite.v1');
      final adsenseBootstrap = html.indexOf('adsbygoogle.js');
      final adsenseInviteGate = html.indexOf(
        'window.__levaHasPendingMentorInvite !== true',
      );

      expect(inviteBootstrap, greaterThanOrEqualTo(0));
      expect(inviteBootstrap, lessThan(adsenseBootstrap));
      expect(html, contains('window.location.hash'));
      expect(html, contains("sessionStorage.setItem('leva.mentor.invite.v1'"));
      expect(html, contains(r'/^[A-Za-z0-9_-]{32,128}$/'));
      expect(html, contains("searchParams.delete('invite')"));
      expect(html, contains('window.history.replaceState'));
      expect(html, contains('window.__levaHasPendingMentorInvite'));
      expect(adsenseInviteGate, greaterThanOrEqualTo(0));
      expect(adsenseInviteGate, lessThan(adsenseBootstrap));
    });

    // 빌드가 치환하는 자리표시자다. 실수로 값을 박아 넣으면 배포 경로가 깨진다.
    test('base href 자리표시자를 유지한다', () {
      expect(html, contains(r'<base href="$FLUTTER_BASE_HREF">'));
    });
  });

  group('웹 앱 매니페스트', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;

    test('홈 화면에 추가했을 때 이름이 레바다', () {
      expect(manifest['name'], '레바');
      expect(manifest['short_name'], '레바');
      expect(manifest['description'], contains('레바(Leva) 앱입니다.'));
    });
  });
}
