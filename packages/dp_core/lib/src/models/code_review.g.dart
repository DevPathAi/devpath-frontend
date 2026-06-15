// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'code_review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodeReview _$CodeReviewFromJson(Map<String, dynamic> json) => _CodeReview(
  confidence: (json['confidence'] as num).toInt(),
  strengths:
      (json['strengths'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  improvements:
      (json['improvements'] as List<dynamic>?)
          ?.map((e) => ReviewIssue.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ReviewIssue>[],
  security:
      (json['security'] as List<dynamic>?)
          ?.map((e) => ReviewIssue.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ReviewIssue>[],
  id: json['id'] as String?,
  status: json['status'] as String?,
);

Map<String, dynamic> _$CodeReviewToJson(_CodeReview instance) =>
    <String, dynamic>{
      'confidence': instance.confidence,
      'strengths': instance.strengths,
      'improvements': instance.improvements.map((e) => e.toJson()).toList(),
      'security': instance.security.map((e) => e.toJson()).toList(),
      'id': instance.id,
      'status': instance.status,
    };

_ReviewIssue _$ReviewIssueFromJson(Map<String, dynamic> json) => _ReviewIssue(
  message: json['message'] as String,
  line: (json['line'] as num?)?.toInt(),
  severity: json['severity'] as String? ?? 'info',
);

Map<String, dynamic> _$ReviewIssueToJson(_ReviewIssue instance) =>
    <String, dynamic>{
      'message': instance.message,
      'line': instance.line,
      'severity': instance.severity,
    };
