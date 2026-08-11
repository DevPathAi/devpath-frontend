// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DashboardSummary _$DashboardSummaryFromJson(
  Map<String, dynamic> json,
) => _DashboardSummary(
  streakDays: (json['streakDays'] as num).toInt(),
  progressPercent: (json['progressPercent'] as num).toInt(),
  nextTaskTitle: json['nextTaskTitle'] as String?,
  badges:
      (json['badges'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  completedContentCount: (json['completedContentCount'] as num?)?.toInt() ?? 0,
  weeklyActivity:
      (json['weeklyActivity'] as List<dynamic>?)
          ?.map((e) => DailyActivity.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <DailyActivity>[],
  progressHistory:
      (json['progressHistory'] as List<dynamic>?)
          ?.map((e) => ProgressPoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ProgressPoint>[],
);

Map<String, dynamic> _$DashboardSummaryToJson(
  _DashboardSummary instance,
) => <String, dynamic>{
  'streakDays': instance.streakDays,
  'progressPercent': instance.progressPercent,
  'nextTaskTitle': instance.nextTaskTitle,
  'badges': instance.badges,
  'completedContentCount': instance.completedContentCount,
  'weeklyActivity': instance.weeklyActivity.map((e) => e.toJson()).toList(),
  'progressHistory': instance.progressHistory.map((e) => e.toJson()).toList(),
};
