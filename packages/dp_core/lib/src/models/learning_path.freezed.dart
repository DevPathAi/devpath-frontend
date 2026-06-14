// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'learning_path.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LearningPath {

 String get rationale; List<PathWeek> get weeks;
/// Create a copy of LearningPath
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LearningPathCopyWith<LearningPath> get copyWith => _$LearningPathCopyWithImpl<LearningPath>(this as LearningPath, _$identity);

  /// Serializes this LearningPath to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LearningPath&&(identical(other.rationale, rationale) || other.rationale == rationale)&&const DeepCollectionEquality().equals(other.weeks, weeks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rationale,const DeepCollectionEquality().hash(weeks));

@override
String toString() {
  return 'LearningPath(rationale: $rationale, weeks: $weeks)';
}


}

/// @nodoc
abstract mixin class $LearningPathCopyWith<$Res>  {
  factory $LearningPathCopyWith(LearningPath value, $Res Function(LearningPath) _then) = _$LearningPathCopyWithImpl;
@useResult
$Res call({
 String rationale, List<PathWeek> weeks
});




}
/// @nodoc
class _$LearningPathCopyWithImpl<$Res>
    implements $LearningPathCopyWith<$Res> {
  _$LearningPathCopyWithImpl(this._self, this._then);

  final LearningPath _self;
  final $Res Function(LearningPath) _then;

/// Create a copy of LearningPath
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rationale = null,Object? weeks = null,}) {
  return _then(_self.copyWith(
rationale: null == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String,weeks: null == weeks ? _self.weeks : weeks // ignore: cast_nullable_to_non_nullable
as List<PathWeek>,
  ));
}

}


/// Adds pattern-matching-related methods to [LearningPath].
extension LearningPathPatterns on LearningPath {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LearningPath value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LearningPath() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LearningPath value)  $default,){
final _that = this;
switch (_that) {
case _LearningPath():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LearningPath value)?  $default,){
final _that = this;
switch (_that) {
case _LearningPath() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String rationale,  List<PathWeek> weeks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LearningPath() when $default != null:
return $default(_that.rationale,_that.weeks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String rationale,  List<PathWeek> weeks)  $default,) {final _that = this;
switch (_that) {
case _LearningPath():
return $default(_that.rationale,_that.weeks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String rationale,  List<PathWeek> weeks)?  $default,) {final _that = this;
switch (_that) {
case _LearningPath() when $default != null:
return $default(_that.rationale,_that.weeks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LearningPath implements LearningPath {
  const _LearningPath({required this.rationale, final  List<PathWeek> weeks = const <PathWeek>[]}): _weeks = weeks;
  factory _LearningPath.fromJson(Map<String, dynamic> json) => _$LearningPathFromJson(json);

@override final  String rationale;
 final  List<PathWeek> _weeks;
@override@JsonKey() List<PathWeek> get weeks {
  if (_weeks is EqualUnmodifiableListView) return _weeks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_weeks);
}


/// Create a copy of LearningPath
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LearningPathCopyWith<_LearningPath> get copyWith => __$LearningPathCopyWithImpl<_LearningPath>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LearningPathToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LearningPath&&(identical(other.rationale, rationale) || other.rationale == rationale)&&const DeepCollectionEquality().equals(other._weeks, _weeks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rationale,const DeepCollectionEquality().hash(_weeks));

@override
String toString() {
  return 'LearningPath(rationale: $rationale, weeks: $weeks)';
}


}

/// @nodoc
abstract mixin class _$LearningPathCopyWith<$Res> implements $LearningPathCopyWith<$Res> {
  factory _$LearningPathCopyWith(_LearningPath value, $Res Function(_LearningPath) _then) = __$LearningPathCopyWithImpl;
@override @useResult
$Res call({
 String rationale, List<PathWeek> weeks
});




}
/// @nodoc
class __$LearningPathCopyWithImpl<$Res>
    implements _$LearningPathCopyWith<$Res> {
  __$LearningPathCopyWithImpl(this._self, this._then);

  final _LearningPath _self;
  final $Res Function(_LearningPath) _then;

/// Create a copy of LearningPath
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rationale = null,Object? weeks = null,}) {
  return _then(_LearningPath(
rationale: null == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String,weeks: null == weeks ? _self._weeks : weeks // ignore: cast_nullable_to_non_nullable
as List<PathWeek>,
  ));
}


}


/// @nodoc
mixin _$PathWeek {

 int get week; String get title; List<WeeklyTask> get tasks;
/// Create a copy of PathWeek
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PathWeekCopyWith<PathWeek> get copyWith => _$PathWeekCopyWithImpl<PathWeek>(this as PathWeek, _$identity);

  /// Serializes this PathWeek to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWeek&&(identical(other.week, week) || other.week == week)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.tasks, tasks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,week,title,const DeepCollectionEquality().hash(tasks));

@override
String toString() {
  return 'PathWeek(week: $week, title: $title, tasks: $tasks)';
}


}

/// @nodoc
abstract mixin class $PathWeekCopyWith<$Res>  {
  factory $PathWeekCopyWith(PathWeek value, $Res Function(PathWeek) _then) = _$PathWeekCopyWithImpl;
@useResult
$Res call({
 int week, String title, List<WeeklyTask> tasks
});




}
/// @nodoc
class _$PathWeekCopyWithImpl<$Res>
    implements $PathWeekCopyWith<$Res> {
  _$PathWeekCopyWithImpl(this._self, this._then);

  final PathWeek _self;
  final $Res Function(PathWeek) _then;

/// Create a copy of PathWeek
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? week = null,Object? title = null,Object? tasks = null,}) {
  return _then(_self.copyWith(
week: null == week ? _self.week : week // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,tasks: null == tasks ? _self.tasks : tasks // ignore: cast_nullable_to_non_nullable
as List<WeeklyTask>,
  ));
}

}


