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

  // 2026-08-03: 회원(로그인) 진단 흐름 — assessment_api.dart의 회원 경로
  // (assessmentId 기반) 전부. 이 중 하나라도 빠지면 온보딩 게이트가 진단
  // 화면으로 보낸 로그인 회원이 그 지점에서 다시 막힌다.
  test('회원 진단 경로 픽스처가 전부 있다', () {
    expect(webMockFixtures.containsKey('POST /onboarding/assessments'), isTrue);
    expect(
      webMockFixtures.containsKey('GET /onboarding/assessments/1/next'),
      isTrue,
    );
    expect(
      webMockFixtures.containsKey('POST /onboarding/assessments/1/answer'),
      isTrue,
    );
    expect(
      webMockFixtures.containsKey('POST /onboarding/assessments/1/complete'),
      isTrue,
    );
    expect(
      webMockFixtures.containsKey('POST /onboarding/assessments/claim'),
      isTrue,
    );
    expect(
      webMockFixtures.containsKey('GET /onboarding/assessments/1/result'),
      isTrue,
    );
  });

  test('상태코드는 성공 범위다', () {
    for (final key in [
      'GET /consents/me',
      'GET /users/me/profile',
      'GET /notifications/prefs/me',
      'POST /contents/c1/progress',
      'POST /onboarding/assessments',
      'GET /onboarding/assessments/1/next',
      'POST /onboarding/assessments/1/answer',
      'POST /onboarding/assessments/1/complete',
      'POST /onboarding/assessments/claim',
      'GET /onboarding/assessments/1/result',
    ]) {
      final (status, _) = webMockFixtures[key]!;
      expect(status, inInclusiveRange(200, 299), reason: key);
    }
  });
}
