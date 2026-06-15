// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'community_post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CommunityPost {

 String get id; String get title; String get author; int get answerCount; String? get body;
/// Create a copy of CommunityPost
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommunityPostCopyWith<CommunityPost> get copyWith => _$CommunityPostCopyWithImpl<CommunityPost>(this as CommunityPost, _$identity);

  /// Serializes this CommunityPost to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommunityPost&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.answerCount, answerCount) || other.answerCount == answerCount)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,author,answerCount,body);

@override
String toString() {
  return 'CommunityPost(id: $id, title: $title, author: $author, answerCount: $answerCount, body: $body)';
}


}

/// @nodoc
abstract mixin class $CommunityPostCopyWith<$Res>  {
  factory $CommunityPostCopyWith(CommunityPost value, $Res Function(CommunityPost) _then) = _$CommunityPostCopyWithImpl;
@useResult
$Res call({
 String id, String title, String author, int answerCount, String? body
});




}
/// @nodoc
class _$CommunityPostCopyWithImpl<$Res>
    implements $CommunityPostCopyWith<$Res> {
  _$CommunityPostCopyWithImpl(this._self, this._then);

  final CommunityPost _self;
  final $Res Function(CommunityPost) _then;

/// Create a copy of CommunityPost
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? author = null,Object? answerCount = null,Object? body = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,answerCount: null == answerCount ? _self.answerCount : answerCount // ignore: cast_nullable_to_non_nullable
as int,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CommunityPost].
extension CommunityPostPatterns on CommunityPost {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommunityPost value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommunityPost() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommunityPost value)  $default,){
final _that = this;
switch (_that) {
case _CommunityPost():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommunityPost value)?  $default,){
final _that = this;
switch (_that) {
case _CommunityPost() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String author,  int answerCount,  String? body)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommunityPost() when $default != null:
return $default(_that.id,_that.title,_that.author,_that.answerCount,_that.body);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String author,  int answerCount,  String? body)  $default,) {final _that = this;
switch (_that) {
case _CommunityPost():
return $default(_that.id,_that.title,_that.author,_that.answerCount,_that.body);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String author,  int answerCount,  String? body)?  $default,) {final _that = this;
switch (_that) {
case _CommunityPost() when $default != null:
return $default(_that.id,_that.title,_that.author,_that.answerCount,_that.body);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommunityPost implements CommunityPost {
  const _CommunityPost({required this.id, required this.title, required this.author, this.answerCount = 0, this.body});
  factory _CommunityPost.fromJson(Map<String, dynamic> json) => _$CommunityPostFromJson(json);

@override final  String id;
@override final  String title;
@override final  String author;
@override@JsonKey() final  int answerCount;
@override final  String? body;

/// Create a copy of CommunityPost
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommunityPostCopyWith<_CommunityPost> get copyWith => __$CommunityPostCopyWithImpl<_CommunityPost>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommunityPostToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommunityPost&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.answerCount, answerCount) || other.answerCount == answerCount)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,author,answerCount,body);

@override
String toString() {
  return 'CommunityPost(id: $id, title: $title, author: $author, answerCount: $answerCount, body: $body)';
}


}

/// @nodoc
abstract mixin class _$CommunityPostCopyWith<$Res> implements $CommunityPostCopyWith<$Res> {
  factory _$CommunityPostCopyWith(_CommunityPost value, $Res Function(_CommunityPost) _then) = __$CommunityPostCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String author, int answerCount, String? body
});




}
/// @nodoc
class __$CommunityPostCopyWithImpl<$Res>
    implements _$CommunityPostCopyWith<$Res> {
  __$CommunityPostCopyWithImpl(this._self, this._then);

  final _CommunityPost _self;
  final $Res Function(_CommunityPost) _then;

/// Create a copy of CommunityPost
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? author = null,Object? answerCount = null,Object? body = freezed,}) {
  return _then(_CommunityPost(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,answerCount: null == answerCount ? _self.answerCount : answerCount // ignore: cast_nullable_to_non_nullable
as int,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
