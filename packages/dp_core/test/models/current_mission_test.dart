import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

Map<String, Object?> taskJson({
  Object? taskId = 11,
  Object? completed = false,
  Object? completedAt,
  Object? contentId = 101,
}) => <String, Object?>{
  'taskId': taskId,
  'orderNum': 1,
  'taskType': 'READ',
  'title': 'HTTP 요청 흐름 읽기',
  'required': true,
  'contentId': contentId,
  'contentSlug': contentId == null ? null : 'http-flow',
  'completed': completed,
  'completedAt': completedAt,
};

Map<String, Object?> availableJson({
  Object? pathId = 7,
  Object? weekNum = 2,
  Object? tasks,
  Object? nextTask,
  Object? pathCompleted = false,
}) {
  final defaultTask = taskJson();
  return <String, Object?>{
    'outcome': 'AVAILABLE',
    'pathId': pathId,
    'weekNum': weekNum,
    'tasks': tasks ?? [defaultTask],
    'nextTask': nextTask ?? defaultTask,
    'pathCompleted': pathCompleted,
  };
}

void expectMalformed(Object? payload) {
  final mission = CurrentMission.fromJson(payload);
  expect(mission.outcome, CurrentMissionOutcome.malformedPath);
  expect(mission.pathId, isNull);
  expect(mission.weekNum, isNull);
  expect(mission.tasks, isEmpty);
  expect(mission.nextTask, isNull);
  expect(mission.pathCompleted, isFalse);
}

