// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assessment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AssessmentQuestion _$AssessmentQuestionFromJson(Map<String, dynamic> json) =>
    _AssessmentQuestion(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String,
      content: json['content'] as String,
      options: json['options'] as String?,
      bloomLevel: json['bloomLevel'] as String,
      difficulty: (json['difficulty'] as num).toDouble(),
    );

Map<String, dynamic> _$AssessmentQuestionToJson(_AssessmentQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'content': instance.content,
      'options': instance.options,
      'bloomLevel': instance.bloomLevel,
      'difficulty': instance.difficulty,
    };

_NextQuestion _$NextQuestionFromJson(Map<String, dynamic> json) =>
    _NextQuestion(
      question: AssessmentQuestion.fromJson(
        json['question'] as Map<String, dynamic>,
      ),
      index: (json['index'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$NextQuestionToJson(_NextQuestion instance) =>
    <String, dynamic>{
      'question': instance.question.toJson(),
      'index': instance.index,
      'total': instance.total,
    };

_AssessmentResult _$AssessmentResultFromJson(Map<String, dynamic> json) =>
    _AssessmentResult(
      diagnosedLevel: json['diagnosedLevel'] as String,
      confidenceWeight: (json['confidenceWeight'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$AssessmentResultToJson(_AssessmentResult instance) =>
    <String, dynamic>{
      'diagnosedLevel': instance.diagnosedLevel,
      'confidenceWeight': instance.confidenceWeight,
    };
