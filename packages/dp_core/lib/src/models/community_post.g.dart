// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommunityPost _$CommunityPostFromJson(Map<String, dynamic> json) =>
    _CommunityPost(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      answerCount: (json['answerCount'] as num?)?.toInt() ?? 0,
      body: json['body'] as String?,
    );

Map<String, dynamic> _$CommunityPostToJson(_CommunityPost instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'author': instance.author,
      'answerCount': instance.answerCount,
      'body': instance.body,
    };
