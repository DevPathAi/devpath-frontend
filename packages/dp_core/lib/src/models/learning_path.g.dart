// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_path.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LearningPath _$LearningPathFromJson(Map<String, dynamic> json) =>
    _LearningPath(
      pathId: (json['pathId'] as num).toInt(),
      track: json['track'] as String,
      totalWeeks: (json['totalWeeks'] as num).toInt(),
      rationale: json['rationale'] as String,
      diagnosis: json['diagnosis'] == null
          ? null
          : PathDiagnosis.fromJson(json['diagnosis'] as Map<String, dynamic>),
      milestones:
          (json['milestones'] as List<dynamic>?)
              ?.map((e) => PathMilestone.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PathMilestone>[],
    );

Map<String, dynamic> _$LearningPathToJson(_LearningPath instance) =>
    <String, dynamic>{
      'pathId': instance.pathId,
      'track': instance.track,
      'totalWeeks': instance.totalWeeks,
      'rationale': instance.rationale,
      'diagnosis': instance.diagnosis?.toJson(),
      'milestones': instance.milestones.map((e) => e.toJson()).toList(),
    };

_PathDiagnosis _$PathDiagnosisFromJson(Map<String, dynamic> json) =>
    _PathDiagnosis(
      diagnosedLevel: json['diagnosedLevel'] as String,
      strengthConcepts:
          (json['strengthConcepts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      weaknessConcepts:
          (json['weaknessConcepts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$PathDiagnosisToJson(_PathDiagnosis instance) =>
    <String, dynamic>{
      'diagnosedLevel': instance.diagnosedLevel,
      'strengthConcepts': instance.strengthConcepts,
      'weaknessConcepts': instance.weaknessConcepts,
    };

_PathMilestone _$PathMilestoneFromJson(Map<String, dynamic> json) =>
    _PathMilestone(
      weekNum: (json['weekNum'] as num).toInt(),
      title: json['title'] as String,
      goalDescription: json['goalDescription'] as String,
      targetSkills:
          (json['targetSkills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      estimatedHours: (json['estimatedHours'] as num).toInt(),
      whyThisOrder: json['whyThisOrder'] as String,
      expectedOutcome: json['expectedOutcome'] as String,
      locked: json['locked'] as bool? ?? false,
      tasks:
          (json['tasks'] as List<dynamic>?)
              ?.map((e) => WeeklyTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <WeeklyTask>[],
    );

Map<String, dynamic> _$PathMilestoneToJson(_PathMilestone instance) =>
    <String, dynamic>{
      'weekNum': instance.weekNum,
      'title': instance.title,
      'goalDescription': instance.goalDescription,
      'targetSkills': instance.targetSkills,
      'estimatedHours': instance.estimatedHours,
      'whyThisOrder': instance.whyThisOrder,
      'expectedOutcome': instance.expectedOutcome,
      'locked': instance.locked,
      'tasks': instance.tasks.map((e) => e.toJson()).toList(),
    };

_WeeklyTask _$WeeklyTaskFromJson(Map<String, dynamic> json) => _WeeklyTask(
  orderNum: (json['orderNum'] as num).toInt(),
  taskType: json['taskType'] as String,
  title: json['title'] as String,
  required: json['required'] as bool? ?? false,
  contentId: (json['contentId'] as num?)?.toInt(),
  contentSlug: json['contentSlug'] as String?,
  completed: json['completed'] as bool? ?? false,
);

Map<String, dynamic> _$WeeklyTaskToJson(_WeeklyTask instance) =>
    <String, dynamic>{
      'orderNum': instance.orderNum,
      'taskType': instance.taskType,
      'title': instance.title,
      'required': instance.required,
      'contentId': instance.contentId,
      'contentSlug': instance.contentSlug,
      'completed': instance.completed,
    };
