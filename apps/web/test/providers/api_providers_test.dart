import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // POST /auth/login 픽스처는 실흐름에 없으므로 제거됨(Task 4).
  // 실흐름: OAuth 리다이렉트 → 콜백 → POST /auth/refresh → 세션 복원.
  test('목 모드 apiClient는 /auth/refresh 픽스처를 반환한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final client = container.read(apiClientProvider);
    final data = await client.post<Map<String, dynamic>>('/auth/refresh');

    expect(data['access_token'], isNotEmpty);
    expect(data['refresh_token_cookie_set'], isTrue);
    expect((data['user'] as Map)['nickname'], '지수');
  });

  test('목 모드 초대 교환 성공은 후속 mentor access 조회를 ACTIVE로 전이한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final client = container.read(apiClientProvider);

    final before = await client.get<Map<String, dynamic>>('/mentor-access/me');
    await client.post<Map<String, dynamic>>(
      '/mentor-access/redeem',
      body: {'code': 'A' * 43},
    );
    final after = await client.get<Map<String, dynamic>>('/mentor-access/me');

    expect(before['status'], 'WAITLISTED');
    expect(after['status'], 'ACTIVE');
    expect(after['source'], 'INVITE_CODE');
    expect(after['activatedAt'], isNotNull);
  });

  test('tokenStore는 InMemory 기본 구현이다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(tokenStoreProvider), isA<InMemoryTokenStore>());
  });

  test('LearningPathApi provider는 공용 인증 ApiClient를 사용한다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(learningPathApiProvider).client,
      same(container.read(apiClientProvider)),
    );
  });

  test('목 모드 LearningPathApi가 authoritative current mission을 반환한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mission = await container
        .read(learningPathApiProvider)
        .currentMission();

    expect(mission.outcome, CurrentMissionOutcome.available);
    expect(mission.pathId, 101);
    expect(mission.nextTask?.taskId, 1003);
  });
}
