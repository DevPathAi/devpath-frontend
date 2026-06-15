// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DashboardSummary _$DashboardSummaryFromJson(Map<String, dynamic> json) =>
    _DashboardSummary(
      streakDays: (json['streakDays'] as num).toInt(),
      progressPercent: (json['progressPercent'] as num).toInt(),
      nextTaskTitle: json['nextTaskTitle'] as String?,
      badges:
          (json['badges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$DashboardSummaryToJson(_DashboardSummary instance) =>
    <String, dynamic>{
      'streakDays': instance.streakDays,
      'progressPercent': instance.progressPercent,
      'nextTaskTitle': instance.nextTaskTitle,
      'badges': instance.badges,
    };
