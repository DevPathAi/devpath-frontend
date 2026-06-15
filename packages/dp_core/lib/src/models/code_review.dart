import 'package:freezed_annotation/freezed_annotation.dart';

part 'code_review.freezed.dart';
part 'code_review.g.dart';

/// AI 코드리뷰 결과(REV-001).
@freezed
abstract class CodeReview with _$CodeReview {
  const factory CodeReview({
    required int confidence, // 0~100
    @Default(<String>[]) List<String> strengths,
    @Default(<ReviewIssue>[]) List<ReviewIssue> improvements,
    @Default(<ReviewIssue>[]) List<ReviewIssue> security,
    String? id, // F6-e: 후속 폴링(GET /reviews/:id) 자리 선확보. 동기 프로토에선 미사용.
    String? status, // F6-e: 'pending'|'done' 등 — 폴링 전환 시 사용.
  }) = _CodeReview;

  factory CodeReview.fromJson(Map<String, dynamic> json) =>
      _$CodeReviewFromJson(json);
}

/// 라인·심각도 동반 지적. severity: info | warning | error.
@freezed
abstract class ReviewIssue with _$ReviewIssue {
  const factory ReviewIssue({
    required String message,
    int? line,
    @Default('info') String severity,
  }) = _ReviewIssue;

  factory ReviewIssue.fromJson(Map<String, dynamic> json) =>
      _$ReviewIssueFromJson(json);
}