/// Adds pattern-matching-related methods to [PathWeek].
extension PathWeekPatterns on PathWeek {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PathWeek value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PathWeek() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PathWeek value)  $default,){
final _that = this;
switch (_that) {
case _PathWeek():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PathWeek value)?  $default,){
final _that = this;
switch (_that) {
case _PathWeek() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int week,  String title,  List<WeeklyTask> tasks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PathWeek() when $default != null:
return $default(_that.week,_that.title,_that.tasks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int week,  String title,  List<WeeklyTask> tasks)  $default,) {final _that = this;
switch (_that) {
case _PathWeek():
return $default(_that.week,_that.title,_that.tasks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int week,  String title,  List<WeeklyTask> tasks)?  $default,) {final _that = this;
switch (_that) {
case _PathWeek() when $default != null:
return $default(_that.week,_that.title,_that.tasks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PathWeek implements PathWeek {
  const _PathWeek({required this.week, required this.title, final  List<WeeklyTask> tasks = const <WeeklyTask>[]}): _tasks = tasks;
  factory _PathWeek.fromJson(Map<String, dynamic> json) => _$PathWeekFromJson(json);

@override final  int week;
@override final  String title;
 final  List<WeeklyTask> _tasks;
@override@JsonKey() List<WeeklyTask> get tasks {
  if (_tasks is EqualUnmodifiableListView) return _tasks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tasks);
}


/// Create a copy of PathWeek
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PathWeekCopyWith<_PathWeek> get copyWith => __$PathWeekCopyWithImpl<_PathWeek>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PathWeekToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PathWeek&&(identical(other.week, week) || other.week == week)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._tasks, _tasks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,week,title,const DeepCollectionEquality().hash(_tasks));

@override
String toString() {
  return 'PathWeek(week: $week, title: $title, tasks: $tasks)';
}


}

/// @nodoc
abstract mixin class _$PathWeekCopyWith<$Res> implements $PathWeekCopyWith<$Res> {
  factory _$PathWeekCopyWith(_PathWeek value, $Res Function(_PathWeek) _then) = __$PathWeekCopyWithImpl;
@override @useResult
$Res call({
 int week, String title, List<WeeklyTask> tasks
});




}
/// @nodoc
class __$PathWeekCopyWithImpl<$Res>
    implements _$PathWeekCopyWith<$Res> {
  __$PathWeekCopyWithImpl(this._self, this._then);

  final _PathWeek _self;
  final $Res Function(_PathWeek) _then;

/// Create a copy of PathWeek
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? week = null,Object? title = null,Object? tasks = null,}) {
  return _then(_PathWeek(
week: null == week ? _self.week : week // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,tasks: null == tasks ? _self._tasks : tasks // ignore: cast_nullable_to_non_nullable
as List<WeeklyTask>,
  ));
}


}


/// @nodoc
mixin _$WeeklyTask {

 String get title; bool get done;
/// Create a copy of WeeklyTask
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeeklyTaskCopyWith<WeeklyTask> get copyWith => _$WeeklyTaskCopyWithImpl<WeeklyTask>(this as WeeklyTask, _$identity);

  /// Serializes this WeeklyTask to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeeklyTask&&(identical(other.title, title) || other.title == title)&&(identical(other.done, done) || other.done == done));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,done);

@override
String toString() {
  return 'WeeklyTask(title: $title, done: $done)';
}


}

/// @nodoc
abstract mixin class $WeeklyTaskCopyWith<$Res>  {
  factory $WeeklyTaskCopyWith(WeeklyTask value, $Res Function(WeeklyTask) _then) = _$WeeklyTaskCopyWithImpl;
@useResult
$Res call({
 String title, bool done
});




}
/// @nodoc
class _$WeeklyTaskCopyWithImpl<$Res>
    implements $WeeklyTaskCopyWith<$Res> {
  _$WeeklyTaskCopyWithImpl(this._self, this._then);

  final WeeklyTask _self;
  final $Res Function(WeeklyTask) _then;

/// Create a copy of WeeklyTask
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? done = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WeeklyTask].
extension WeeklyTaskPatterns on WeeklyTask {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WeeklyTask value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WeeklyTask() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WeeklyTask value)  $default,){
final _that = this;
switch (_that) {
case _WeeklyTask():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WeeklyTask value)?  $default,){
final _that = this;
switch (_that) {
case _WeeklyTask() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  bool done)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeeklyTask() when $default != null:
return $default(_that.title,_that.done);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  bool done)  $default,) {final _that = this;
switch (_that) {
case _WeeklyTask():
return $default(_that.title,_that.done);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  bool done)?  $default,) {final _that = this;
switch (_that) {
case _WeeklyTask() when $default != null:
return $default(_that.title,_that.done);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WeeklyTask implements WeeklyTask {
  const _WeeklyTask({required this.title, this.done = false});
  factory _WeeklyTask.fromJson(Map<String, dynamic> json) => _$WeeklyTaskFromJson(json);

@override final  String title;
@override@JsonKey() final  bool done;

/// Create a copy of WeeklyTask
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WeeklyTaskCopyWith<_WeeklyTask> get copyWith => __$WeeklyTaskCopyWithImpl<_WeeklyTask>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WeeklyTaskToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeeklyTask&&(identical(other.title, title) || other.title == title)&&(identical(other.done, done) || other.done == done));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,done);

@override
String toString() {
  return 'WeeklyTask(title: $title, done: $done)';
}


}

/// @nodoc
abstract mixin class _$WeeklyTaskCopyWith<$Res> implements $WeeklyTaskCopyWith<$Res> {
  factory _$WeeklyTaskCopyWith(_WeeklyTask value, $Res Function(_WeeklyTask) _then) = __$WeeklyTaskCopyWithImpl;
@override @useResult
$Res call({
 String title, bool done
});




}
/// @nodoc
class __$WeeklyTaskCopyWithImpl<$Res>
    implements _$WeeklyTaskCopyWith<$Res> {
  __$WeeklyTaskCopyWithImpl(this._self, this._then);

  final _WeeklyTask _self;
  final $Res Function(_WeeklyTask) _then;

/// Create a copy of WeeklyTask
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? done = null,}) {
  return _then(_WeeklyTask(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
