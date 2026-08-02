// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'community_report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CommunityReportResult {

 int get id; String get status;
/// Create a copy of CommunityReportResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommunityReportResultCopyWith<CommunityReportResult> get copyWith => _$CommunityReportResultCopyWithImpl<CommunityReportResult>(this as CommunityReportResult, _$identity);

  /// Serializes this CommunityReportResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommunityReportResult&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status);

@override
String toString() {
  return 'CommunityReportResult(id: $id, status: $status)';
}


}

/// @nodoc
abstract mixin class $CommunityReportResultCopyWith<$Res>  {
  factory $CommunityReportResultCopyWith(CommunityReportResult value, $Res Function(CommunityReportResult) _then) = _$CommunityReportResultCopyWithImpl;
@useResult
$Res call({
 int id, String status
});




}
/// @nodoc
class _$CommunityReportResultCopyWithImpl<$Res>
    implements $CommunityReportResultCopyWith<$Res> {
  _$CommunityReportResultCopyWithImpl(this._self, this._then);

  final CommunityReportResult _self;
  final $Res Function(CommunityReportResult) _then;

/// Create a copy of CommunityReportResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CommunityReportResult].
extension CommunityReportResultPatterns on CommunityReportResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommunityReportResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommunityReportResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommunityReportResult value)  $default,){
final _that = this;
switch (_that) {
case _CommunityReportResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommunityReportResult value)?  $default,){
final _that = this;
switch (_that) {
case _CommunityReportResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommunityReportResult() when $default != null:
return $default(_that.id,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String status)  $default,) {final _that = this;
switch (_that) {
case _CommunityReportResult():
return $default(_that.id,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String status)?  $default,) {final _that = this;
switch (_that) {
case _CommunityReportResult() when $default != null:
return $default(_that.id,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommunityReportResult implements CommunityReportResult {
  const _CommunityReportResult({this.id = 0, this.status = 'OPEN'});
  factory _CommunityReportResult.fromJson(Map<String, dynamic> json) => _$CommunityReportResultFromJson(json);

@override@JsonKey() final  int id;
@override@JsonKey() final  String status;

/// Create a copy of CommunityReportResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommunityReportResultCopyWith<_CommunityReportResult> get copyWith => __$CommunityReportResultCopyWithImpl<_CommunityReportResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommunityReportResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommunityReportResult&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status);

@override
String toString() {
  return 'CommunityReportResult(id: $id, status: $status)';
}


}

/// @nodoc
abstract mixin class _$CommunityReportResultCopyWith<$Res> implements $CommunityReportResultCopyWith<$Res> {
  factory _$CommunityReportResultCopyWith(_CommunityReportResult value, $Res Function(_CommunityReportResult) _then) = __$CommunityReportResultCopyWithImpl;
@override @useResult
$Res call({
 int id, String status
});




}
/// @nodoc
class __$CommunityReportResultCopyWithImpl<$Res>
    implements _$CommunityReportResultCopyWith<$Res> {
  __$CommunityReportResultCopyWithImpl(this._self, this._then);

  final _CommunityReportResult _self;
  final $Res Function(_CommunityReportResult) _then;

/// Create a copy of CommunityReportResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,}) {
  return _then(_CommunityReportResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
