// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_timeseries.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DailyActivity _$DailyActivityFromJson(Map<String, dynamic> json) =>
    _DailyActivity(
      date: json['date'] as String,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$DailyActivityToJson(_DailyActivity instance) =>
    <String, dynamic>{
      'date': instance.date,
      'completedCount': instance.completedCount,
    };

_ProgressPoint _$ProgressPointFromJson(Map<String, dynamic> json) =>
    _ProgressPoint(
      date: json['date'] as String,
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      byType:
          (json['byType'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
    );

Map<String, dynamic> _$ProgressPointToJson(_ProgressPoint instance) =>
    <String, dynamic>{
      'date': instance.date,
      'percent': instance.percent,
      'byType': instance.byType,
    };
