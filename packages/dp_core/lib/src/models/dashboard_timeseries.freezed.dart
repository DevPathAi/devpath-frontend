// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_timeseries.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DailyActivity {

 String get date; int get completedCount;
/// Create a copy of DailyActivity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyActivityCopyWith<DailyActivity> get copyWith => _$DailyActivityCopyWithImpl<DailyActivity>(this as DailyActivity, _$identity);

  /// Serializes this DailyActivity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyActivity&&(identical(other.date, date) || other.date == date)&&(identical(other.completedCount, completedCount) || other.completedCount == completedCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,completedCount);

@override
String toString() {
  return 'DailyActivity(date: $date, completedCount: $completedCount)';
}


}

/// @nodoc
abstract mixin class $DailyActivityCopyWith<$Res>  {
  factory $DailyActivityCopyWith(DailyActivity value, $Res Function(DailyActivity) _then) = _$DailyActivityCopyWithImpl;
@useResult
$Res call({
 String date, int completedCount
});




}
/// @nodoc
class _$DailyActivityCopyWithImpl<$Res>
    implements $DailyActivityCopyWith<$Res> {
  _$DailyActivityCopyWithImpl(this._self, this._then);

  final DailyActivity _self;
  final $Res Function(DailyActivity) _then;

/// Create a copy of DailyActivity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? completedCount = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyActivity].
extension DailyActivityPatterns on DailyActivity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyActivity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyActivity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyActivity value)  $default,){
final _that = this;
switch (_that) {
case _DailyActivity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyActivity value)?  $default,){
final _that = this;
switch (_that) {
case _DailyActivity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  int completedCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyActivity() when $default != null:
return $default(_that.date,_that.completedCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  int completedCount)  $default,) {final _that = this;
switch (_that) {
case _DailyActivity():
return $default(_that.date,_that.completedCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  int completedCount)?  $default,) {final _that = this;
switch (_that) {
case _DailyActivity() when $default != null:
return $default(_that.date,_that.completedCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyActivity implements DailyActivity {
  const _DailyActivity({required this.date, this.completedCount = 0});
  factory _DailyActivity.fromJson(Map<String, dynamic> json) => _$DailyActivityFromJson(json);

@override final  String date;
@override@JsonKey() final  int completedCount;

/// Create a copy of DailyActivity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyActivityCopyWith<_DailyActivity> get copyWith => __$DailyActivityCopyWithImpl<_DailyActivity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyActivityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyActivity&&(identical(other.date, date) || other.date == date)&&(identical(other.completedCount, completedCount) || other.completedCount == completedCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,completedCount);

@override
String toString() {
  return 'DailyActivity(date: $date, completedCount: $completedCount)';
}


}

/// @nodoc
abstract mixin class _$DailyActivityCopyWith<$Res> implements $DailyActivityCopyWith<$Res> {
  factory _$DailyActivityCopyWith(_DailyActivity value, $Res Function(_DailyActivity) _then) = __$DailyActivityCopyWithImpl;
@override @useResult
$Res call({
 String date, int completedCount
});




}
/// @nodoc
class __$DailyActivityCopyWithImpl<$Res>
    implements _$DailyActivityCopyWith<$Res> {
  __$DailyActivityCopyWithImpl(this._self, this._then);

  final _DailyActivity _self;
  final $Res Function(_DailyActivity) _then;

/// Create a copy of DailyActivity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? completedCount = null,}) {
  return _then(_DailyActivity(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ProgressPoint {

 String get date; int get percent;
/// Create a copy of ProgressPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProgressPointCopyWith<ProgressPoint> get copyWith => _$ProgressPointCopyWithImpl<ProgressPoint>(this as ProgressPoint, _$identity);

  /// Serializes this ProgressPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProgressPoint&&(identical(other.date, date) || other.date == date)&&(identical(other.percent, percent) || other.percent == percent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,percent);

@override
String toString() {
  return 'ProgressPoint(date: $date, percent: $percent)';
}


}

/// @nodoc
abstract mixin class $ProgressPointCopyWith<$Res>  {
  factory $ProgressPointCopyWith(ProgressPoint value, $Res Function(ProgressPoint) _then) = _$ProgressPointCopyWithImpl;
@useResult
$Res call({
 String date, int percent
});




}
/// @nodoc
class _$ProgressPointCopyWithImpl<$Res>
    implements $ProgressPointCopyWith<$Res> {
  _$ProgressPointCopyWithImpl(this._self, this._then);

  final ProgressPoint _self;
  final $Res Function(ProgressPoint) _then;

/// Create a copy of ProgressPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? percent = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ProgressPoint].
extension ProgressPointPatterns on ProgressPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProgressPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProgressPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProgressPoint value)  $default,){
final _that = this;
switch (_that) {
case _ProgressPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProgressPoint value)?  $default,){
final _that = this;
switch (_that) {
case _ProgressPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  int percent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProgressPoint() when $default != null:
return $default(_that.date,_that.percent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  int percent)  $default,) {final _that = this;
switch (_that) {
case _ProgressPoint():
return $default(_that.date,_that.percent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  int percent)?  $default,) {final _that = this;
switch (_that) {
case _ProgressPoint() when $default != null:
return $default(_that.date,_that.percent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProgressPoint implements ProgressPoint {
  const _ProgressPoint({required this.date, this.percent = 0});
  factory _ProgressPoint.fromJson(Map<String, dynamic> json) => _$ProgressPointFromJson(json);

@override final  String date;
@override@JsonKey() final  int percent;

/// Create a copy of ProgressPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProgressPointCopyWith<_ProgressPoint> get copyWith => __$ProgressPointCopyWithImpl<_ProgressPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProgressPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProgressPoint&&(identical(other.date, date) || other.date == date)&&(identical(other.percent, percent) || other.percent == percent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,percent);

@override
String toString() {
  return 'ProgressPoint(date: $date, percent: $percent)';
}


}

/// @nodoc
abstract mixin class _$ProgressPointCopyWith<$Res> implements $ProgressPointCopyWith<$Res> {
  factory _$ProgressPointCopyWith(_ProgressPoint value, $Res Function(_ProgressPoint) _then) = __$ProgressPointCopyWithImpl;
@override @useResult
$Res call({
 String date, int percent
});




}
/// @nodoc
class __$ProgressPointCopyWithImpl<$Res>
    implements _$ProgressPointCopyWith<$Res> {
  __$ProgressPointCopyWithImpl(this._self, this._then);

  final _ProgressPoint _self;
  final $Res Function(_ProgressPoint) _then;

/// Create a copy of ProgressPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? percent = null,}) {
  return _then(_ProgressPoint(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
