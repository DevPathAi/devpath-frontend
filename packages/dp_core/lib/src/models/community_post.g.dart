// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommunityPostSummary _$CommunityPostSummaryFromJson(
  Map<String, dynamic> json,
) => _CommunityPostSummary(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  authorId: (json['authorId'] as num?)?.toInt(),
  solved: json['solved'] as bool? ?? false,
  upvoteCount: (json['upvoteCount'] as num?)?.toInt() ?? 0,
  answerCount: (json['answerCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CommunityPostSummaryToJson(
  _CommunityPostSummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'authorId': instance.authorId,
  'solved': instance.solved,
  'upvoteCount': instance.upvoteCount,
  'answerCount': instance.answerCount,
};

_CommunityAnswer _$CommunityAnswerFromJson(Map<String, dynamic> json) =>
    _CommunityAnswer(
      id: (json['id'] as num).toInt(),
      authorId: (json['authorId'] as num?)?.toInt(),
      bodyMd: json['bodyMd'] as String,
      aiGenerated: json['aiGenerated'] as bool? ?? false,
      accepted: json['accepted'] as bool? ?? false,
      upvoteCount: (json['upvoteCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CommunityAnswerToJson(_CommunityAnswer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'authorId': instance.authorId,
      'bodyMd': instance.bodyMd,
      'aiGenerated': instance.aiGenerated,
      'accepted': instance.accepted,
      'upvoteCount': instance.upvoteCount,
    };

_CommunityQuestionDetail _$CommunityQuestionDetailFromJson(
  Map<String, dynamic> json,
) => _CommunityQuestionDetail(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  bodyMd: json['bodyMd'] as String,
  solved: json['solved'] as bool? ?? false,
  acceptedAnswerId: (json['acceptedAnswerId'] as num?)?.toInt(),
  upvoteCount: (json['upvoteCount'] as num?)?.toInt() ?? 0,
  downvoteCount: (json['downvoteCount'] as num?)?.toInt() ?? 0,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  answers:
      (json['answers'] as List<dynamic>?)
          ?.map((e) => CommunityAnswer.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CommunityAnswer>[],
);

Map<String, dynamic> _$CommunityQuestionDetailToJson(
  _CommunityQuestionDetail instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'bodyMd': instance.bodyMd,
  'solved': instance.solved,
  'acceptedAnswerId': instance.acceptedAnswerId,
  'upvoteCount': instance.upvoteCount,
  'downvoteCount': instance.downvoteCount,
  'tags': instance.tags,
  'answers': instance.answers.map((e) => e.toJson()).toList(),
};

_SimilarQuestion _$SimilarQuestionFromJson(Map<String, dynamic> json) =>
    _SimilarQuestion(
      questionId: (json['questionId'] as num).toInt(),
      title: json['title'] as String,
    );

Map<String, dynamic> _$SimilarQuestionToJson(_SimilarQuestion instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'title': instance.title,
    };

_CommunityTag _$CommunityTagFromJson(Map<String, dynamic> json) =>
    _CommunityTag(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CommunityTagToJson(_CommunityTag instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'postCount': instance.postCount,
    };
