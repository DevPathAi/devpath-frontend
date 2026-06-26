// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lcs_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LcsFieldUnavailable _$LcsFieldUnavailableFromJson(Map<String, dynamic> json) =>
    _LcsFieldUnavailable(
      field: json['field'] as String,
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$LcsFieldUnavailableToJson(
  _LcsFieldUnavailable instance,
) => <String, dynamic>{'field': instance.field, 'reason': instance.reason};

_LcsDraft _$LcsDraftFromJson(Map<String, dynamic> json) => _LcsDraft(
  draftId: json['draftId'] as String,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  content:
      json['content'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  fieldsAvailable:
      (json['fieldsAvailable'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  fieldsUnavailable:
      (json['fieldsUnavailable'] as List<dynamic>?)
          ?.map((e) => LcsFieldUnavailable.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <LcsFieldUnavailable>[],
);

Map<String, dynamic> _$LcsDraftToJson(_LcsDraft instance) => <String, dynamic>{
  'draftId': instance.draftId,
  'expiresAt': instance.expiresAt.toIso8601String(),
  'content': instance.content,
  'fieldsAvailable': instance.fieldsAvailable,
  'fieldsUnavailable': instance.fieldsUnavailable
      .map((e) => e.toJson())
      .toList(),
};

_LcsSnapshotView _$LcsSnapshotViewFromJson(Map<String, dynamic> json) =>
    _LcsSnapshotView(
      id: (json['id'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      content:
          json['content'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      renderedFor: json['renderedFor'] as String? ?? 'answerer',
    );

Map<String, dynamic> _$LcsSnapshotViewToJson(_LcsSnapshotView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'content': instance.content,
      'renderedFor': instance.renderedFor,
    };
