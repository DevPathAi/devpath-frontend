import 'package:devpath_mobile/src/data/mobile_mock_fixtures.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock mode는 authoritative Today에서 canonical content까지 이어진다', () async {
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://api.test', useMock: true),
    );
    client.dio.httpClientAdapter = MockHttpAdapter(mobileMockFixtures);

    final mission = await LearningPathApi(client).currentMission();
    final task = mission.nextTask!;
    final contentJson = await client.get<Map<String, dynamic>>(
      '/contents/${task.contentId}',
    );
    final content = LearningContent.fromJson(contentJson);

    expect(mission.outcome, CurrentMissionOutcome.available);
    expect(mission.pathId, 101);
    expect(task.taskId, 1001);
    expect(content.id, task.contentId);
    expect(content.slug, task.contentSlug);
  });
}
