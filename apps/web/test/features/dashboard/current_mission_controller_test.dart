import 'dart:async';

import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CurrentMission _availableMission({
  required int taskId,
  required String title,
  int? contentId = 21,
}) {
  final nextTask = <String, Object?>{
    'taskId': taskId,
    'orderNum': 2,
    'taskType': contentId == null ? 'PRACTICE' : 'READ',
    'title': title,
    'required': true,
    'contentId': contentId,
    'contentSlug': contentId == null ? null : 'mission-$taskId',
    'completed': false,
    'completedAt': null,
  };
  return CurrentMission.fromJson({
    'outcome': 'AVAILABLE',
    'pathId': 101,
    'weekNum': 3,
    'tasks': [
      {
        'taskId': taskId - 1,
        'orderNum': 1,
        'taskType': 'READ',
        'title': '완료한 미션',
        'required': true,
        'contentId': 20,
        'contentSlug': 'completed-mission',
        'completed': true,
        'completedAt': '2026-08-15T01:00:00.000Z',
      },
      nextTask,
    ],
    'nextTask': nextTask,
    'pathCompleted': false,
  });
}

final class _QueuedLearningPathApi extends LearningPathApi {
  _QueuedLearningPathApi() : super(ApiClient(Dio()));

  final missionRequests = <Completer<CurrentMission>>[];
  final completionRequests = <int, Completer<void>>{};
  var currentMissionCalls = 0;
  var completionCalls = 0;

