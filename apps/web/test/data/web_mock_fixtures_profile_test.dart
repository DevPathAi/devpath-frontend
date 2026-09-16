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
}
