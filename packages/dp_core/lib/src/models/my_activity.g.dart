// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_activity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MyActivity _$MyActivityFromJson(Map<String, dynamic> json) => _MyActivity(
  questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
  answerCount: (json['answerCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$MyActivityToJson(_MyActivity instance) =>
    <String, dynamic>{
      'questionCount': instance.questionCount,
      'answerCount': instance.answerCount,
    };
