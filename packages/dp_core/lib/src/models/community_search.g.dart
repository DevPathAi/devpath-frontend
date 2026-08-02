// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_search.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommunitySearchItem _$CommunitySearchItemFromJson(Map<String, dynamic> json) =>
    _CommunitySearchItem(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      boardType: json['boardType'] as String? ?? 'QNA',
      authorId: (json['authorId'] as num?)?.toInt(),
      solved: json['solved'] as bool? ?? false,
      upvoteCount: (json['upvoteCount'] as num?)?.toInt() ?? 0,
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      excerpt: json['excerpt'] as String? ?? '',
      highlight: json['highlight'] as String? ?? '',
    );

Map<String, dynamic> _$CommunitySearchItemToJson(
  _CommunitySearchItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'boardType': instance.boardType,
  'authorId': instance.authorId,
  'solved': instance.solved,
  'upvoteCount': instance.upvoteCount,
  'replyCount': instance.replyCount,
  'excerpt': instance.excerpt,
  'highlight': instance.highlight,
};

_CommunitySearchResult _$CommunitySearchResultFromJson(
  Map<String, dynamic> json,
) => _CommunitySearchResult(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => CommunitySearchItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CommunitySearchItem>[],
  total: (json['total'] as num?)?.toInt() ?? 0,
  page: (json['page'] as num?)?.toInt() ?? 0,
  size: (json['size'] as num?)?.toInt() ?? 20,
);

Map<String, dynamic> _$CommunitySearchResultToJson(
  _CommunitySearchResult instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'total': instance.total,
  'page': instance.page,
  'size': instance.size,
};
