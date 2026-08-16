import 'package:devpath_mobile/src/features/learning/application/content_controller.dart';
import 'package:devpath_mobile/src/features/today/application/today_controller.dart';
import 'package:devpath_mobile/src/features/today/data/current_mission_cache.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CurrentMission _mission(int taskId) {
  final task = <String, Object?>{
    'taskId': taskId,
    'orderNum': 1,
    'taskType': 'READ',
    'title': '미션 $taskId',
    'required': true,
    'contentId': taskId,
    'contentSlug': 'content-$taskId',
    'completed': false,
    'completedAt': null,
  };
  return CurrentMission.fromJson({
    'outcome': 'AVAILABLE',
    'pathId': 301,
    'weekNum': 1,
    'tasks': [task],
    'nextTask': task,
    'pathCompleted': false,
  });
}

class _MissionApi extends LearningPathApi {
  _MissionApi() : super(ApiClient(Dio()));

  var calls = 0;

  @override
  Future<CurrentMission> currentMission() async {
    calls += 1;
    return _mission(calls);
  }
}

void main() {
  test('content 완료 transition은 authoritative Today를 즉시 무효화한다', () async {
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://api.example.test'),
    );
    client.dio.httpClientAdapter = MockHttpAdapter({
      'GET /contents/1': (
        200,
        {
          'id': 1,
          'slug': 'content-1',
          'title': '콘텐츠',
          'track': 'BACKEND_SPRING',
          'markdown': '# 콘텐츠',
          'progress': {
            'scrollPct': 0.5,
            'dwellSec': 30,
            'completed': false,
            'completedAt': null,
          },
        },
      ),
      'POST /contents/1/progress': (
        200,
        {
          'scrollPct': 1.0,
          'dwellSec': 60,
          'completed': true,
          'completedAt': '2026-08-16T00:00:00Z',
        },
      ),
    });
    final missionApi = _MissionApi();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        learningPathApiProvider.overrideWithValue(missionApi),
        todayOwnerKeyProvider.overrideWithValue('owner-a'),
        currentMissionCacheProvider.overrideWithValue(
          InMemoryCurrentMissionCache(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(todayControllerProvider.notifier).load();
    await container.read(contentControllerProvider.notifier).load('1');

    await container
        .read(contentControllerProvider.notifier)
        .reportProgress('1', scrollPct: 1, dwellSec: 60);
    await pumpEventQueue();

    expect(missionApi.calls, 2);
    expect(
      container.read(todayControllerProvider).mission?.nextTask?.taskId,
      2,
    );
  });
}
