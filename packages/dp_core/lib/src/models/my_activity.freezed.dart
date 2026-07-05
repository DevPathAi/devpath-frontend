// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'my_activity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MyActivity {

 int get questionCount; int get answerCount;
/// Create a copy of MyActivity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MyActivityCopyWith<MyActivity> get copyWith => _$MyActivityCopyWithImpl<MyActivity>(this as MyActivity, _$identity);

  /// Serializes this MyActivity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MyActivity&&(identical(other.questionCount, questionCount) || other.questionCount == questionCount)&&(identical(other.answerCount, answerCount) || other.answerCount == answerCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionCount,answerCount);

@override
String toString() {
  return 'MyActivity(questionCount: $questionCount, answerCount: $answerCount)';
}


}

/// @nodoc
abstract mixin class $MyActivityCopyWith<$Res>  {
  factory $MyActivityCopyWith(MyActivity value, $Res Function(MyActivity) _then) = _$MyActivityCopyWithImpl;
@useResult
$Res call({
 int questionCount, int answerCount
});




}
/// @nodoc
class _$MyActivityCopyWithImpl<$Res>
    implements $MyActivityCopyWith<$Res> {
  _$MyActivityCopyWithImpl(this._self, this._then);

  final MyActivity _self;
  final $Res Function(MyActivity) _then;

/// Create a copy of MyActivity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? questionCount = null,Object? answerCount = null,}) {
  return _then(_self.copyWith(
questionCount: null == questionCount ? _self.questionCount : questionCount // ignore: cast_nullable_to_non_nullable
as int,answerCount: null == answerCount ? _self.answerCount : answerCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MyActivity].
extension MyActivityPatterns on MyActivity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MyActivity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MyActivity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MyActivity value)  $default,){
final _that = this;
switch (_that) {
case _MyActivity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MyActivity value)?  $default,){
final _that = this;
switch (_that) {
case _MyActivity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int questionCount,  int answerCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MyActivity() when $default != null:
return $default(_that.questionCount,_that.answerCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int questionCount,  int answerCount)  $default,) {final _that = this;
switch (_that) {
case _MyActivity():
return $default(_that.questionCount,_that.answerCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int questionCount,  int answerCount)?  $default,) {final _that = this;
switch (_that) {
case _MyActivity() when $default != null:
return $default(_that.questionCount,_that.answerCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MyActivity implements MyActivity {
  const _MyActivity({this.questionCount = 0, this.answerCount = 0});
  factory _MyActivity.fromJson(Map<String, dynamic> json) => _$MyActivityFromJson(json);

@override@JsonKey() final  int questionCount;
@override@JsonKey() final  int answerCount;

/// Create a copy of MyActivity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MyActivityCopyWith<_MyActivity> get copyWith => __$MyActivityCopyWithImpl<_MyActivity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MyActivityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MyActivity&&(identical(other.questionCount, questionCount) || other.questionCount == questionCount)&&(identical(other.answerCount, answerCount) || other.answerCount == answerCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionCount,answerCount);

@override
String toString() {
  return 'MyActivity(questionCount: $questionCount, answerCount: $answerCount)';
}


}

/// @nodoc
abstract mixin class _$MyActivityCopyWith<$Res> implements $MyActivityCopyWith<$Res> {
  factory _$MyActivityCopyWith(_MyActivity value, $Res Function(_MyActivity) _then) = __$MyActivityCopyWithImpl;
@override @useResult
$Res call({
 int questionCount, int answerCount
});




}
/// @nodoc
class __$MyActivityCopyWithImpl<$Res>
    implements _$MyActivityCopyWith<$Res> {
  __$MyActivityCopyWithImpl(this._self, this._then);

  final _MyActivity _self;
  final $Res Function(_MyActivity) _then;

/// Create a copy of MyActivity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? questionCount = null,Object? answerCount = null,}) {
  return _then(_MyActivity(
questionCount: null == questionCount ? _self.questionCount : questionCount // ignore: cast_nullable_to_non_nullable
as int,answerCount: null == answerCount ? _self.answerCount : answerCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
