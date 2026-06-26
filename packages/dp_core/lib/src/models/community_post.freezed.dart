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
mixin _$CommunityPostSummary {

 int get id; String get title; int? get authorId; bool get solved; int get upvoteCount; int get answerCount;
/// Create a copy of CommunityPostSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommunityPostSummaryCopyWith<CommunityPostSummary> get copyWith => _$CommunityPostSummaryCopyWithImpl<CommunityPostSummary>(this as CommunityPostSummary, _$identity);

  /// Serializes this CommunityPostSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommunityPostSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.solved, solved) || other.solved == solved)&&(identical(other.upvoteCount, upvoteCount) || other.upvoteCount == upvoteCount)&&(identical(other.answerCount, answerCount) || other.answerCount == answerCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,authorId,solved,upvoteCount,answerCount);

@override
String toString() {
  return 'CommunityPostSummary(id: $id, title: $title, authorId: $authorId, solved: $solved, upvoteCount: $upvoteCount, answerCount: $answerCount)';
}


}

/// @nodoc
abstract mixin class $CommunityPostSummaryCopyWith<$Res>  {
  factory $CommunityPostSummaryCopyWith(CommunityPostSummary value, $Res Function(CommunityPostSummary) _then) = _$CommunityPostSummaryCopyWithImpl;
@useResult
$Res call({
 int id, String title, int? authorId, bool solved, int upvoteCount, int answerCount
});




}
/// @nodoc
class _$CommunityPostSummaryCopyWithImpl<$Res>
    implements $CommunityPostSummaryCopyWith<$Res> {
  _$CommunityPostSummaryCopyWithImpl(this._self, this._then);

  final CommunityPostSummary _self;
  final $Res Function(CommunityPostSummary) _then;

/// Create a copy of CommunityPostSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? authorId = freezed,Object? solved = null,Object? upvoteCount = null,Object? answerCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as int?,solved: null == solved ? _self.solved : solved // ignore: cast_nullable_to_non_nullable
as bool,upvoteCount: null == upvoteCount ? _self.upvoteCount : upvoteCount // ignore: cast_nullable_to_non_nullable
as int,answerCount: null == answerCount ? _self.answerCount : answerCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CommunityPostSummary].
extension CommunityPostSummaryPatterns on CommunityPostSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommunityPostSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommunityPostSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommunityPostSummary value)  $default,){
final _that = this;
switch (_that) {
case _CommunityPostSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommunityPostSummary value)?  $default,){
final _that = this;
switch (_that) {
case _CommunityPostSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  int? authorId,  bool solved,  int upvoteCount,  int answerCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommunityPostSummary() when $default != null:
return $default(_that.id,_that.title,_that.authorId,_that.solved,_that.upvoteCount,_that.answerCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  int? authorId,  bool solved,  int upvoteCount,  int answerCount)  $default,) {final _that = this;
switch (_that) {
case _CommunityPostSummary():
return $default(_that.id,_that.title,_that.authorId,_that.solved,_that.upvoteCount,_that.answerCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  int? authorId,  bool solved,  int upvoteCount,  int answerCount)?  $default,) {final _that = this;
switch (_that) {
case _CommunityPostSummary() when $default != null:
return $default(_that.id,_that.title,_that.authorId,_that.solved,_that.upvoteCount,_that.answerCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommunityPostSummary implements CommunityPostSummary {
  const _CommunityPostSummary({required this.id, required this.title, this.authorId, this.solved = false, this.upvoteCount = 0, this.answerCount = 0});
  factory _CommunityPostSummary.fromJson(Map<String, dynamic> json) => _$CommunityPostSummaryFromJson(json);

@override final  int id;
@override final  String title;
@override final  int? authorId;
@override@JsonKey() final  bool solved;
@override@JsonKey() final  int upvoteCount;
@override@JsonKey() final  int answerCount;

/// Create a copy of CommunityPostSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommunityPostSummaryCopyWith<_CommunityPostSummary> get copyWith => __$CommunityPostSummaryCopyWithImpl<_CommunityPostSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommunityPostSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommunityPostSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.solved, solved) || other.solved == solved)&&(identical(other.upvoteCount, upvoteCount) || other.upvoteCount == upvoteCount)&&(identical(other.answerCount, answerCount) || other.answerCount == answerCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,authorId,solved,upvoteCount,answerCount);

@override
String toString() {
  return 'CommunityPostSummary(id: $id, title: $title, authorId: $authorId, solved: $solved, upvoteCount: $upvoteCount, answerCount: $answerCount)';
}


}

/// @nodoc
abstract mixin class _$CommunityPostSummaryCopyWith<$Res> implements $CommunityPostSummaryCopyWith<$Res> {
  factory _$CommunityPostSummaryCopyWith(_CommunityPostSummary value, $Res Function(_CommunityPostSummary) _then) = __$CommunityPostSummaryCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, int? authorId, bool solved, int upvoteCount, int answerCount
});




}
/// @nodoc
class __$CommunityPostSummaryCopyWithImpl<$Res>
    implements _$CommunityPostSummaryCopyWith<$Res> {
  __$CommunityPostSummaryCopyWithImpl(this._self, this._then);

  final _CommunityPostSummary _self;
  final $Res Function(_CommunityPostSummary) _then;

/// Create a copy of CommunityPostSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? authorId = freezed,Object? solved = null,Object? upvoteCount = null,Object? answerCount = null,}) {
  return _then(_CommunityPostSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as int?,solved: null == solved ? _self.solved : solved // ignore: cast_nullable_to_non_nullable
as bool,upvoteCount: null == upvoteCount ? _self.upvoteCount : upvoteCount // ignore: cast_nullable_to_non_nullable
as int,answerCount: null == answerCount ? _self.answerCount : answerCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CommunityAnswer {

 int get id; int? get authorId; String get bodyMd; bool get aiGenerated; bool get accepted; int get upvoteCount;
/// Create a copy of CommunityAnswer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommunityAnswerCopyWith<CommunityAnswer> get copyWith => _$CommunityAnswerCopyWithImpl<CommunityAnswer>(this as CommunityAnswer, _$identity);

  /// Serializes this CommunityAnswer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommunityAnswer&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.bodyMd, bodyMd) || other.bodyMd == bodyMd)&&(identical(other.aiGenerated, aiGenerated) || other.aiGenerated == aiGenerated)&&(identical(other.accepted, accepted) || other.accepted == accepted)&&(identical(other.upvoteCount, upvoteCount) || other.upvoteCount == upvoteCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,authorId,bodyMd,aiGenerated,accepted,upvoteCount);

@override
String toString() {
  return 'CommunityAnswer(id: $id, authorId: $authorId, bodyMd: $bodyMd, aiGenerated: $aiGenerated, accepted: $accepted, upvoteCount: $upvoteCount)';
}


}

/// @nodoc
abstract mixin class $CommunityAnswerCopyWith<$Res>  {
  factory $CommunityAnswerCopyWith(CommunityAnswer value, $Res Function(CommunityAnswer) _then) = _$CommunityAnswerCopyWithImpl;
@useResult
$Res call({
 int id, int? authorId, String bodyMd, bool aiGenerated, bool accepted, int upvoteCount
});




}
/// @nodoc
class _$CommunityAnswerCopyWithImpl<$Res>
    implements $CommunityAnswerCopyWith<$Res> {
  _$CommunityAnswerCopyWithImpl(this._self, this._then);

  final CommunityAnswer _self;
  final $Res Function(CommunityAnswer) _then;

/// Create a copy of CommunityAnswer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? authorId = freezed,Object? bodyMd = null,Object? aiGenerated = null,Object? accepted = null,Object? upvoteCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as int?,bodyMd: null == bodyMd ? _self.bodyMd : bodyMd // ignore: cast_nullable_to_non_nullable
as String,aiGenerated: null == aiGenerated ? _self.aiGenerated : aiGenerated // ignore: cast_nullable_to_non_nullable
as bool,accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as bool,upvoteCount: null == upvoteCount ? _self.upvoteCount : upvoteCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CommunityAnswer].
extension CommunityAnswerPatterns on CommunityAnswer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommunityAnswer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommunityAnswer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommunityAnswer value)  $default,){
final _that = this;
switch (_that) {
case _CommunityAnswer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommunityAnswer value)?  $default,){
final _that = this;
switch (_that) {
case _CommunityAnswer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int? authorId,  String bodyMd,  bool aiGenerated,  bool accepted,  int upvoteCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommunityAnswer() when $default != null:
return $default(_that.id,_that.authorId,_that.bodyMd,_that.aiGenerated,_that.accepted,_that.upvoteCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int? authorId,  String bodyMd,  bool aiGenerated,  bool accepted,  int upvoteCount)  $default,) {final _that = this;
switch (_that) {
case _CommunityAnswer():
return $default(_that.id,_that.authorId,_that.bodyMd,_that.aiGenerated,_that.accepted,_that.upvoteCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int? authorId,  String bodyMd,  bool aiGenerated,  bool accepted,  int upvoteCount)?  $default,) {final _that = this;
switch (_that) {
case _CommunityAnswer() when $default != null:
return $default(_that.id,_that.authorId,_that.bodyMd,_that.aiGenerated,_that.accepted,_that.upvoteCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommunityAnswer implements CommunityAnswer {
  const _CommunityAnswer({required this.id, this.authorId, required this.bodyMd, this.aiGenerated = false, this.accepted = false, this.upvoteCount = 0});
  factory _CommunityAnswer.fromJson(Map<String, dynamic> json) => _$CommunityAnswerFromJson(json);

@override final  int id;
@override final  int? authorId;
@override final  String bodyMd;
@override@JsonKey() final  bool aiGenerated;
@override@JsonKey() final  bool accepted;
@override@JsonKey() final  int upvoteCount;

/// Create a copy of CommunityAnswer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommunityAnswerCopyWith<_CommunityAnswer> get copyWith => __$CommunityAnswerCopyWithImpl<_CommunityAnswer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommunityAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommunityAnswer&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.bodyMd, bodyMd) || other.bodyMd == bodyMd)&&(identical(other.aiGenerated, aiGenerated) || other.aiGenerated == aiGenerated)&&(identical(other.accepted, accepted) || other.accepted == accepted)&&(identical(other.upvoteCount, upvoteCount) || other.upvoteCount == upvoteCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,authorId,bodyMd,aiGenerated,accepted,upvoteCount);

@override
String toString() {
  return 'CommunityAnswer(id: $id, authorId: $authorId, bodyMd: $bodyMd, aiGenerated: $aiGenerated, accepted: $accepted, upvoteCount: $upvoteCount)';
}


}

/// @nodoc
abstract mixin class _$CommunityAnswerCopyWith<$Res> implements $CommunityAnswerCopyWith<$Res> {
  factory _$CommunityAnswerCopyWith(_CommunityAnswer value, $Res Function(_CommunityAnswer) _then) = __$CommunityAnswerCopyWithImpl;
@override @useResult
$Res call({
 int id, int? authorId, String bodyMd, bool aiGenerated, bool accepted, int upvoteCount
});




}
/// @nodoc
class __$CommunityAnswerCopyWithImpl<$Res>
    implements _$CommunityAnswerCopyWith<$Res> {
  __$CommunityAnswerCopyWithImpl(this._self, this._then);

  final _CommunityAnswer _self;
  final $Res Function(_CommunityAnswer) _then;

/// Create a copy of CommunityAnswer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? authorId = freezed,Object? bodyMd = null,Object? aiGenerated = null,Object? accepted = null,Object? upvoteCount = null,}) {
  return _then(_CommunityAnswer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as int?,bodyMd: null == bodyMd ? _self.bodyMd : bodyMd // ignore: cast_nullable_to_non_nullable
as String,aiGenerated: null == aiGenerated ? _self.aiGenerated : aiGenerated // ignore: cast_nullable_to_non_nullable
as bool,accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as bool,upvoteCount: null == upvoteCount ? _self.upvoteCount : upvoteCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CommunityQuestionDetail {

 int get id; String get title; String get bodyMd; bool get solved; int? get acceptedAnswerId; int get upvoteCount; int get downvoteCount; List<String> get tags; List<CommunityAnswer> get answers;
/// Create a copy of CommunityQuestionDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommunityQuestionDetailCopyWith<CommunityQuestionDetail> get copyWith => _$CommunityQuestionDetailCopyWithImpl<CommunityQuestionDetail>(this as CommunityQuestionDetail, _$identity);

  /// Serializes this CommunityQuestionDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommunityQuestionDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.bodyMd, bodyMd) || other.bodyMd == bodyMd)&&(identical(other.solved, solved) || other.solved == solved)&&(identical(other.acceptedAnswerId, acceptedAnswerId) || other.acceptedAnswerId == acceptedAnswerId)&&(identical(other.upvoteCount, upvoteCount) || other.upvoteCount == upvoteCount)&&(identical(other.downvoteCount, downvoteCount) || other.downvoteCount == downvoteCount)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.answers, answers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,bodyMd,solved,acceptedAnswerId,upvoteCount,downvoteCount,const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(answers));

@override
String toString() {
  return 'CommunityQuestionDetail(id: $id, title: $title, bodyMd: $bodyMd, solved: $solved, acceptedAnswerId: $acceptedAnswerId, upvoteCount: $upvoteCount, downvoteCount: $downvoteCount, tags: $tags, answers: $answers)';
}


}

/// @nodoc
abstract mixin class $CommunityQuestionDetailCopyWith<$Res>  {
  factory $CommunityQuestionDetailCopyWith(CommunityQuestionDetail value, $Res Function(CommunityQuestionDetail) _then) = _$CommunityQuestionDetailCopyWithImpl;
@useResult
$Res call({
 int id, String title, String bodyMd, bool solved, int? acceptedAnswerId, int upvoteCount, int downvoteCount, List<String> tags, List<CommunityAnswer> answers
});




}
/// @nodoc
class _$CommunityQuestionDetailCopyWithImpl<$Res>
    implements $CommunityQuestionDetailCopyWith<$Res> {
  _$CommunityQuestionDetailCopyWithImpl(this._self, this._then);

  final CommunityQuestionDetail _self;
  final $Res Function(CommunityQuestionDetail) _then;

/// Create a copy of CommunityQuestionDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? bodyMd = null,Object? solved = null,Object? acceptedAnswerId = freezed,Object? upvoteCount = null,Object? downvoteCount = null,Object? tags = null,Object? answers = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,bodyMd: null == bodyMd ? _self.bodyMd : bodyMd // ignore: cast_nullable_to_non_nullable
as String,solved: null == solved ? _self.solved : solved // ignore: cast_nullable_to_non_nullable
as bool,acceptedAnswerId: freezed == acceptedAnswerId ? _self.acceptedAnswerId : acceptedAnswerId // ignore: cast_nullable_to_non_nullable
as int?,upvoteCount: null == upvoteCount ? _self.upvoteCount : upvoteCount // ignore: cast_nullable_to_non_nullable
as int,downvoteCount: null == downvoteCount ? _self.downvoteCount : downvoteCount // ignore: cast_nullable_to_non_nullable
as int,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,answers: null == answers ? _self.answers : answers // ignore: cast_nullable_to_non_nullable
as List<CommunityAnswer>,
  ));
}

}


/// Adds pattern-matching-related methods to [CommunityQuestionDetail].
extension CommunityQuestionDetailPatterns on CommunityQuestionDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommunityQuestionDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommunityQuestionDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommunityQuestionDetail value)  $default,){
final _that = this;
switch (_that) {
case _CommunityQuestionDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommunityQuestionDetail value)?  $default,){
final _that = this;
switch (_that) {
case _CommunityQuestionDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String bodyMd,  bool solved,  int? acceptedAnswerId,  int upvoteCount,  int downvoteCount,  List<String> tags,  List<CommunityAnswer> answers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommunityQuestionDetail() when $default != null:
return $default(_that.id,_that.title,_that.bodyMd,_that.solved,_that.acceptedAnswerId,_that.upvoteCount,_that.downvoteCount,_that.tags,_that.answers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String bodyMd,  bool solved,  int? acceptedAnswerId,  int upvoteCount,  int downvoteCount,  List<String> tags,  List<CommunityAnswer> answers)  $default,) {final _that = this;
switch (_that) {
case _CommunityQuestionDetail():
return $default(_that.id,_that.title,_that.bodyMd,_that.solved,_that.acceptedAnswerId,_that.upvoteCount,_that.downvoteCount,_that.tags,_that.answers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String bodyMd,  bool solved,  int? acceptedAnswerId,  int upvoteCount,  int downvoteCount,  List<String> tags,  List<CommunityAnswer> answers)?  $default,) {final _that = this;
switch (_that) {
case _CommunityQuestionDetail() when $default != null:
return $default(_that.id,_that.title,_that.bodyMd,_that.solved,_that.acceptedAnswerId,_that.upvoteCount,_that.downvoteCount,_that.tags,_that.answers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommunityQuestionDetail implements CommunityQuestionDetail {
  const _CommunityQuestionDetail({required this.id, required this.title, required this.bodyMd, this.solved = false, this.acceptedAnswerId, this.upvoteCount = 0, this.downvoteCount = 0, final  List<String> tags = const <String>[], final  List<CommunityAnswer> answers = const <CommunityAnswer>[]}): _tags = tags,_answers = answers;
  factory _CommunityQuestionDetail.fromJson(Map<String, dynamic> json) => _$CommunityQuestionDetailFromJson(json);

@override final  int id;
@override final  String title;
@override final  String bodyMd;
@override@JsonKey() final  bool solved;
@override final  int? acceptedAnswerId;
@override@JsonKey() final  int upvoteCount;
@override@JsonKey() final  int downvoteCount;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<CommunityAnswer> _answers;
@override@JsonKey() List<CommunityAnswer> get answers {
  if (_answers is EqualUnmodifiableListView) return _answers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_answers);
}


/// Create a copy of CommunityQuestionDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommunityQuestionDetailCopyWith<_CommunityQuestionDetail> get copyWith => __$CommunityQuestionDetailCopyWithImpl<_CommunityQuestionDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommunityQuestionDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommunityQuestionDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.bodyMd, bodyMd) || other.bodyMd == bodyMd)&&(identical(other.solved, solved) || other.solved == solved)&&(identical(other.acceptedAnswerId, acceptedAnswerId) || other.acceptedAnswerId == acceptedAnswerId)&&(identical(other.upvoteCount, upvoteCount) || other.upvoteCount == upvoteCount)&&(identical(other.downvoteCount, downvoteCount) || other.downvoteCount == downvoteCount)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._answers, _answers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,bodyMd,solved,acceptedAnswerId,upvoteCount,downvoteCount,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_answers));

@override
String toString() {
  return 'CommunityQuestionDetail(id: $id, title: $title, bodyMd: $bodyMd, solved: $solved, acceptedAnswerId: $acceptedAnswerId, upvoteCount: $upvoteCount, downvoteCount: $downvoteCount, tags: $tags, answers: $answers)';
}


}

/// @nodoc
abstract mixin class _$CommunityQuestionDetailCopyWith<$Res> implements $CommunityQuestionDetailCopyWith<$Res> {
  factory _$CommunityQuestionDetailCopyWith(_CommunityQuestionDetail value, $Res Function(_CommunityQuestionDetail) _then) = __$CommunityQuestionDetailCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String bodyMd, bool solved, int? acceptedAnswerId, int upvoteCount, int downvoteCount, List<String> tags, List<CommunityAnswer> answers
});




}
/// @nodoc
class __$CommunityQuestionDetailCopyWithImpl<$Res>
    implements _$CommunityQuestionDetailCopyWith<$Res> {
  __$CommunityQuestionDetailCopyWithImpl(this._self, this._then);

  final _CommunityQuestionDetail _self;
  final $Res Function(_CommunityQuestionDetail) _then;

/// Create a copy of CommunityQuestionDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? bodyMd = null,Object? solved = null,Object? acceptedAnswerId = freezed,Object? upvoteCount = null,Object? downvoteCount = null,Object? tags = null,Object? answers = null,}) {
  return _then(_CommunityQuestionDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,bodyMd: null == bodyMd ? _self.bodyMd : bodyMd // ignore: cast_nullable_to_non_nullable
as String,solved: null == solved ? _self.solved : solved // ignore: cast_nullable_to_non_nullable
as bool,acceptedAnswerId: freezed == acceptedAnswerId ? _self.acceptedAnswerId : acceptedAnswerId // ignore: cast_nullable_to_non_nullable
as int?,upvoteCount: null == upvoteCount ? _self.upvoteCount : upvoteCount // ignore: cast_nullable_to_non_nullable
as int,downvoteCount: null == downvoteCount ? _self.downvoteCount : downvoteCount // ignore: cast_nullable_to_non_nullable
as int,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,answers: null == answers ? _self._answers : answers // ignore: cast_nullable_to_non_nullable
as List<CommunityAnswer>,
  ));
}


}


/// @nodoc
mixin _$SimilarQuestion {

 int get questionId; String get title;
/// Create a copy of SimilarQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SimilarQuestionCopyWith<SimilarQuestion> get copyWith => _$SimilarQuestionCopyWithImpl<SimilarQuestion>(this as SimilarQuestion, _$identity);

  /// Serializes this SimilarQuestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SimilarQuestion&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionId,title);

@override
String toString() {
  return 'SimilarQuestion(questionId: $questionId, title: $title)';
}


}

/// @nodoc
abstract mixin class $SimilarQuestionCopyWith<$Res>  {
  factory $SimilarQuestionCopyWith(SimilarQuestion value, $Res Function(SimilarQuestion) _then) = _$SimilarQuestionCopyWithImpl;
@useResult
$Res call({
 int questionId, String title
});




}
/// @nodoc
class _$SimilarQuestionCopyWithImpl<$Res>
    implements $SimilarQuestionCopyWith<$Res> {
  _$SimilarQuestionCopyWithImpl(this._self, this._then);

  final SimilarQuestion _self;
  final $Res Function(SimilarQuestion) _then;

/// Create a copy of SimilarQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? questionId = null,Object? title = null,}) {
  return _then(_self.copyWith(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SimilarQuestion].
extension SimilarQuestionPatterns on SimilarQuestion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SimilarQuestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SimilarQuestion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SimilarQuestion value)  $default,){
final _that = this;
switch (_that) {
case _SimilarQuestion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SimilarQuestion value)?  $default,){
final _that = this;
switch (_that) {
case _SimilarQuestion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int questionId,  String title)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SimilarQuestion() when $default != null:
return $default(_that.questionId,_that.title);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int questionId,  String title)  $default,) {final _that = this;
switch (_that) {
case _SimilarQuestion():
return $default(_that.questionId,_that.title);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int questionId,  String title)?  $default,) {final _that = this;
switch (_that) {
case _SimilarQuestion() when $default != null:
return $default(_that.questionId,_that.title);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SimilarQuestion implements SimilarQuestion {
  const _SimilarQuestion({required this.questionId, required this.title});
  factory _SimilarQuestion.fromJson(Map<String, dynamic> json) => _$SimilarQuestionFromJson(json);

@override final  int questionId;
@override final  String title;

/// Create a copy of SimilarQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SimilarQuestionCopyWith<_SimilarQuestion> get copyWith => __$SimilarQuestionCopyWithImpl<_SimilarQuestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SimilarQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SimilarQuestion&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionId,title);

@override
String toString() {
  return 'SimilarQuestion(questionId: $questionId, title: $title)';
}


}

/// @nodoc
abstract mixin class _$SimilarQuestionCopyWith<$Res> implements $SimilarQuestionCopyWith<$Res> {
  factory _$SimilarQuestionCopyWith(_SimilarQuestion value, $Res Function(_SimilarQuestion) _then) = __$SimilarQuestionCopyWithImpl;
@override @useResult
$Res call({
 int questionId, String title
});




}
/// @nodoc
class __$SimilarQuestionCopyWithImpl<$Res>
    implements _$SimilarQuestionCopyWith<$Res> {
  __$SimilarQuestionCopyWithImpl(this._self, this._then);

  final _SimilarQuestion _self;
  final $Res Function(_SimilarQuestion) _then;

/// Create a copy of SimilarQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? questionId = null,Object? title = null,}) {
  return _then(_SimilarQuestion(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CommunityTag {

 int get id; String get name; int get postCount;
/// Create a copy of CommunityTag
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommunityTagCopyWith<CommunityTag> get copyWith => _$CommunityTagCopyWithImpl<CommunityTag>(this as CommunityTag, _$identity);

  /// Serializes this CommunityTag to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommunityTag&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.postCount, postCount) || other.postCount == postCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,postCount);

@override
String toString() {
  return 'CommunityTag(id: $id, name: $name, postCount: $postCount)';
}


}

/// @nodoc
abstract mixin class $CommunityTagCopyWith<$Res>  {
  factory $CommunityTagCopyWith(CommunityTag value, $Res Function(CommunityTag) _then) = _$CommunityTagCopyWithImpl;
@useResult
$Res call({
 int id, String name, int postCount
});




}
/// @nodoc
class _$CommunityTagCopyWithImpl<$Res>
    implements $CommunityTagCopyWith<$Res> {
  _$CommunityTagCopyWithImpl(this._self, this._then);

  final CommunityTag _self;
  final $Res Function(CommunityTag) _then;

/// Create a copy of CommunityTag
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? postCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,postCount: null == postCount ? _self.postCount : postCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CommunityTag].
extension CommunityTagPatterns on CommunityTag {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommunityTag value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommunityTag() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommunityTag value)  $default,){
final _that = this;
switch (_that) {
case _CommunityTag():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommunityTag value)?  $default,){
final _that = this;
switch (_that) {
case _CommunityTag() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  int postCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommunityTag() when $default != null:
return $default(_that.id,_that.name,_that.postCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  int postCount)  $default,) {final _that = this;
switch (_that) {
case _CommunityTag():
return $default(_that.id,_that.name,_that.postCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  int postCount)?  $default,) {final _that = this;
switch (_that) {
case _CommunityTag() when $default != null:
return $default(_that.id,_that.name,_that.postCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommunityTag implements CommunityTag {
  const _CommunityTag({required this.id, required this.name, this.postCount = 0});
  factory _CommunityTag.fromJson(Map<String, dynamic> json) => _$CommunityTagFromJson(json);

@override final  int id;
@override final  String name;
@override@JsonKey() final  int postCount;

/// Create a copy of CommunityTag
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommunityTagCopyWith<_CommunityTag> get copyWith => __$CommunityTagCopyWithImpl<_CommunityTag>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommunityTagToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommunityTag&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.postCount, postCount) || other.postCount == postCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,postCount);

@override
String toString() {
  return 'CommunityTag(id: $id, name: $name, postCount: $postCount)';
}


}

/// @nodoc
abstract mixin class _$CommunityTagCopyWith<$Res> implements $CommunityTagCopyWith<$Res> {
  factory _$CommunityTagCopyWith(_CommunityTag value, $Res Function(_CommunityTag) _then) = __$CommunityTagCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, int postCount
});




}
/// @nodoc
class __$CommunityTagCopyWithImpl<$Res>
    implements _$CommunityTagCopyWith<$Res> {
  __$CommunityTagCopyWithImpl(this._self, this._then);

  final _CommunityTag _self;
  final $Res Function(_CommunityTag) _then;

/// Create a copy of CommunityTag
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? postCount = null,}) {
  return _then(_CommunityTag(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,postCount: null == postCount ? _self.postCount : postCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
