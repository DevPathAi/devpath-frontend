// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_path.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LearningPath _$LearningPathFromJson(Map<String, dynamic> json) =>
    _LearningPath(
      rationale: json['rationale'] as String,
      weeks:
          (json['weeks'] as List<dynamic>?)
              ?.map((e) => PathWeek.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PathWeek>[],
    );

Map<String, dynamic> _$LearningPathToJson(_LearningPath instance) =>
    <String, dynamic>{
      'rationale': instance.rationale,
      'weeks': instance.weeks.map((e) => e.toJson()).toList(),
    };

_PathWeek _$PathWeekFromJson(Map<String, dynamic> json) => _PathWeek(
  week: (json['week'] as num).toInt(),
  title: json['title'] as String,
  tasks:
      (json['tasks'] as List<dynamic>?)
          ?.map((e) => WeeklyTask.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <WeeklyTask>[],
);

Map<String, dynamic> _$PathWeekToJson(_PathWeek instance) => <String, dynamic>{
  'week': instance.week,
  'title': instance.title,
  'tasks': instance.tasks.map((e) => e.toJson()).toList(),
};

_WeeklyTask _$WeeklyTaskFromJson(Map<String, dynamic> json) => _WeeklyTask(
  title: json['title'] as String,
  done: json['done'] as bool? ?? false,
);

Map<String, dynamic> _$WeeklyTaskToJson(_WeeklyTask instance) =>
    <String, dynamic>{'title': instance.title, 'done': instance.done};
