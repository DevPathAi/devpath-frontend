import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('기본 mock 프로필은 온보딩 PENDING 이다', () {
    expect(mockAuthRefreshUser()['onboardingStatus'], 'PENDING');
    expect(mockProfile, 'pending');
  });

  test('MOCK_PROFILE=onboarded 는 온보딩 DONE 유저를 만든다', () {
    final user = mockAuthRefreshUser(profile: 'onboarded');
    expect(user['onboardingStatus'], 'DONE');
    expect(user['consentStatus'], 'DONE');
    expect(user['id'], 'u-mock');
  });

  test('알 수 없는 프로필은 PENDING 으로 안전하게 떨어진다', () {
    expect(
      mockAuthRefreshUser(profile: 'weird')['onboardingStatus'],
      'PENDING',
    );
  });

  // browser-ux 가 /login·/diagnostic·/beta-pending·/auth/callback 을 재려면 그
  // 빌드가 미인증이어야 한다 — 라우터 게이트가 인증 상태에서 그 화면을 전부
  // 돌려보낸다. 세션 복원이 401 로 실패하는 것이 미인증을 만드는 경로다
  // (auth_controller.dart `_performBootstrap` 의 ApiException 분기).
  test('guest 프로필은 세션 복원을 401 로 거절한다', () {
    final (status, _) = webMockFixturesFor('guest')['POST /auth/refresh']!;
    expect(status, 401);
  });

  test('guest 의 401 본문은 사람이 읽는 문장을 담는다', () {
    // /auth/callback 은 복원 실패 메시지를 화면에 렌더한다
    // (bootstrapFromCallback 이 includeApiError: true 로 부른다).
    final (_, body) = webMockFixturesFor('guest')['POST /auth/refresh']!;
    final error = (body as Map)['error'] as Map;
    expect(error['code'], 'UNAUTHORIZED');
    expect(error['message'], isA<String>());
    expect((error['message'] as String).isNotEmpty, isTrue);
  });

  test('guest 가 아닌 프로필은 세션 복원이 200 이고 유저를 담는다', () {
    for (final profile in const ['pending', 'onboarded', 'consent']) {
      final (status, body) = webMockFixturesFor(profile)['POST /auth/refresh']!;
      expect(status, 200, reason: profile);
      expect(
        (body as Map)['user'],
        isA<Map<String, dynamic>>(),
        reason: profile,
      );
    }
  });

  test('consent 프로필의 유저는 consentStatus 가 PENDING 이다', () {
    expect(mockAuthRefreshUser(profile: 'consent')['consentStatus'], 'PENDING');
  });

  test('consent 외의 프로필은 consentStatus 가 DONE 이다', () {
    for (final profile in const ['pending', 'onboarded', 'guest']) {
      expect(
        mockAuthRefreshUser(profile: profile)['consentStatus'],
        'DONE',
        reason: profile,
      );
    }
  });

  test('ambient webMockFixtures 는 webMockFixturesFor(mockProfile) 과 같다', () {
    // 두 접근자가 갈라지면 빌드가 쓰는 픽스처와 테스트가 재는 픽스처가 달라진다.
    // 레코드끼리 비교하면 안 된다 — `(int, Map)` 의 `==` 는 Map 을 동일성으로 보므로
    // 매 호출이 만드는 새 Map 이 결코 같지 않다. 구성요소로 갈라 값으로 비교한다.
    final ambient = webMockFixturesFor(mockProfile);
    expect(webMockFixtures.keys.toSet(), ambient.keys.toSet());
    final (ambientStatus, ambientBody) = ambient['POST /auth/refresh']!;
    final (status, body) = webMockFixtures['POST /auth/refresh']!;
    expect(status, ambientStatus);
    expect(body, ambientBody);
  });
}
