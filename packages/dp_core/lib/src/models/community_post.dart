import 'package:freezed_annotation/freezed_annotation.dart';

part 'community_post.freezed.dart';
part 'community_post.g.dart';

/// Q&A 목록 항목(`GET /community/posts` → `PostSummaryView`).
///
/// 백엔드는 작성자 **이름**을 주지 않는다([authorId] 논리참조만, 교차서비스 FK 없음).
@freezed
abstract class CommunityPostSummary with _$CommunityPostSummary {
  const factory CommunityPostSummary({
    required int id,
    required String title,
    int? authorId,
    @Default(false) bool solved,
    @Default(0) int upvoteCount,
    @Default(0) int answerCount,
  }) = _CommunityPostSummary;

  factory CommunityPostSummary.fromJson(Map<String, dynamic> json) =>
      _$CommunityPostSummaryFromJson(json);
}

/// 답변(`AnswerView`). 인간 답변은 [authorId] 있음, **AI 시드 답변은 [authorId]=null +
/// [aiGenerated]=true**(→ "🤖 AI 초안" 뱃지).
@freezed
abstract class CommunityAnswer with _$CommunityAnswer {
  const factory CommunityAnswer({
    required int id,
    int? authorId,
    required String bodyMd,
    @Default(false) bool aiGenerated,
    @Default(false) bool accepted,
    @Default(0) int upvoteCount,
  }) = _CommunityAnswer;

  factory CommunityAnswer.fromJson(Map<String, dynamic> json) =>
      _$CommunityAnswerFromJson(json);
}

/// Q&A 상세(`GET /community/questions/{id}` → `QuestionDetailView`).
/// 질문 + 답변 스레드(인간/AI). 질문 작성자 식별자는 상세 응답에 **없다**(채택 OWNER
/// 게이팅은 백엔드가 강제, 프론트는 미해결 상태에서 버튼 노출 + 403 우아 처리).
@freezed
abstract class CommunityQuestionDetail with _$CommunityQuestionDetail {
  const factory CommunityQuestionDetail({
    required int id,
    required String title,
    required String bodyMd,
    @Default(false) bool solved,
    int? acceptedAnswerId,
    @Default(0) int upvoteCount,
    @Default(0) int downvoteCount,
    @Default(<String>[]) List<String> tags,
    @Default(<CommunityAnswer>[]) List<CommunityAnswer> answers,
  }) = _CommunityQuestionDetail;

  factory CommunityQuestionDetail.fromJson(Map<String, dynamic> json) =>
      _$CommunityQuestionDetailFromJson(json);
}

/// 유사질문(`GET /community/questions/similar?q=` → `SimilarQuestionView`).
/// 중복 방지용. 임베딩 불가 시 백엔드가 빈 목록 반환(무에러).
@freezed
abstract class SimilarQuestion with _$SimilarQuestion {
  const factory SimilarQuestion({
    required int questionId,
    required String title,
  }) = _SimilarQuestion;

  factory SimilarQuestion.fromJson(Map<String, dynamic> json) =>
      _$SimilarQuestionFromJson(json);
}

/// 태그 자동완성 항목(`GET /community/tags?q=` → `TagView`).
@freezed
abstract class CommunityTag with _$CommunityTag {
  const factory CommunityTag({
    required int id,
    required String name,
    @Default(0) int postCount,
  }) = _CommunityTag;

  factory CommunityTag.fromJson(Map<String, dynamic> json) =>
      _$CommunityTagFromJson(json);
}
