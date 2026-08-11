import 'package:freezed_annotation/freezed_annotation.dart';

part 'community_search.freezed.dart';
part 'community_search.g.dart';

/// 검색 결과 1건(`GET /community/search` → `SearchItemView`).
///
/// 목록의 [CommunityPostSummary] 와 같은 필드에 [highlight] 가 더해진 형태다.
///
/// ⚠️ [highlight] 는 매칭 구간이 `<em>` 으로 감싸인 문자열이지만, **ES 하이라이터는 사용자가
/// 쓴 본문의 `<`·`>` 를 이스케이프하지 않는다.** 본문에 `<img src=x onerror=...>` 가 있으면
/// 그 마크업이 그대로 이 필드에 담겨 온다. 따라서 **HTML 로 해석해 렌더하지 말고**,
/// `<em>` 만 화이트리스트로 파싱해 강조 스팬을 만들고 나머지는 평문으로 취급해야 한다.
@freezed
abstract class CommunitySearchItem with _$CommunitySearchItem {
  const factory CommunitySearchItem({
    required int id,
    required String title,
    @Default('QNA') String boardType,
    int? authorId,
    @Default(false) bool solved,
    @Default(0) int upvoteCount,
    @Default(0) int replyCount,
    @Default('') String excerpt,
    @Default('') String highlight,
  }) = _CommunitySearchItem;

  factory CommunitySearchItem.fromJson(Map<String, dynamic> json) =>
      _$CommunitySearchItemFromJson(json);
}

/// 검색 응답 envelope. 목록 API(bare 배열)와 달리 총건수·페이지를 가진다.
/// [total] 이 [items] 길이보다 크면 다음 페이지가 있다.
@freezed
abstract class CommunitySearchResult with _$CommunitySearchResult {
  const factory CommunitySearchResult({
    @Default(<CommunitySearchItem>[]) List<CommunitySearchItem> items,
    @Default(0) int total,
    @Default(0) int page,
    @Default(20) int size,
  }) = _CommunitySearchResult;

  factory CommunitySearchResult.fromJson(Map<String, dynamic> json) =>
      _$CommunitySearchResultFromJson(json);
}
