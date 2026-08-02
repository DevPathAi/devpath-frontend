// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommunityReportResult _$CommunityReportResultFromJson(
  Map<String, dynamic> json,
) => _CommunityReportResult(
  id: (json['id'] as num?)?.toInt() ?? 0,
  status: json['status'] as String? ?? 'OPEN',
);

Map<String, dynamic> _$CommunityReportResultToJson(
  _CommunityReportResult instance,
) => <String, dynamic>{'id': instance.id, 'status': instance.status};
