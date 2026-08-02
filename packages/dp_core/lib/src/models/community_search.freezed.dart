// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'community_search.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CommunitySearchItem {

 int get id; String get title; String get boardType; int? get authorId; bool get solved; int get upvoteCount; int get replyCount; String get excerpt; String get highlight;
/// Create a copy of CommunitySearchItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommunitySearchItemCopyWith<CommunitySearchItem> get copyWith => _$CommunitySearchItemCopyWithImpl<CommunitySearchItem>(this as CommunitySearchItem, _$identity);

  /// Serializes this CommunitySearchItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommunitySearchItem&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.boardType, boardType) || other.boardType == boardType)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.solved, solved) || other.solved == solved)&&(identical(other.upvoteCount, upvoteCount) || other.upvoteCount == upvoteCount)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.highlight, highlight) || other.highlight == highlight));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,boardType,authorId,solved,upvoteCount,replyCount,excerpt,highlight);

@override
String toString() {
  return 'CommunitySearchItem(id: $id, title: $title, boardType: $boardType, authorId: $authorId, solved: $solved, upvoteCount: $upvoteCount, replyCount: $replyCount, excerpt: $excerpt, highlight: $highlight)';
}


}

/// @nodoc
abstract mixin class $CommunitySearchItemCopyWith<$Res>  {
  factory $CommunitySearchItemCopyWith(CommunitySearchItem value, $Res Function(CommunitySearchItem) _then) = _$CommunitySearchItemCopyWithImpl;
@useResult
$Res call({
 int id, String title, String boardType, int? authorId, bool solved, int upvoteCount, int replyCount, String excerpt, String highlight
});




}
/// @nodoc
class _$CommunitySearchItemCopyWithImpl<$Res>
    implements $CommunitySearchItemCopyWith<$Res> {
  _$CommunitySearchItemCopyWithImpl(this._self, this._then);

  final CommunitySearchItem _self;
  final $Res Function(CommunitySearchItem) _then;

/// Create a copy of CommunitySearchItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? boardType = null,Object? authorId = freezed,Object? solved = null,Object? upvoteCount = null,Object? replyCount = null,Object? excerpt = null,Object? highlight = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,boardType: null == boardType ? _self.boardType : boardType // ignore: cast_nullable_to_non_nullable
as String,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as int?,solved: null == solved ? _self.solved : solved // ignore: cast_nullable_to_non_nullable
as bool,upvoteCount: null == upvoteCount ? _self.upvoteCount : upvoteCount // ignore: cast_nullable_to_non_nullable
as int,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,excerpt: null == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String,highlight: null == highlight ? _self.highlight : highlight // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CommunitySearchItem].
extension CommunitySearchItemPatterns on CommunitySearchItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommunitySearchItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommunitySearchItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommunitySearchItem value)  $default,){
final _that = this;
switch (_that) {
case _CommunitySearchItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommunitySearchItem value)?  $default,){
final _that = this;
switch (_that) {
case _CommunitySearchItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String boardType,  int? authorId,  bool solved,  int upvoteCount,  int replyCount,  String excerpt,  String highlight)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommunitySearchItem() when $default != null:
return $default(_that.id,_that.title,_that.boardType,_that.authorId,_that.solved,_that.upvoteCount,_that.replyCount,_that.excerpt,_that.highlight);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String boardType,  int? authorId,  bool solved,  int upvoteCount,  int replyCount,  String excerpt,  String highlight)  $default,) {final _that = this;
switch (_that) {
case _CommunitySearchItem():
return $default(_that.id,_that.title,_that.boardType,_that.authorId,_that.solved,_that.upvoteCount,_that.replyCount,_that.excerpt,_that.highlight);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String boardType,  int? authorId,  bool solved,  int upvoteCount,  int replyCount,  String excerpt,  String highlight)?  $default,) {final _that = this;
switch (_that) {
case _CommunitySearchItem() when $default != null:
return $default(_that.id,_that.title,_that.boardType,_that.authorId,_that.solved,_that.upvoteCount,_that.replyCount,_that.excerpt,_that.highlight);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommunitySearchItem implements CommunitySearchItem {
  const _CommunitySearchItem({required this.id, required this.title, this.boardType = 'QNA', this.authorId, this.solved = false, this.upvoteCount = 0, this.replyCount = 0, this.excerpt = '', this.highlight = ''});
  factory _CommunitySearchItem.fromJson(Map<String, dynamic> json) => _$CommunitySearchItemFromJson(json);

@override final  int id;
@override final  String title;
@override@JsonKey() final  String boardType;
@override final  int? authorId;
@override@JsonKey() final  bool solved;
@override@JsonKey() final  int upvoteCount;
@override@JsonKey() final  int replyCount;
@override@JsonKey() final  String excerpt;
@override@JsonKey() final  String highlight;

/// Create a copy of CommunitySearchItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommunitySearchItemCopyWith<_CommunitySearchItem> get copyWith => __$CommunitySearchItemCopyWithImpl<_CommunitySearchItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommunitySearchItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommunitySearchItem&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.boardType, boardType) || other.boardType == boardType)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.solved, solved) || other.solved == solved)&&(identical(other.upvoteCount, upvoteCount) || other.upvoteCount == upvoteCount)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.highlight, highlight) || other.highlight == highlight));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,boardType,authorId,solved,upvoteCount,replyCount,excerpt,highlight);

@override
String toString() {
  return 'CommunitySearchItem(id: $id, title: $title, boardType: $boardType, authorId: $authorId, solved: $solved, upvoteCount: $upvoteCount, replyCount: $replyCount, excerpt: $excerpt, highlight: $highlight)';
}


}

/// @nodoc
abstract mixin class _$CommunitySearchItemCopyWith<$Res> implements $CommunitySearchItemCopyWith<$Res> {
  factory _$CommunitySearchItemCopyWith(_CommunitySearchItem value, $Res Function(_CommunitySearchItem) _then) = __$CommunitySearchItemCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String boardType, int? authorId, bool solved, int upvoteCount, int replyCount, String excerpt, String highlight
});




}
/// @nodoc
class __$CommunitySearchItemCopyWithImpl<$Res>
    implements _$CommunitySearchItemCopyWith<$Res> {
  __$CommunitySearchItemCopyWithImpl(this._self, this._then);

  final _CommunitySearchItem _self;
  final $Res Function(_CommunitySearchItem) _then;

/// Create a copy of CommunitySearchItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? boardType = null,Object? authorId = freezed,Object? solved = null,Object? upvoteCount = null,Object? replyCount = null,Object? excerpt = null,Object? highlight = null,}) {
  return _then(_CommunitySearchItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,boardType: null == boardType ? _self.boardType : boardType // ignore: cast_nullable_to_non_nullable
as String,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as int?,solved: null == solved ? _self.solved : solved // ignore: cast_nullable_to_non_nullable
as bool,upvoteCount: null == upvoteCount ? _self.upvoteCount : upvoteCount // ignore: cast_nullable_to_non_nullable
as int,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,excerpt: null == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String,highlight: null == highlight ? _self.highlight : highlight // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CommunitySearchResult {

 List<CommunitySearchItem> get items; int get total; int get page; int get size;
/// Create a copy of CommunitySearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommunitySearchResultCopyWith<CommunitySearchResult> get copyWith => _$CommunitySearchResultCopyWithImpl<CommunitySearchResult>(this as CommunitySearchResult, _$identity);

  /// Serializes this CommunitySearchResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommunitySearchResult&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,size);

@override
String toString() {
  return 'CommunitySearchResult(items: $items, total: $total, page: $page, size: $size)';
}


}

/// @nodoc
abstract mixin class $CommunitySearchResultCopyWith<$Res>  {
  factory $CommunitySearchResultCopyWith(CommunitySearchResult value, $Res Function(CommunitySearchResult) _then) = _$CommunitySearchResultCopyWithImpl;
@useResult
$Res call({
 List<CommunitySearchItem> items, int total, int page, int size
});




}
/// @nodoc
class _$CommunitySearchResultCopyWithImpl<$Res>
    implements $CommunitySearchResultCopyWith<$Res> {
  _$CommunitySearchResultCopyWithImpl(this._self, this._then);

  final CommunitySearchResult _self;
  final $Res Function(CommunitySearchResult) _then;

/// Create a copy of CommunitySearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? size = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<CommunitySearchItem>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CommunitySearchResult].
extension CommunitySearchResultPatterns on CommunitySearchResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommunitySearchResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommunitySearchResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommunitySearchResult value)  $default,){
final _that = this;
switch (_that) {
case _CommunitySearchResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommunitySearchResult value)?  $default,){
final _that = this;
switch (_that) {
case _CommunitySearchResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CommunitySearchItem> items,  int total,  int page,  int size)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommunitySearchResult() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.size);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CommunitySearchItem> items,  int total,  int page,  int size)  $default,) {final _that = this;
switch (_that) {
case _CommunitySearchResult():
return $default(_that.items,_that.total,_that.page,_that.size);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CommunitySearchItem> items,  int total,  int page,  int size)?  $default,) {final _that = this;
switch (_that) {
case _CommunitySearchResult() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.size);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommunitySearchResult implements CommunitySearchResult {
  const _CommunitySearchResult({final  List<CommunitySearchItem> items = const <CommunitySearchItem>[], this.total = 0, this.page = 0, this.size = 20}): _items = items;
  factory _CommunitySearchResult.fromJson(Map<String, dynamic> json) => _$CommunitySearchResultFromJson(json);

 final  List<CommunitySearchItem> _items;
@override@JsonKey() List<CommunitySearchItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey() final  int size;

/// Create a copy of CommunitySearchResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommunitySearchResultCopyWith<_CommunitySearchResult> get copyWith => __$CommunitySearchResultCopyWithImpl<_CommunitySearchResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommunitySearchResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommunitySearchResult&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,size);

@override
String toString() {
  return 'CommunitySearchResult(items: $items, total: $total, page: $page, size: $size)';
}


}

/// @nodoc
abstract mixin class _$CommunitySearchResultCopyWith<$Res> implements $CommunitySearchResultCopyWith<$Res> {
  factory _$CommunitySearchResultCopyWith(_CommunitySearchResult value, $Res Function(_CommunitySearchResult) _then) = __$CommunitySearchResultCopyWithImpl;
@override @useResult
$Res call({
 List<CommunitySearchItem> items, int total, int page, int size
});




}
/// @nodoc
class __$CommunitySearchResultCopyWithImpl<$Res>
    implements _$CommunitySearchResultCopyWith<$Res> {
  __$CommunitySearchResultCopyWithImpl(this._self, this._then);

  final _CommunitySearchResult _self;
  final $Res Function(_CommunitySearchResult) _then;

/// Create a copy of CommunitySearchResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? size = null,}) {
  return _then(_CommunitySearchResult(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<CommunitySearchItem>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
