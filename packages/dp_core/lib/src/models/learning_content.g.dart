// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_content.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LearningContent _$LearningContentFromJson(Map<String, dynamic> json) =>
    _LearningContent(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      title: json['title'] as String,
      track: json['track'] as String,
      markdown: json['markdown'] as String,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      difficulty: (json['difficulty'] as num?)?.toDouble(),
      bloomLevel: json['bloomLevel'] as String?,
      conceptTags:
          (json['conceptTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      progress: ContentProgress.fromJson(
        json['progress'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$LearningContentToJson(_LearningContent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'title': instance.title,
      'track': instance.track,
      'markdown': instance.markdown,
      'estimatedMinutes': instance.estimatedMinutes,
      'difficulty': instance.difficulty,
      'bloomLevel': instance.bloomLevel,
      'conceptTags': instance.conceptTags,
      'progress': instance.progress.toJson(),
    };

_ContentProgress _$ContentProgressFromJson(Map<String, dynamic> json) =>
    _ContentProgress(
      scrollPct: (json['scrollPct'] as num).toDouble(),
      dwellSec: (json['dwellSec'] as num).toInt(),
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completedAt'] as String?,
    );

Map<String, dynamic> _$ContentProgressToJson(_ContentProgress instance) =>
    <String, dynamic>{
      'scrollPct': instance.scrollPct,
      'dwellSec': instance.dwellSec,
      'completed': instance.completed,
      'completedAt': instance.completedAt,
    };

_ContentProgressUpdateResponse _$ContentProgressUpdateResponseFromJson(
  Map<String, dynamic> json,
) => _ContentProgressUpdateResponse(
  scrollPct: (json['scrollPct'] as num).toDouble(),
  dwellSec: (json['dwellSec'] as num).toInt(),
  completed: json['completed'] as bool? ?? false,
  completedAt: json['completedAt'] as String?,
);

Map<String, dynamic> _$ContentProgressUpdateResponseToJson(
  _ContentProgressUpdateResponse instance,
) => <String, dynamic>{
  'scrollPct': instance.scrollPct,
  'dwellSec': instance.dwellSec,
  'completed': instance.completed,
  'completedAt': instance.completedAt,
};