  @override
  Future<CurrentMission> currentMission() {
    currentMissionCalls += 1;
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
  _QueuedLearningPathApi api,
  DateTime Function() clock,
) {
  final container = ProviderContainer(
    overrides: [
      learningPathApiProvider.overrideWithValue(api),
      currentMissionClockProvider.overrideWithValue(clock),
      currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _OwnerKeyController extends Notifier<String?> {
  @override
  String? build() => 'user-a';

  void changeTo(String? owner) => state = owner;
}

final _ownerKeyProvider = NotifierProvider<_OwnerKeyController, String?>(
  _OwnerKeyController.new,
);

void main() {
  group('CurrentMissionController cache', () {
    test(
      'authenticated owner가 바뀌면 retained data와 pending mutation을 폐기한다',
      () async {
        final api = _QueuedLearningPathApi();
        final container = ProviderContainer(
          overrides: [
            learningPathApiProvider.overrideWithValue(api),
            currentMissionOwnerKeyProvider.overrideWith(
              (ref) => ref.watch(_ownerKeyProvider),
            ),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          currentMissionControllerProvider.notifier,
        );

        final load = controller.load();
        api.missionRequests[0].complete(
          _availableMission(taskId: 32, title: '사용자 A 미션', contentId: null),
        );
        await load;
        final oldCompletion = controller.completeContentlessTask(32);

        container.read(_ownerKeyProvider.notifier).changeTo('user-b');

        final resetState = container.read(currentMissionControllerProvider);
        expect(resetState.mission, isNull);
        expect(resetState.completingTaskId, isNull);
        expect(resetState.isLoading, isTrue);

        final newController = container.read(
          currentMissionControllerProvider.notifier,
        );
        final newLoad = newController.load();
        api.missionRequests[1].complete(
          _availableMission(taskId: 42, title: '사용자 B 미션', contentId: null),
        );
        await newLoad;
        final newCompletion = newController.completeContentlessTask(42);

        api.completionRequests[32]!.complete();
        await oldCompletion;
        expect(
          container.read(currentMissionControllerProvider).completingTaskId,
          42,
        );
        expect(
          container
              .read(currentMissionControllerProvider)
              .mission
              ?.nextTask
              ?.taskId,
          42,
        );

        api.completionRequests[42]!.complete();
        await Future<void>.delayed(Duration.zero);
        api.missionRequests[2].complete(
          _availableMission(taskId: 43, title: '사용자 B 다음 미션'),
        );
        await newCompletion;
        expect(
          container
              .read(currentMissionControllerProvider)
              .mission
              ?.nextTask
              ?.taskId,
          43,
        );
      },
    );

    test('동시 소비자는 하나의 in-flight 요청을 공유한다', () async {
      final api = _QueuedLearningPathApi();
      final container = _container(api, DateTime.now);
      final controller = container.read(
        currentMissionControllerProvider.notifier,
      );

      final first = controller.load();
      final second = controller.load();

      expect(api.currentMissionCalls, 1);
      api.missionRequests.single.complete(
        _availableMission(taskId: 42, title: '트랜잭션 경계 읽기'),
      );
      await Future.wait([first, second]);

      expect(
        container
            .read(currentMissionControllerProvider)
            .mission
            ?.nextTask
            ?.taskId,
        42,
      );
    });

    test('30초 미만은 fresh이고 정확히 30초부터 다시 조회한다', () async {
      var now = DateTime.utc(2026, 8, 15, 2);
      final api = _QueuedLearningPathApi();
      final container = _container(api, () => now);
      final controller = container.read(
        currentMissionControllerProvider.notifier,
      );

      final first = controller.load();
      api.missionRequests[0].complete(
        _availableMission(taskId: 42, title: '첫 미션'),
      );
      await first;

      now = now.add(
        const Duration(seconds: 30) - const Duration(microseconds: 1),
      );
      await controller.load();
      expect(api.currentMissionCalls, 1);

      now = now.add(const Duration(microseconds: 1));
      final boundary = controller.load();
      expect(api.currentMissionCalls, 2);
      api.missionRequests[1].complete(
        _availableMission(taskId: 43, title: '경계 뒤 미션'),
      );
      await boundary;

      expect(
        container
            .read(currentMissionControllerProvider)
            .mission
            ?.nextTask
            ?.taskId,
        43,
      );
    });

    test('invalidate 후 새 세대가 도착하면 이전 늦은 응답을 무시한다', () async {
      final api = _QueuedLearningPathApi();
      final container = _container(api, DateTime.now);
      final controller = container.read(
        currentMissionControllerProvider.notifier,
      );

      final oldRequest = controller.load();
      final newRequest = controller.invalidateAndRefetch();
      expect(api.currentMissionCalls, 2);

      api.missionRequests[1].complete(
        _availableMission(taskId: 52, title: '새 세대 미션'),
      );
      await newRequest;
      api.missionRequests[0].complete(
        _availableMission(taskId: 51, title: '늦게 온 이전 미션'),
      );
      final ignored = await oldRequest;

      final state = container.read(currentMissionControllerProvider);
      expect(ignored, isNull);
      expect(state.mission?.nextTask?.taskId, 52);
      expect(state.generation, 1);
    });

    test('유효 데이터 뒤 refresh 실패는 마지막 미션을 stale로 보존한다', () async {
      final api = _QueuedLearningPathApi();
      final container = _container(api, DateTime.now);
      final controller = container.read(
        currentMissionControllerProvider.notifier,
      );

      final first = controller.load();
      api.missionRequests[0].complete(
        _availableMission(taskId: 61, title: '보존할 미션'),
      );
      await first;

      final refresh = controller.invalidateAndRefetch();
      api.missionRequests[1].completeError(StateError('network down'));
      await refresh;

      final state = container.read(currentMissionControllerProvider);
      expect(state.mission?.nextTask?.taskId, 61);
      expect(state.isStale, isTrue);
      expect(state.failureKind, CurrentMissionFailureKind.refresh);
      expect(state.failureMessage, isNotEmpty);
    });
  });

  group('CurrentMissionController contentless completion', () {
    test('pending 중 같은 task 완료를 한 번만 보내고 성공 뒤 즉시 refetch한다', () async {
      final api = _QueuedLearningPathApi();
      final container = _container(api, DateTime.now);
      final controller = container.read(
        currentMissionControllerProvider.notifier,
      );

      final load = controller.load();
      api.missionRequests[0].complete(
        _availableMission(taskId: 72, title: '기록 미션', contentId: null),
      );
      await load;

      final first = controller.completeContentlessTask(72);
      final replay = controller.completeContentlessTask(72);
      expect(api.completionCalls, 1);
      expect(
        container.read(currentMissionControllerProvider).completingTaskId,
        72,
      );

      api.completionRequests[72]!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(api.currentMissionCalls, 2);
      api.missionRequests[1].complete(
        _availableMission(taskId: 73, title: '다음 미션'),
      );
      await Future.wait([first, replay]);

      final state = container.read(currentMissionControllerProvider);
      expect(state.mission?.nextTask?.taskId, 73);
      expect(state.completingTaskId, isNull);
      expect(state.isStale, isFalse);
    });

    test('완료 실패는 읽을 수 있는 미션과 incomplete 상태를 보존한다', () async {
      final api = _QueuedLearningPathApi();
      final container = _container(api, DateTime.now);
      final controller = container.read(
        currentMissionControllerProvider.notifier,
      );

      final load = controller.load();
      api.missionRequests[0].complete(
        _availableMission(taskId: 82, title: '실패 보존', contentId: null),
      );
      await load;

      final completion = controller.completeContentlessTask(82);
      api.completionRequests[82]!.completeError(StateError('write failed'));
      await completion;

      final state = container.read(currentMissionControllerProvider);
      expect(state.mission?.nextTask?.taskId, 82);
      expect(state.mission?.nextTask?.completed, isFalse);
      expect(state.completingTaskId, isNull);
      expect(state.failureKind, CurrentMissionFailureKind.completion);
    });

    test('content가 연결된 task는 명시적 완료 endpoint를 호출하지 않는다', () async {
      final api = _QueuedLearningPathApi();
      final container = _container(api, DateTime.now);
      final controller = container.read(
        currentMissionControllerProvider.notifier,
      );

      final load = controller.load();
      api.missionRequests[0].complete(
        _availableMission(taskId: 92, title: '콘텐츠 미션'),
      );
      await load;

      await expectLater(
        controller.completeContentlessTask(92),
        throwsStateError,
      );
      expect(api.completionCalls, 0);
    });

    for (final lateCompletionFails in [false, true]) {
      test(
        'invalidate는 이전 완료 ${lateCompletionFails ? '실패' : '성공'}를 분리해 새 task를 막지 않는다',
        () async {
          final api = _QueuedLearningPathApi();
          final container = _container(api, DateTime.now);
          final controller = container.read(
            currentMissionControllerProvider.notifier,
          );

          final initialLoad = controller.load();
          api.missionRequests[0].complete(
            _availableMission(taskId: 102, title: '이전 계정 미션', contentId: null),
          );
          await initialLoad;
          final oldCompletion = controller.completeContentlessTask(102);

          final newLoad = controller.invalidateAndRefetch();
          expect(
            container.read(currentMissionControllerProvider).completingTaskId,
            isNull,
          );
          api.missionRequests[1].complete(
            _availableMission(taskId: 202, title: '새 계정 미션', contentId: null),
          );
          await newLoad;

          final newCompletion = controller.completeContentlessTask(202);
          expect(api.completionCalls, 2);
          expect(
            container.read(currentMissionControllerProvider).completingTaskId,
            202,
          );

          if (lateCompletionFails) {
            api.completionRequests[102]!.completeError(
              StateError('late failure'),
            );
          } else {
            api.completionRequests[102]!.complete();
          }
          await oldCompletion;
          expect(
            container.read(currentMissionControllerProvider).completingTaskId,
            202,
          );
          expect(
            container.read(currentMissionControllerProvider).failureKind,
            isNull,
          );

          api.completionRequests[202]!.complete();
          await Future<void>.delayed(Duration.zero);
          api.missionRequests[2].complete(
            _availableMission(taskId: 203, title: '완료 뒤 다음 미션'),
          );
          await newCompletion;

          expect(
            container
                .read(currentMissionControllerProvider)
                .mission
                ?.nextTask
                ?.taskId,
            203,
          );
        },
      );
    }
  });
}
