// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_view.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProfileView {

 String? get avatar; String? get bio; String? get learningGoal; String? get targetTrack; int? get experienceYears;
/// Create a copy of ProfileView
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileViewCopyWith<ProfileView> get copyWith => _$ProfileViewCopyWithImpl<ProfileView>(this as ProfileView, _$identity);

  /// Serializes this ProfileView to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileView&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.learningGoal, learningGoal) || other.learningGoal == learningGoal)&&(identical(other.targetTrack, targetTrack) || other.targetTrack == targetTrack)&&(identical(other.experienceYears, experienceYears) || other.experienceYears == experienceYears));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,avatar,bio,learningGoal,targetTrack,experienceYears);

@override
String toString() {
  return 'ProfileView(avatar: $avatar, bio: $bio, learningGoal: $learningGoal, targetTrack: $targetTrack, experienceYears: $experienceYears)';
}


}

/// @nodoc
abstract mixin class $ProfileViewCopyWith<$Res>  {
  factory $ProfileViewCopyWith(ProfileView value, $Res Function(ProfileView) _then) = _$ProfileViewCopyWithImpl;
@useResult
$Res call({
 String? avatar, String? bio, String? learningGoal, String? targetTrack, int? experienceYears
});




}
/// @nodoc
class _$ProfileViewCopyWithImpl<$Res>
    implements $ProfileViewCopyWith<$Res> {
  _$ProfileViewCopyWithImpl(this._self, this._then);

  final ProfileView _self;
  final $Res Function(ProfileView) _then;

/// Create a copy of ProfileView
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? avatar = freezed,Object? bio = freezed,Object? learningGoal = freezed,Object? targetTrack = freezed,Object? experienceYears = freezed,}) {
  return _then(_self.copyWith(
avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,learningGoal: freezed == learningGoal ? _self.learningGoal : learningGoal // ignore: cast_nullable_to_non_nullable
as String?,targetTrack: freezed == targetTrack ? _self.targetTrack : targetTrack // ignore: cast_nullable_to_non_nullable
as String?,experienceYears: freezed == experienceYears ? _self.experienceYears : experienceYears // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileView].
extension ProfileViewPatterns on ProfileView {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileView value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileView() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileView value)  $default,){
final _that = this;
switch (_that) {
case _ProfileView():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileView value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileView() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? avatar,  String? bio,  String? learningGoal,  String? targetTrack,  int? experienceYears)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileView() when $default != null:
return $default(_that.avatar,_that.bio,_that.learningGoal,_that.targetTrack,_that.experienceYears);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? avatar,  String? bio,  String? learningGoal,  String? targetTrack,  int? experienceYears)  $default,) {final _that = this;
switch (_that) {
case _ProfileView():
return $default(_that.avatar,_that.bio,_that.learningGoal,_that.targetTrack,_that.experienceYears);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? avatar,  String? bio,  String? learningGoal,  String? targetTrack,  int? experienceYears)?  $default,) {final _that = this;
switch (_that) {
case _ProfileView() when $default != null:
return $default(_that.avatar,_that.bio,_that.learningGoal,_that.targetTrack,_that.experienceYears);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileView implements ProfileView {
  const _ProfileView({this.avatar, this.bio, this.learningGoal, this.targetTrack, this.experienceYears});
  factory _ProfileView.fromJson(Map<String, dynamic> json) => _$ProfileViewFromJson(json);

@override final  String? avatar;
@override final  String? bio;
@override final  String? learningGoal;
@override final  String? targetTrack;
@override final  int? experienceYears;

/// Create a copy of ProfileView
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileViewCopyWith<_ProfileView> get copyWith => __$ProfileViewCopyWithImpl<_ProfileView>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileViewToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileView&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.learningGoal, learningGoal) || other.learningGoal == learningGoal)&&(identical(other.targetTrack, targetTrack) || other.targetTrack == targetTrack)&&(identical(other.experienceYears, experienceYears) || other.experienceYears == experienceYears));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,avatar,bio,learningGoal,targetTrack,experienceYears);

@override
String toString() {
  return 'ProfileView(avatar: $avatar, bio: $bio, learningGoal: $learningGoal, targetTrack: $targetTrack, experienceYears: $experienceYears)';
}


}

/// @nodoc
abstract mixin class _$ProfileViewCopyWith<$Res> implements $ProfileViewCopyWith<$Res> {
  factory _$ProfileViewCopyWith(_ProfileView value, $Res Function(_ProfileView) _then) = __$ProfileViewCopyWithImpl;
@override @useResult
$Res call({
 String? avatar, String? bio, String? learningGoal, String? targetTrack, int? experienceYears
});




}
/// @nodoc
class __$ProfileViewCopyWithImpl<$Res>
    implements _$ProfileViewCopyWith<$Res> {
  __$ProfileViewCopyWithImpl(this._self, this._then);

  final _ProfileView _self;
  final $Res Function(_ProfileView) _then;

/// Create a copy of ProfileView
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? avatar = freezed,Object? bio = freezed,Object? learningGoal = freezed,Object? targetTrack = freezed,Object? experienceYears = freezed,}) {
  return _then(_ProfileView(
avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,learningGoal: freezed == learningGoal ? _self.learningGoal : learningGoal // ignore: cast_nullable_to_non_nullable
as String?,targetTrack: freezed == targetTrack ? _self.targetTrack : targetTrack // ignore: cast_nullable_to_non_nullable
as String?,experienceYears: freezed == experienceYears ? _self.experienceYears : experienceYears // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
