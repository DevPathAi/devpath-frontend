import 'dart:async';

import 'package:devpath_mobile/src/features/today/application/today_controller.dart';
import 'package:devpath_mobile/src/features/today/data/current_mission_cache.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CurrentMission _mission({required int taskId, int? contentId = 77}) {
  final task = <String, Object?>{
    'taskId': taskId,
    'orderNum': 1,
    'taskType': contentId == null ? 'PRACTICE' : 'READ',
    'title': '미션 $taskId',
    'required': true,
    'contentId': contentId,
    'contentSlug': contentId == null ? null : 'content-$contentId',
    'completed': false,
    'completedAt': null,
  };
  return CurrentMission.fromJson({
    'outcome': 'AVAILABLE',
    'pathId': 301,
    'weekNum': 4,
    'tasks': [task],
    'nextTask': task,
    'pathCompleted': false,
  });
}

final class _QueuedApi extends LearningPathApi {
  _QueuedApi() : super(ApiClient(Dio()));

  final missionRequests = <Completer<CurrentMission>>[];
  final completionRequests = <int, Completer<void>>{};
  var missionCalls = 0;
  var completionCalls = 0;

  @override
  Future<CurrentMission> currentMission() {
    missionCalls += 1;
    final request = Completer<CurrentMission>();
    missionRequests.add(request);
    return request.future;
  }

  @override
  Future<void> completeContentlessTask(int taskId) {
    completionCalls += 1;
    return (completionRequests[taskId] ??= Completer<void>()).future;
  }
}

ProviderContainer _container(
  _QueuedApi api, {
  required DateTime Function() clock,
  CurrentMissionCache? cache,
  String? owner = 'owner-a',
}) {
  final container = ProviderContainer(
    overrides: [
      learningPathApiProvider.overrideWithValue(api),
      todayClockProvider.overrideWithValue(clock),
      currentMissionCacheProvider.overrideWithValue(
        cache ?? InMemoryCurrentMissionCache(),
      ),
      todayOwnerKeyProvider.overrideWithValue(owner),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('동시 Today 소비자는 하나의 요청을 공유하고 30초 경계를 지킨다', () async {
    var now = DateTime.utc(2026, 8, 16);
    final api = _QueuedApi();
    final container = _container(api, clock: () => now);
    final controller = container.read(todayControllerProvider.notifier);

    final first = controller.load();
    final second = controller.load();
    expect(api.missionCalls, 1);
    api.missionRequests.single.complete(_mission(taskId: 1));
    await Future.wait([first, second]);

    now = now.add(
      const Duration(seconds: 30) - const Duration(microseconds: 1),
    );
    await controller.load();
    expect(api.missionCalls, 1);

    now = now.add(const Duration(microseconds: 1));
    final boundary = controller.load();
    expect(api.missionCalls, 2);
    api.missionRequests[1].complete(_mission(taskId: 2));
    await boundary;
    expect(container.read(todayControllerProvider).mission?.nextTask?.taskId, 2);
  });

  test('refresh 실패는 읽을 수 있는 데이터와 오류를 함께 보존한다', () async {
    final api = _QueuedApi();
    final container = _container(api, clock: DateTime.now);
    final controller = container.read(todayControllerProvider.notifier);

    final initial = controller.load();
    api.missionRequests[0].complete(_mission(taskId: 1));
    await initial;
    final refresh = controller.invalidateAndRefetch();
    api.missionRequests[1].completeError(StateError('offline'));
    await refresh;

    final state = container.read(todayControllerProvider);
    expect(state.mission?.nextTask?.taskId, 1);
    expect(state.isStale, isTrue);
    expect(state.failureMessage, isNotEmpty);
  });

  test('초기 네트워크 실패는 같은 owner의 24h 이내 snapshot만 복구한다', () async {
    final now = DateTime.utc(2026, 8, 16);
    final cache = InMemoryCurrentMissionCache();
    await cache.write(
      'owner-a',
      _mission(taskId: 9),
      cachedAt: now.subtract(const Duration(hours: 23)),
    );
    final api = _QueuedApi();
    final container = _container(api, clock: () => now, cache: cache);

    final load = container.read(todayControllerProvider.notifier).load();
    api.missionRequests.single.completeError(StateError('offline'));
    await load;

    final state = container.read(todayControllerProvider);
    expect(state.mission?.nextTask?.taskId, 9);
    expect(state.source, TodayMissionSource.offlineCache);
    expect(state.isStale, isTrue);
  });

  test('contentless 완료는 coalesce하고 성공 뒤 authoritative Today를 refetch한다', () async {
    final api = _QueuedApi();
    final container = _container(api, clock: DateTime.now);
    final controller = container.read(todayControllerProvider.notifier);
    final initial = controller.load();
    api.missionRequests[0].complete(_mission(taskId: 10, contentId: null));
    await initial;

    final first = controller.completeContentlessTask(10);
    final replay = controller.completeContentlessTask(10);
    expect(api.completionCalls, 1);
    api.completionRequests[10]!.complete();
    await Future<void>.delayed(Duration.zero);
    api.missionRequests[1].complete(_mission(taskId: 11));
    await Future.wait([first, replay]);

    expect(container.read(todayControllerProvider).mission?.nextTask?.taskId, 11);
  });
}
