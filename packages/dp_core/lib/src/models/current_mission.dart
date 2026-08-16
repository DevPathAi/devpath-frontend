import 'dart:collection';

import 'learning_path.dart';

const _currentMissionTaskTypes = <String>{'READ', 'PRACTICE', 'QUIZ'};
const _maxJsSafeInteger = 9007199254740991;
final _rfc3339Instant = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
  r'(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})$',
);

/// 서버가 판정한 현재 미션 조회 결과.
enum CurrentMissionOutcome {
  available,
  pathCompleted,
  noActivePath,
  malformedPath,
}

/// `GET /learning-paths/me/this-week` 응답을 일관된 상태로 정규화한 모델.
///
/// 구형 또는 혼합 배포 응답을 클라이언트가 제목·순서로 추론하지 않는다. 새 계약을
/// 완전히 만족하지 않는 응답은 [CurrentMissionOutcome.malformedPath]로 축소한다.
final class CurrentMission {
  CurrentMission._({
    required this.outcome,
    required this.pathId,
    required this.weekNum,
    required List<WeeklyTask> tasks,
    required this.nextTask,
    required this.pathCompleted,
  }) : tasks = UnmodifiableListView<WeeklyTask>(tasks);

  final CurrentMissionOutcome outcome;
  final int? pathId;
  final int? weekNum;
  final List<WeeklyTask> tasks;
  final WeeklyTask? nextTask;
  final bool pathCompleted;

  /// JSON shape와 결과별 불변식을 함께 검증한다.
  factory CurrentMission.fromJson(Object? json) {
    try {
      if (json is! Map) return CurrentMission._malformed();
      final data = json.cast<String, Object?>();
      return switch (data['outcome']) {
        'AVAILABLE' => CurrentMission._available(data),
        'PATH_COMPLETED' => CurrentMission._pathCompleted(data),
        'NO_ACTIVE_PATH' => CurrentMission._noActivePath(data),
        'MALFORMED_PATH' => CurrentMission._malformed(),
        _ => CurrentMission._malformed(),
      };
    } on Object {
      return CurrentMission._malformed();
    }
  }

  factory CurrentMission._available(Map<String, Object?> data) {
    final pathId = _positiveInt(data['pathId']);
    final weekNum = _positiveInt(data['weekNum']);
    final tasks = _tasks(data['tasks']);
    final nextTask = _task(data['nextTask']);

    if (pathId == null ||
        weekNum == null ||
        tasks == null ||
        nextTask == null ||
        data['pathCompleted'] != false ||
        nextTask.completed) {
      return CurrentMission._malformed();
    }

    final matchingTasks = tasks.where((task) => task.taskId == nextTask.taskId);
    if (matchingTasks.length != 1 ||
        matchingTasks.single.completed ||
        matchingTasks.single != nextTask ||
        tasks.firstWhere((task) => !task.completed) != nextTask) {
      return CurrentMission._malformed();
    }

    return CurrentMission._(
      outcome: CurrentMissionOutcome.available,
      pathId: pathId,
      weekNum: weekNum,
      tasks: tasks,
      nextTask: nextTask,
      pathCompleted: false,
    );
  }

  factory CurrentMission._pathCompleted(Map<String, Object?> data) {
    final pathId = _positiveInt(data['pathId']);
    final weekNum = _positiveInt(data['weekNum']);
    final tasks = _tasks(data['tasks']);

    if (pathId == null ||
        weekNum == null ||
        tasks == null ||
        tasks.isEmpty ||
        data['nextTask'] != null ||
        data['pathCompleted'] != true ||
        tasks.any((task) => !task.completed)) {
      return CurrentMission._malformed();
    }

    return CurrentMission._(
      outcome: CurrentMissionOutcome.pathCompleted,
      pathId: pathId,
      weekNum: weekNum,
      tasks: tasks,
      nextTask: null,
      pathCompleted: true,
    );
  }

  factory CurrentMission._noActivePath(Map<String, Object?> data) {
    final tasks = _tasks(data['tasks']);
    if (data['pathId'] != null ||
        data['weekNum'] != null ||
        tasks == null ||
        tasks.isNotEmpty ||
        data['nextTask'] != null ||
        data['pathCompleted'] != false) {
      return CurrentMission._malformed();
    }

    return CurrentMission._(
      outcome: CurrentMissionOutcome.noActivePath,
      pathId: null,
      weekNum: null,
      tasks: const <WeeklyTask>[],
      nextTask: null,
      pathCompleted: false,
    );
  }

  factory CurrentMission._malformed() => CurrentMission._(
    outcome: CurrentMissionOutcome.malformedPath,
    pathId: null,
    weekNum: null,
    tasks: const <WeeklyTask>[],
    nextTask: null,
    pathCompleted: false,
  );

  static List<WeeklyTask>? _tasks(Object? value) {
    if (value is! List) return null;
    final parsed = <WeeklyTask>[];
    final ids = <int>{};
    var previousOrder = 0;
    for (final value in value) {
      final task = _task(value);
      if (task == null ||
          !ids.add(task.taskId!) ||
          task.orderNum <= previousOrder) {
        return null;
      }
      parsed.add(task);
      previousOrder = task.orderNum;
    }
    return parsed;
  }

  static WeeklyTask? _task(Object? value) {
    if (value is! Map) return null;

    Map<String, Object?> data;
    try {
      data = value.cast<String, Object?>();
    } on Object {
      return null;
    }

    final taskId = _positiveInt(data['taskId']);
    final orderNum = _positiveInt(data['orderNum']);
    final taskType = data['taskType'];
    final title = data['title'];
    final required = data['required'];
    final completed = data['completed'];
    final contentSlug = data['contentSlug'];
    final rawContentId = data['contentId'];
    final rawCompletedAt = data['completedAt'];

    if (taskId == null ||
        orderNum == null ||
        taskType is! String ||
        !_currentMissionTaskTypes.contains(taskType) ||
        title is! String ||
        required is! bool ||
        completed is! bool ||
        (contentSlug != null && contentSlug is! String)) {
      return null;
    }

    int? contentId;
    if (rawContentId != null) {
      contentId = _positiveInt(rawContentId);
      if (contentId == null) return null;
    }
    if ((contentId == null) != (contentSlug == null)) return null;

    DateTime? completedAt;
    if (rawCompletedAt != null) {
      if (rawCompletedAt is! String) return null;
      completedAt = _parseRfc3339Instant(rawCompletedAt);
      if (completedAt == null) return null;
    }
    if (completed != (completedAt != null)) return null;

    return WeeklyTask(
      taskId: taskId,
      orderNum: orderNum,
      taskType: taskType,
      title: title,
      required: required,
      contentId: contentId,
      contentSlug: contentSlug as String?,
      completed: completed,
      completedAt: completedAt,
    );
  }

  static int? _positiveInt(Object? value) =>
      value is int && value > 0 && value <= _maxJsSafeInteger ? value : null;

  static DateTime? _parseRfc3339Instant(String value) {
    final match = _rfc3339Instant.firstMatch(value);
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final zone = match.group(8)!;
    if (month > 12 || hour > 23 || minute > 59 || second > 59) return null;
    if (zone != 'Z') {
      final zoneHour = int.parse(zone.substring(1, 3));
      final zoneMinute = int.parse(zone.substring(4, 6));
      if (zoneHour > 23 || zoneMinute > 59) return null;
    }

    final calendar = DateTime.utc(year, month, day, hour, minute, second);
    if (calendar.year != year ||
        calendar.month != month ||
        calendar.day != day ||
        calendar.hour != hour ||
        calendar.minute != minute ||
        calendar.second != second) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