void main() {
  group('CurrentMission normalization', () {
    test('AVAILABLE은 stable taskId·nullable contentId·unknown field를 처리한다', () {
      final contentless = taskJson(contentId: null);
      final mission = CurrentMission.fromJson({
        ...availableJson(tasks: [contentless], nextTask: contentless),
        'futureProducerField': {'ignored': true},
      });

      expect(mission.outcome, CurrentMissionOutcome.available);
      expect(mission.pathId, 7);
      expect(mission.weekNum, 2);
      expect(mission.pathCompleted, isFalse);
      expect(mission.tasks.single.taskId, 11);
      expect(mission.tasks.single.contentId, isNull);
      expect(mission.nextTask!.taskId, 11);
      expect(mission.nextTask!.completed, isFalse);
    });

    test('completedAt은 ISO-8601 UTC와 offset을 손실 없이 파싱한다', () {
      final completed = taskJson(
        taskId: 10,
        completed: true,
        completedAt: '2026-08-15T19:20:30.123456+09:00',
      );
      final next = {...taskJson(taskId: 11), 'orderNum': 2};
      final mission = CurrentMission.fromJson(
        availableJson(tasks: [completed, next], nextTask: next),
      );

      expect(
        mission.tasks.first.completedAt,
        DateTime.utc(2026, 8, 15, 10, 20, 30, 123, 456),
      );
    });

    test('PATH_COMPLETED는 마지막 milestone과 null nextTask를 보존한다', () {
      final completed = taskJson(
        completed: true,
        completedAt: '2026-08-15T10:20:30Z',
      );
      final mission = CurrentMission.fromJson({
        'outcome': 'PATH_COMPLETED',
        'pathId': 7,
        'weekNum': 12,
        'tasks': [completed],
        'nextTask': null,
        'pathCompleted': true,
      });

      expect(mission.outcome, CurrentMissionOutcome.pathCompleted);
      expect(mission.weekNum, 12);
      expect(mission.tasks.single.completed, isTrue);
      expect(mission.nextTask, isNull);
      expect(mission.pathCompleted, isTrue);
    });

    test('NO_ACTIVE_PATH는 빈 canonical 상태로 정규화한다', () {
      final mission = CurrentMission.fromJson({
        'outcome': 'NO_ACTIVE_PATH',
        'pathId': null,
        'weekNum': null,
        'tasks': <Object?>[],
        'nextTask': null,
        'pathCompleted': false,
      });

      expect(mission.outcome, CurrentMissionOutcome.noActivePath);
      expect(mission.pathId, isNull);
      expect(mission.weekNum, isNull);
      expect(mission.tasks, isEmpty);
      expect(mission.nextTask, isNull);
      expect(mission.pathCompleted, isFalse);
    });

    test('명시적 MALFORMED_PATH는 안전한 typed fallback이다', () {
      expectMalformed({
        'outcome': 'MALFORMED_PATH',
        'pathId': null,
        'weekNum': null,
        'tasks': <Object?>[],
        'nextTask': null,
        'pathCompleted': false,
      });
    });

    test('구형 payload를 week/title 순서로 추론하지 않는다', () {
      expectMalformed({
        'pathId': 7,
        'weekNum': 1,
        'tasks': [
          {
            'orderNum': 1,
            'taskType': 'READ',
            'title': '첫 과제',
            'required': true,
            'contentId': 101,
            'contentSlug': 'first',
            'completed': false,
          },
        ],
      });
    });

    test('혼합 payload에서 taskId가 빠지면 incompatible로 처리한다', () {
      final taskWithoutId = taskJson()..remove('taskId');
      expectMalformed(
        availableJson(tasks: [taskWithoutId], nextTask: taskWithoutId),
      );
    });

    test('AVAILABLE의 nextTask는 양수 ID이며 tasks의 미완료 항목이어야 한다', () {
      expectMalformed(availableJson(nextTask: taskJson(taskId: 0)));
      expectMalformed(availableJson(nextTask: taskJson(taskId: 999)));
      expectMalformed(
        availableJson(tasks: [taskJson(completed: true)], nextTask: taskJson()),
      );
    });

    test('completed와 completedAt은 같은 서버 완료 상태를 표현해야 한다', () {
      expectMalformed(
        availableJson(
          tasks: [
            taskJson(completed: false, completedAt: '2026-08-15T10:20:30Z'),
          ],
          nextTask: taskJson(
            completed: false,
            completedAt: '2026-08-15T10:20:30Z',
          ),
        ),
      );
      expectMalformed({
        'outcome': 'PATH_COMPLETED',
        'pathId': 7,
        'weekNum': 12,
        'tasks': [taskJson(completed: true)],
        'nextTask': null,
        'pathCompleted': true,
      });
    });

    test('nextTask는 tasks의 첫 미완료 항목과 모든 알려진 필드가 같아야 한다', () {
      final first = taskJson(taskId: 11);
      final second = {...taskJson(taskId: 12), 'orderNum': 2};
      expectMalformed(
        availableJson(
          tasks: [first],
          nextTask: {...first, 'title': '서로 다른 제목'},
        ),
      );
      expectMalformed(availableJson(tasks: [first, second], nextTask: second));
    });

    test('PATH_COMPLETED는 마지막 milestone의 완료 근거를 포함해야 한다', () {
      expectMalformed({
        'outcome': 'PATH_COMPLETED',
        'pathId': 7,
        'weekNum': 12,
        'tasks': <Object?>[],
        'nextTask': null,
        'pathCompleted': true,
      });
    });

    test('contentId와 contentSlug는 함께 있거나 함께 없어야 한다', () {
      final idOnly = {...taskJson(), 'contentSlug': null};
      final slugOnly = {
        ...taskJson(contentId: null),
        'contentSlug': 'unexpected-slug',
      };
      expectMalformed(availableJson(tasks: [idOnly], nextTask: idOnly));
      expectMalformed(availableJson(tasks: [slugOnly], nextTask: slugOnly));
    });

    test('pathId·weekNum·taskId는 누락/0/음수/소수 값을 거부한다', () {
      expectMalformed(availableJson(pathId: null));
      expectMalformed(availableJson(pathId: 0));
      expectMalformed(availableJson(weekNum: -1));
      expectMalformed(availableJson(tasks: [taskJson(taskId: 1.5)]));
    });

    test(
      'link-bearing mission IDs are limited to the JS-safe positive range',
      () {
        const maxSafe = 9007199254740991;
        const overflow = 9007199254740992;
        final maxTask = taskJson(taskId: maxSafe, contentId: maxSafe);
        final accepted = CurrentMission.fromJson(
          availableJson(pathId: maxSafe, tasks: [maxTask], nextTask: maxTask),
        );
        expect(accepted.outcome, CurrentMissionOutcome.available);
        expect(accepted.pathId, maxSafe);
        expect(accepted.tasks.single.taskId, maxSafe);
        expect(accepted.tasks.single.contentId, maxSafe);

        expectMalformed(availableJson(pathId: overflow));
        final overflowTask = taskJson(taskId: overflow);
        expectMalformed(
          availableJson(tasks: [overflowTask], nextTask: overflowTask),
        );
        final overflowContent = taskJson(contentId: overflow);
        expectMalformed(
          availableJson(tasks: [overflowContent], nextTask: overflowContent),
        );
      },
    );

    test('outcome과 pathCompleted/null/목록 shape가 섞이면 malformed다', () {
      expectMalformed(availableJson(pathCompleted: true));
      expectMalformed({
        'outcome': 'NO_ACTIVE_PATH',
        'pathId': 7,
        'weekNum': null,
        'tasks': <Object?>[],
        'nextTask': null,
        'pathCompleted': false,
      });
      expectMalformed({
        'outcome': 'PATH_COMPLETED',
        'pathId': 7,
        'weekNum': 12,
        'tasks': [taskJson()],
        'nextTask': null,
        'pathCompleted': true,
      });
    });

    test(
      'unknown outcome, malformed field types, root null/list를 안전하게 거부한다',
      () {
        expectMalformed({...availableJson(), 'outcome': 'FUTURE_OUTCOME'});
        expectMalformed(availableJson(tasks: 'not-a-list'));
        expectMalformed(availableJson(tasks: [taskJson(completedAt: 1234)]));
        expectMalformed(
          availableJson(tasks: [taskJson(completedAt: 'not-a-date')]),
        );
        expectMalformed(null);
        expectMalformed(<Object?>[]);
      },
    );

    test('completedAt은 timezone이 명시된 유효한 RFC3339 instant만 허용한다', () {
      for (final timestamp in <String>[
        '2026-08-15',
        '2026-08-15T10:20:30',
        '2020-01-42T10:20:30Z',
      ]) {
        final completed = taskJson(completed: true, completedAt: timestamp);
        expectMalformed({
          'outcome': 'PATH_COMPLETED',
          'pathId': 7,
          'weekNum': 12,
          'tasks': [completed],
          'nextTask': null,
          'pathCompleted': true,
        });
      }
    });

    test('tasks는 producer의 strictly increasing orderNum을 보존해야 한다', () {
      final first = taskJson(taskId: 11);
      final duplicate = {...taskJson(taskId: 12), 'orderNum': 1};
      final reversedFirst = {...taskJson(taskId: 11), 'orderNum': 2};
      final reversedSecond = {...taskJson(taskId: 12), 'orderNum': 1};
      expectMalformed(
        availableJson(tasks: [first, duplicate], nextTask: first),
      );
      expectMalformed(
        availableJson(
          tasks: [reversedFirst, reversedSecond],
          nextTask: reversedFirst,
        ),
      );
    });

    test('taskType은 producer 계약의 READ/PRACTICE/QUIZ만 허용한다', () {
      final unknown = {...taskJson(), 'taskType': 'FUTURE_TASK'};
      expectMalformed(availableJson(tasks: [unknown], nextTask: unknown));
    });
  });
}
