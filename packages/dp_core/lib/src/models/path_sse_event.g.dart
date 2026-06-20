// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'path_sse_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PathSseEvent _$PathSseEventFromJson(Map<String, dynamic> json) =>
    _PathSseEvent(
      stage: json['stage'] as String,
      progress: (json['progress'] as num).toDouble(),
      message: json['message'] as String,
      pathId: (json['pathId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PathSseEventToJson(_PathSseEvent instance) =>
    <String, dynamic>{
      'stage': instance.stage,
      'progress': instance.progress,
      'message': instance.message,
      'pathId': instance.pathId,
    };
