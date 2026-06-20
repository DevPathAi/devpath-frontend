// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'path_sse_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PathSseEvent {

 String get stage; double get progress; String get message; int? get pathId;
/// Create a copy of PathSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PathSseEventCopyWith<PathSseEvent> get copyWith => _$PathSseEventCopyWithImpl<PathSseEvent>(this as PathSseEvent, _$identity);

  /// Serializes this PathSseEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathSseEvent&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.message, message) || other.message == message)&&(identical(other.pathId, pathId) || other.pathId == pathId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stage,progress,message,pathId);

@override
String toString() {
  return 'PathSseEvent(stage: $stage, progress: $progress, message: $message, pathId: $pathId)';
}


}

/// @nodoc
abstract mixin class $PathSseEventCopyWith<$Res>  {
  factory $PathSseEventCopyWith(PathSseEvent value, $Res Function(PathSseEvent) _then) = _$PathSseEventCopyWithImpl;
@useResult
$Res call({
 String stage, double progress, String message, int? pathId
});




}
/// @nodoc
class _$PathSseEventCopyWithImpl<$Res>
    implements $PathSseEventCopyWith<$Res> {
  _$PathSseEventCopyWithImpl(this._self, this._then);

  final PathSseEvent _self;
  final $Res Function(PathSseEvent) _then;

/// Create a copy of PathSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stage = null,Object? progress = null,Object? message = null,Object? pathId = freezed,}) {
  return _then(_self.copyWith(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,pathId: freezed == pathId ? _self.pathId : pathId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PathSseEvent].
extension PathSseEventPatterns on PathSseEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PathSseEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PathSseEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PathSseEvent value)  $default,){
final _that = this;
switch (_that) {
case _PathSseEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PathSseEvent value)?  $default,){
final _that = this;
switch (_that) {
case _PathSseEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String stage,  double progress,  String message,  int? pathId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PathSseEvent() when $default != null:
return $default(_that.stage,_that.progress,_that.message,_that.pathId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String stage,  double progress,  String message,  int? pathId)  $default,) {final _that = this;
switch (_that) {
case _PathSseEvent():
return $default(_that.stage,_that.progress,_that.message,_that.pathId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String stage,  double progress,  String message,  int? pathId)?  $default,) {final _that = this;
switch (_that) {
case _PathSseEvent() when $default != null:
return $default(_that.stage,_that.progress,_that.message,_that.pathId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PathSseEvent implements PathSseEvent {
  const _PathSseEvent({required this.stage, required this.progress, required this.message, this.pathId});
  factory _PathSseEvent.fromJson(Map<String, dynamic> json) => _$PathSseEventFromJson(json);

@override final  String stage;
@override final  double progress;
@override final  String message;
@override final  int? pathId;

/// Create a copy of PathSseEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PathSseEventCopyWith<_PathSseEvent> get copyWith => __$PathSseEventCopyWithImpl<_PathSseEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PathSseEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PathSseEvent&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.message, message) || other.message == message)&&(identical(other.pathId, pathId) || other.pathId == pathId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stage,progress,message,pathId);

@override
String toString() {
  return 'PathSseEvent(stage: $stage, progress: $progress, message: $message, pathId: $pathId)';
}


}

/// @nodoc
abstract mixin class _$PathSseEventCopyWith<$Res> implements $PathSseEventCopyWith<$Res> {
  factory _$PathSseEventCopyWith(_PathSseEvent value, $Res Function(_PathSseEvent) _then) = __$PathSseEventCopyWithImpl;
@override @useResult
$Res call({
 String stage, double progress, String message, int? pathId
});




}
/// @nodoc
class __$PathSseEventCopyWithImpl<$Res>
    implements _$PathSseEventCopyWith<$Res> {
  __$PathSseEventCopyWithImpl(this._self, this._then);

  final _PathSseEvent _self;
  final $Res Function(_PathSseEvent) _then;

/// Create a copy of PathSseEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stage = null,Object? progress = null,Object? message = null,Object? pathId = freezed,}) {
  return _then(_PathSseEvent(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,pathId: freezed == pathId ? _self.pathId : pathId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
