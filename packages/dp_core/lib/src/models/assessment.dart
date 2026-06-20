import 'package:freezed_annotation/freezed_annotation.dart';

part 'assessment.freezed.dart';
part 'assessment.g.dart';

/// 진단 문항 뷰(정답 키 미포함).
@freezed
abstract class AssessmentQuestion with _$AssessmentQuestion {
  const factory AssessmentQuestion({
    required int id,
    required String type,
    required String content,
    String? options,
    required String bloomLevel,
    required double difficulty,
  }) = _AssessmentQuestion;

  factory AssessmentQuestion.fromJson(Map<String, dynamic> json) =>
      _$AssessmentQuestionFromJson(json);
}

/// 적응형 다음 문항 + 진행률.
@freezed
abstract class NextQuestion with _$NextQuestion {
  const factory NextQuestion({
    required AssessmentQuestion question,
    required int index,
    required int total,
  }) = _NextQuestion;

  factory NextQuestion.fromJson(Map<String, dynamic> json) =>
      _$NextQuestionFromJson(json);
}

/// 진단 결과(강·약점은 후속 확장).
@freezed
abstract class AssessmentResult with _$AssessmentResult {
  const factory AssessmentResult({
    required String diagnosedLevel,
    double? confidenceWeight,
  }) = _AssessmentResult;

  factory AssessmentResult.fromJson(Map<String, dynamic> json) =>
      _$AssessmentResultFromJson(json);
}
