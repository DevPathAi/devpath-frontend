import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 목 모드가 기본값이라 픽스처가 없으면 화면이 에러로 뜬다.
  // 2026-08-03 실측에서 아래 셋이 누락돼 설정·마이페이지·콘텐츠가 깨져 있었다.
  test('사용자가 도달하는 주요 GET 은 픽스처가 있다', () {
    expect(webMockFixtures.containsKey('GET /consents/me'), isTrue);
    expect(webMockFixtures.containsKey('GET /users/me/profile'), isTrue);
    expect(webMockFixtures.containsKey('GET /notifications/prefs/me'), isTrue);
  });

  test('콘텐츠 진행 저장 픽스처가 있다', () {
    expect(webMockFixtures.containsKey('POST /contents/c1/progress'), isTrue);
  });

  test('상태코드는 성공 범위다', () {
    for (final key in [
      'GET /consents/me',
      'GET /users/me/profile',
      'POST /contents/c1/progress',
    ]) {
      final (status, _) = webMockFixtures[key]!;
      expect(status, inInclusiveRange(200, 299), reason: key);
    }
  });
}
