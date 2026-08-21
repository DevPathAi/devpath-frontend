import 'package:freezed_annotation/freezed_annotation.dart';

part 'community_post.freezed.dart';
part 'community_post.g.dart';

/// 목록 항목(`GET /community/posts` → `PostSummaryView`, 전 보드 혼합).
///
/// 백엔드는 작성자 **이름**을 주지 않는다([authorId] 논리참조만, 교차서비스 FK 없음).
/// [boardType]으로 보드(QNA/FREE/FEEDBACK)를 구분하고, [replyCount]는 일반화된 응답 수
/// (QNA=답변 수, FREE/FEEDBACK=댓글 수). QNA만 [solved]가 의미를 가진다.
@freezed
abstract class CommunityPostSummary with _$CommunityPostSummary {
  const factory CommunityPostSummary({
    required int id,
    required String title,
    @Default('QNA') String boardType,
    int? authorId,
    @Default(false) bool solved,
    @Default(0) int upvoteCount,
    @Default(0) int replyCount,
    @Default('') String excerpt,
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
    // ★required 가 아니라 기본값이다★ — 비석 응답은 bodyMd 를 명시적 null 로 보낸다.
    // required String 이면 생성 코드가 as String 캐스트라 null 에서 죽는다.
    // @Default 는 `as String? ?? ''` 를 생성해 null 을 흡수한다.
    @Default('') String bodyMd,
    @Default(false) bool aiGenerated,
    @Default(false) bool accepted,
    @Default(0) int upvoteCount,

    /// 작성자·관리자가 지운 답변. true 면 본문과 작성자가 비어 있고 카드는 비석으로 렌더한다.
    @Default(false) bool deleted,
  }) = _CommunityAnswer;

  factory CommunityAnswer.fromJson(Map<String, dynamic> json) =>
      _$CommunityAnswerFromJson(json);
}

/// Q&A 상세(`GET /community/questions/{id}` → `QuestionDetailView`).
/// 질문 + 답변 스레드(인간/AI). 채택 OWNER 게이팅은 백엔드가 강제하고 프론트는 미해결
/// 상태에서 버튼을 노출한 뒤 403 을 우아하게 처리한다. 수정·삭제 메뉴 분기는 [authorId] 로 한다.
@freezed
abstract class CommunityQuestionDetail with _$CommunityQuestionDetail {
  const factory CommunityQuestionDetail({
    required int id,
    required String title,
    required String bodyMd,

    /// 질문 작성자. 프론트가 「내 질문인가」를 판단하는 유일한 근거다(1부 부록에서 추가됨).
    int? authorId,
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

/// 일반 게시글 상세(`GET /community/posts/{id}` → `PostDetailView`, FREE/FEEDBACK).
/// Q&A와 달리 답변/채택이 없고 **댓글**로 소통한다.
@freezed
abstract class CommunityPostDetail with _$CommunityPostDetail {
  const factory CommunityPostDetail({
    required int id,
    required String boardType,
    required String title,
    required String bodyMd,
    int? authorId,
    @Default(0) int upvoteCount,
    @Default(0) int downvoteCount,
    @Default(<String>[]) List<String> tags,
    @Default(<CommunityComment>[]) List<CommunityComment> comments,
  }) = _CommunityPostDetail;

  factory CommunityPostDetail.fromJson(Map<String, dynamic> json) =>
      _$CommunityPostDetailFromJson(json);
}

/// 일반 게시글 댓글(`CommentView`). createdAt은 ISO-8601 문자열(표시용).
@freezed
abstract class CommunityComment with _$CommunityComment {
  const factory CommunityComment({
    required int id,
    int? authorId,
    @Default('') String bodyMd,
    @Default(0) int upvoteCount,
    required String createdAt,

    /// 지워진 댓글. 본문·작성자는 비고 작성 시각만 남아 스레드 순서를 보존한다.
    @Default(false) bool deleted,
  }) = _CommunityComment;

  factory CommunityComment.fromJson(Map<String, dynamic> json) =>
      _$CommunityCommentFromJson(json);
}
