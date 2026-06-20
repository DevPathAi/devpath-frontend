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

 int get pathId; String get track; int get totalWeeks; String get rationale; PathDiagnosis? get diagnosis; List<PathMilestone> get milestones;
/// Create a copy of LearningPath
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LearningPathCopyWith<LearningPath> get copyWith => _$LearningPathCopyWithImpl<LearningPath>(this as LearningPath, _$identity);

  /// Serializes this LearningPath to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LearningPath&&(identical(other.pathId, pathId) || other.pathId == pathId)&&(identical(other.track, track) || other.track == track)&&(identical(other.totalWeeks, totalWeeks) || other.totalWeeks == totalWeeks)&&(identical(other.rationale, rationale) || other.rationale == rationale)&&(identical(other.diagnosis, diagnosis) || other.diagnosis == diagnosis)&&const DeepCollectionEquality().equals(other.milestones, milestones));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pathId,track,totalWeeks,rationale,diagnosis,const DeepCollectionEquality().hash(milestones));

@override
String toString() {
  return 'LearningPath(pathId: $pathId, track: $track, totalWeeks: $totalWeeks, rationale: $rationale, diagnosis: $diagnosis, milestones: $milestones)';
}


}

/// @nodoc
abstract mixin class $LearningPathCopyWith<$Res>  {
  factory $LearningPathCopyWith(LearningPath value, $Res Function(LearningPath) _then) = _$LearningPathCopyWithImpl;
@useResult
$Res call({
 int pathId, String track, int totalWeeks, String rationale, PathDiagnosis? diagnosis, List<PathMilestone> milestones
});


$PathDiagnosisCopyWith<$Res>? get diagnosis;

}
/// @nodoc
class _$LearningPathCopyWithImpl<$Res>
    implements $LearningPathCopyWith<$Res> {
  _$LearningPathCopyWithImpl(this._self, this._then);

  final LearningPath _self;
  final $Res Function(LearningPath) _then;

/// Create a copy of LearningPath
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pathId = null,Object? track = null,Object? totalWeeks = null,Object? rationale = null,Object? diagnosis = freezed,Object? milestones = null,}) {
  return _then(_self.copyWith(
pathId: null == pathId ? _self.pathId : pathId // ignore: cast_nullable_to_non_nullable
as int,track: null == track ? _self.track : track // ignore: cast_nullable_to_non_nullable
as String,totalWeeks: null == totalWeeks ? _self.totalWeeks : totalWeeks // ignore: cast_nullable_to_non_nullable
as int,rationale: null == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String,diagnosis: freezed == diagnosis ? _self.diagnosis : diagnosis // ignore: cast_nullable_to_non_nullable
as PathDiagnosis?,milestones: null == milestones ? _self.milestones : milestones // ignore: cast_nullable_to_non_nullable
as List<PathMilestone>,
  ));
}
/// Create a copy of LearningPath
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PathDiagnosisCopyWith<$Res>? get diagnosis {
    if (_self.diagnosis == null) {
    return null;
  }

  return $PathDiagnosisCopyWith<$Res>(_self.diagnosis!, (value) {
    return _then(_self.copyWith(diagnosis: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int pathId,  String track,  int totalWeeks,  String rationale,  PathDiagnosis? diagnosis,  List<PathMilestone> milestones)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LearningPath() when $default != null:
return $default(_that.pathId,_that.track,_that.totalWeeks,_that.rationale,_that.diagnosis,_that.milestones);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int pathId,  String track,  int totalWeeks,  String rationale,  PathDiagnosis? diagnosis,  List<PathMilestone> milestones)  $default,) {final _that = this;
switch (_that) {
case _LearningPath():
return $default(_that.pathId,_that.track,_that.totalWeeks,_that.rationale,_that.diagnosis,_that.milestones);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int pathId,  String track,  int totalWeeks,  String rationale,  PathDiagnosis? diagnosis,  List<PathMilestone> milestones)?  $default,) {final _that = this;
switch (_that) {
case _LearningPath() when $default != null:
return $default(_that.pathId,_that.track,_that.totalWeeks,_that.rationale,_that.diagnosis,_that.milestones);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LearningPath implements LearningPath {
  const _LearningPath({required this.pathId, required this.track, required this.totalWeeks, required this.rationale, this.diagnosis, final  List<PathMilestone> milestones = const <PathMilestone>[]}): _milestones = milestones;
  factory _LearningPath.fromJson(Map<String, dynamic> json) => _$LearningPathFromJson(json);

@override final  int pathId;
@override final  String track;
@override final  int totalWeeks;
@override final  String rationale;
@override final  PathDiagnosis? diagnosis;
 final  List<PathMilestone> _milestones;
@override@JsonKey() List<PathMilestone> get milestones {
  if (_milestones is EqualUnmodifiableListView) return _milestones;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_milestones);
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LearningPath&&(identical(other.pathId, pathId) || other.pathId == pathId)&&(identical(other.track, track) || other.track == track)&&(identical(other.totalWeeks, totalWeeks) || other.totalWeeks == totalWeeks)&&(identical(other.rationale, rationale) || other.rationale == rationale)&&(identical(other.diagnosis, diagnosis) || other.diagnosis == diagnosis)&&const DeepCollectionEquality().equals(other._milestones, _milestones));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pathId,track,totalWeeks,rationale,diagnosis,const DeepCollectionEquality().hash(_milestones));

@override
String toString() {
  return 'LearningPath(pathId: $pathId, track: $track, totalWeeks: $totalWeeks, rationale: $rationale, diagnosis: $diagnosis, milestones: $milestones)';
}


}

/// @nodoc
abstract mixin class _$LearningPathCopyWith<$Res> implements $LearningPathCopyWith<$Res> {
  factory _$LearningPathCopyWith(_LearningPath value, $Res Function(_LearningPath) _then) = __$LearningPathCopyWithImpl;
@override @useResult
$Res call({
 int pathId, String track, int totalWeeks, String rationale, PathDiagnosis? diagnosis, List<PathMilestone> milestones
});


@override $PathDiagnosisCopyWith<$Res>? get diagnosis;

}
/// @nodoc
class __$LearningPathCopyWithImpl<$Res>
    implements _$LearningPathCopyWith<$Res> {
  __$LearningPathCopyWithImpl(this._self, this._then);

  final _LearningPath _self;
  final $Res Function(_LearningPath) _then;

/// Create a copy of LearningPath
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pathId = null,Object? track = null,Object? totalWeeks = null,Object? rationale = null,Object? diagnosis = freezed,Object? milestones = null,}) {
  return _then(_LearningPath(
pathId: null == pathId ? _self.pathId : pathId // ignore: cast_nullable_to_non_nullable
as int,track: null == track ? _self.track : track // ignore: cast_nullable_to_non_nullable
as String,totalWeeks: null == totalWeeks ? _self.totalWeeks : totalWeeks // ignore: cast_nullable_to_non_nullable
as int,rationale: null == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String,diagnosis: freezed == diagnosis ? _self.diagnosis : diagnosis // ignore: cast_nullable_to_non_nullable
as PathDiagnosis?,milestones: null == milestones ? _self._milestones : milestones // ignore: cast_nullable_to_non_nullable
as List<PathMilestone>,
  ));
}

/// Create a copy of LearningPath
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PathDiagnosisCopyWith<$Res>? get diagnosis {
    if (_self.diagnosis == null) {
    return null;
  }

  return $PathDiagnosisCopyWith<$Res>(_self.diagnosis!, (value) {
    return _then(_self.copyWith(diagnosis: value));
  });
}
}


/// @nodoc
mixin _$PathDiagnosis {

 String get diagnosedLevel; List<String> get strengthConcepts; List<String> get weaknessConcepts;
/// Create a copy of PathDiagnosis
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PathDiagnosisCopyWith<PathDiagnosis> get copyWith => _$PathDiagnosisCopyWithImpl<PathDiagnosis>(this as PathDiagnosis, _$identity);

  /// Serializes this PathDiagnosis to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathDiagnosis&&(identical(other.diagnosedLevel, diagnosedLevel) || other.diagnosedLevel == diagnosedLevel)&&const DeepCollectionEquality().equals(other.strengthConcepts, strengthConcepts)&&const DeepCollectionEquality().equals(other.weaknessConcepts, weaknessConcepts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,diagnosedLevel,const DeepCollectionEquality().hash(strengthConcepts),const DeepCollectionEquality().hash(weaknessConcepts));

@override
String toString() {
  return 'PathDiagnosis(diagnosedLevel: $diagnosedLevel, strengthConcepts: $strengthConcepts, weaknessConcepts: $weaknessConcepts)';
}


}

/// @nodoc
abstract mixin class $PathDiagnosisCopyWith<$Res>  {
  factory $PathDiagnosisCopyWith(PathDiagnosis value, $Res Function(PathDiagnosis) _then) = _$PathDiagnosisCopyWithImpl;
@useResult
$Res call({
 String diagnosedLevel, List<String> strengthConcepts, List<String> weaknessConcepts
});




}
/// @nodoc
class _$PathDiagnosisCopyWithImpl<$Res>
    implements $PathDiagnosisCopyWith<$Res> {
  _$PathDiagnosisCopyWithImpl(this._self, this._then);

  final PathDiagnosis _self;
  final $Res Function(PathDiagnosis) _then;

/// Create a copy of PathDiagnosis
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? diagnosedLevel = null,Object? strengthConcepts = null,Object? weaknessConcepts = null,}) {
  return _then(_self.copyWith(
diagnosedLevel: null == diagnosedLevel ? _self.diagnosedLevel : diagnosedLevel // ignore: cast_nullable_to_non_nullable
as String,strengthConcepts: null == strengthConcepts ? _self.strengthConcepts : strengthConcepts // ignore: cast_nullable_to_non_nullable
as List<String>,weaknessConcepts: null == weaknessConcepts ? _self.weaknessConcepts : weaknessConcepts // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [PathDiagnosis].
extension PathDiagnosisPatterns on PathDiagnosis {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PathDiagnosis value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PathDiagnosis() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PathDiagnosis value)  $default,){
final _that = this;
switch (_that) {
case _PathDiagnosis():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PathDiagnosis value)?  $default,){
final _that = this;
switch (_that) {
case _PathDiagnosis() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String diagnosedLevel,  List<String> strengthConcepts,  List<String> weaknessConcepts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PathDiagnosis() when $default != null:
return $default(_that.diagnosedLevel,_that.strengthConcepts,_that.weaknessConcepts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String diagnosedLevel,  List<String> strengthConcepts,  List<String> weaknessConcepts)  $default,) {final _that = this;
switch (_that) {
case _PathDiagnosis():
return $default(_that.diagnosedLevel,_that.strengthConcepts,_that.weaknessConcepts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String diagnosedLevel,  List<String> strengthConcepts,  List<String> weaknessConcepts)?  $default,) {final _that = this;
switch (_that) {
case _PathDiagnosis() when $default != null:
return $default(_that.diagnosedLevel,_that.strengthConcepts,_that.weaknessConcepts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PathDiagnosis implements PathDiagnosis {
  const _PathDiagnosis({required this.diagnosedLevel, final  List<String> strengthConcepts = const <String>[], final  List<String> weaknessConcepts = const <String>[]}): _strengthConcepts = strengthConcepts,_weaknessConcepts = weaknessConcepts;
  factory _PathDiagnosis.fromJson(Map<String, dynamic> json) => _$PathDiagnosisFromJson(json);

@override final  String diagnosedLevel;
 final  List<String> _strengthConcepts;
@override@JsonKey() List<String> get strengthConcepts {
  if (_strengthConcepts is EqualUnmodifiableListView) return _strengthConcepts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_strengthConcepts);
}

 final  List<String> _weaknessConcepts;
@override@JsonKey() List<String> get weaknessConcepts {
  if (_weaknessConcepts is EqualUnmodifiableListView) return _weaknessConcepts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_weaknessConcepts);
}


/// Create a copy of PathDiagnosis
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PathDiagnosisCopyWith<_PathDiagnosis> get copyWith => __$PathDiagnosisCopyWithImpl<_PathDiagnosis>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PathDiagnosisToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PathDiagnosis&&(identical(other.diagnosedLevel, diagnosedLevel) || other.diagnosedLevel == diagnosedLevel)&&const DeepCollectionEquality().equals(other._strengthConcepts, _strengthConcepts)&&const DeepCollectionEquality().equals(other._weaknessConcepts, _weaknessConcepts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,diagnosedLevel,const DeepCollectionEquality().hash(_strengthConcepts),const DeepCollectionEquality().hash(_weaknessConcepts));

@override
String toString() {
  return 'PathDiagnosis(diagnosedLevel: $diagnosedLevel, strengthConcepts: $strengthConcepts, weaknessConcepts: $weaknessConcepts)';
}


}

/// @nodoc
abstract mixin class _$PathDiagnosisCopyWith<$Res> implements $PathDiagnosisCopyWith<$Res> {
  factory _$PathDiagnosisCopyWith(_PathDiagnosis value, $Res Function(_PathDiagnosis) _then) = __$PathDiagnosisCopyWithImpl;
@override @useResult
$Res call({
 String diagnosedLevel, List<String> strengthConcepts, List<String> weaknessConcepts
});




}
/// @nodoc
class __$PathDiagnosisCopyWithImpl<$Res>
    implements _$PathDiagnosisCopyWith<$Res> {
  __$PathDiagnosisCopyWithImpl(this._self, this._then);

  final _PathDiagnosis _self;
  final $Res Function(_PathDiagnosis) _then;

/// Create a copy of PathDiagnosis
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? diagnosedLevel = null,Object? strengthConcepts = null,Object? weaknessConcepts = null,}) {
  return _then(_PathDiagnosis(
diagnosedLevel: null == diagnosedLevel ? _self.diagnosedLevel : diagnosedLevel // ignore: cast_nullable_to_non_nullable
as String,strengthConcepts: null == strengthConcepts ? _self._strengthConcepts : strengthConcepts // ignore: cast_nullable_to_non_nullable
as List<String>,weaknessConcepts: null == weaknessConcepts ? _self._weaknessConcepts : weaknessConcepts // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$PathMilestone {

 int get weekNum; String get title; String get goalDescription; List<String> get targetSkills; int get estimatedHours; String get whyThisOrder; String get expectedOutcome; bool get locked; List<WeeklyTask> get tasks;
/// Create a copy of PathMilestone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PathMilestoneCopyWith<PathMilestone> get copyWith => _$PathMilestoneCopyWithImpl<PathMilestone>(this as PathMilestone, _$identity);

  /// Serializes this PathMilestone to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathMilestone&&(identical(other.weekNum, weekNum) || other.weekNum == weekNum)&&(identical(other.title, title) || other.title == title)&&(identical(other.goalDescription, goalDescription) || other.goalDescription == goalDescription)&&const DeepCollectionEquality().equals(other.targetSkills, targetSkills)&&(identical(other.estimatedHours, estimatedHours) || other.estimatedHours == estimatedHours)&&(identical(other.whyThisOrder, whyThisOrder) || other.whyThisOrder == whyThisOrder)&&(identical(other.expectedOutcome, expectedOutcome) || other.expectedOutcome == expectedOutcome)&&(identical(other.locked, locked) || other.locked == locked)&&const DeepCollectionEquality().equals(other.tasks, tasks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,weekNum,title,goalDescription,const DeepCollectionEquality().hash(targetSkills),estimatedHours,whyThisOrder,expectedOutcome,locked,const DeepCollectionEquality().hash(tasks));

@override
String toString() {
  return 'PathMilestone(weekNum: $weekNum, title: $title, goalDescription: $goalDescription, targetSkills: $targetSkills, estimatedHours: $estimatedHours, whyThisOrder: $whyThisOrder, expectedOutcome: $expectedOutcome, locked: $locked, tasks: $tasks)';
}


}

/// @nodoc
abstract mixin class $PathMilestoneCopyWith<$Res>  {
  factory $PathMilestoneCopyWith(PathMilestone value, $Res Function(PathMilestone) _then) = _$PathMilestoneCopyWithImpl;
@useResult
$Res call({
 int weekNum, String title, String goalDescription, List<String> targetSkills, int estimatedHours, String whyThisOrder, String expectedOutcome, bool locked, List<WeeklyTask> tasks
});




}
/// @nodoc
class _$PathMilestoneCopyWithImpl<$Res>
    implements $PathMilestoneCopyWith<$Res> {
  _$PathMilestoneCopyWithImpl(this._self, this._then);

  final PathMilestone _self;
  final $Res Function(PathMilestone) _then;

/// Create a copy of PathMilestone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? weekNum = null,Object? title = null,Object? goalDescription = null,Object? targetSkills = null,Object? estimatedHours = null,Object? whyThisOrder = null,Object? expectedOutcome = null,Object? locked = null,Object? tasks = null,}) {
  return _then(_self.copyWith(
weekNum: null == weekNum ? _self.weekNum : weekNum // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,goalDescription: null == goalDescription ? _self.goalDescription : goalDescription // ignore: cast_nullable_to_non_nullable
as String,targetSkills: null == targetSkills ? _self.targetSkills : targetSkills // ignore: cast_nullable_to_non_nullable
as List<String>,estimatedHours: null == estimatedHours ? _self.estimatedHours : estimatedHours // ignore: cast_nullable_to_non_nullable
as int,whyThisOrder: null == whyThisOrder ? _self.whyThisOrder : whyThisOrder // ignore: cast_nullable_to_non_nullable
as String,expectedOutcome: null == expectedOutcome ? _self.expectedOutcome : expectedOutcome // ignore: cast_nullable_to_non_nullable
as String,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,tasks: null == tasks ? _self.tasks : tasks // ignore: cast_nullable_to_non_nullable
as List<WeeklyTask>,
  ));
}

}


/// Adds pattern-matching-related methods to [PathMilestone].
extension PathMilestonePatterns on PathMilestone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PathMilestone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PathMilestone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PathMilestone value)  $default,){
final _that = this;
switch (_that) {
case _PathMilestone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PathMilestone value)?  $default,){
final _that = this;
switch (_that) {
case _PathMilestone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int weekNum,  String title,  String goalDescription,  List<String> targetSkills,  int estimatedHours,  String whyThisOrder,  String expectedOutcome,  bool locked,  List<WeeklyTask> tasks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PathMilestone() when $default != null:
return $default(_that.weekNum,_that.title,_that.goalDescription,_that.targetSkills,_that.estimatedHours,_that.whyThisOrder,_that.expectedOutcome,_that.locked,_that.tasks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int weekNum,  String title,  String goalDescription,  List<String> targetSkills,  int estimatedHours,  String whyThisOrder,  String expectedOutcome,  bool locked,  List<WeeklyTask> tasks)  $default,) {final _that = this;
switch (_that) {
case _PathMilestone():
return $default(_that.weekNum,_that.title,_that.goalDescription,_that.targetSkills,_that.estimatedHours,_that.whyThisOrder,_that.expectedOutcome,_that.locked,_that.tasks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int weekNum,  String title,  String goalDescription,  List<String> targetSkills,  int estimatedHours,  String whyThisOrder,  String expectedOutcome,  bool locked,  List<WeeklyTask> tasks)?  $default,) {final _that = this;
switch (_that) {
case _PathMilestone() when $default != null:
return $default(_that.weekNum,_that.title,_that.goalDescription,_that.targetSkills,_that.estimatedHours,_that.whyThisOrder,_that.expectedOutcome,_that.locked,_that.tasks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PathMilestone implements PathMilestone {
  const _PathMilestone({required this.weekNum, required this.title, required this.goalDescription, final  List<String> targetSkills = const <String>[], required this.estimatedHours, required this.whyThisOrder, required this.expectedOutcome, this.locked = false, final  List<WeeklyTask> tasks = const <WeeklyTask>[]}): _targetSkills = targetSkills,_tasks = tasks;
  factory _PathMilestone.fromJson(Map<String, dynamic> json) => _$PathMilestoneFromJson(json);

@override final  int weekNum;
@override final  String title;
@override final  String goalDescription;
 final  List<String> _targetSkills;
@override@JsonKey() List<String> get targetSkills {
  if (_targetSkills is EqualUnmodifiableListView) return _targetSkills;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_targetSkills);
}

@override final  int estimatedHours;
@override final  String whyThisOrder;
@override final  String expectedOutcome;
@override@JsonKey() final  bool locked;
 final  List<WeeklyTask> _tasks;
@override@JsonKey() List<WeeklyTask> get tasks {
  if (_tasks is EqualUnmodifiableListView) return _tasks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tasks);
}


/// Create a copy of PathMilestone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PathMilestoneCopyWith<_PathMilestone> get copyWith => __$PathMilestoneCopyWithImpl<_PathMilestone>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PathMilestoneToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PathMilestone&&(identical(other.weekNum, weekNum) || other.weekNum == weekNum)&&(identical(other.title, title) || other.title == title)&&(identical(other.goalDescription, goalDescription) || other.goalDescription == goalDescription)&&const DeepCollectionEquality().equals(other._targetSkills, _targetSkills)&&(identical(other.estimatedHours, estimatedHours) || other.estimatedHours == estimatedHours)&&(identical(other.whyThisOrder, whyThisOrder) || other.whyThisOrder == whyThisOrder)&&(identical(other.expectedOutcome, expectedOutcome) || other.expectedOutcome == expectedOutcome)&&(identical(other.locked, locked) || other.locked == locked)&&const DeepCollectionEquality().equals(other._tasks, _tasks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,weekNum,title,goalDescription,const DeepCollectionEquality().hash(_targetSkills),estimatedHours,whyThisOrder,expectedOutcome,locked,const DeepCollectionEquality().hash(_tasks));

@override
String toString() {
  return 'PathMilestone(weekNum: $weekNum, title: $title, goalDescription: $goalDescription, targetSkills: $targetSkills, estimatedHours: $estimatedHours, whyThisOrder: $whyThisOrder, expectedOutcome: $expectedOutcome, locked: $locked, tasks: $tasks)';
}


}

/// @nodoc
abstract mixin class _$PathMilestoneCopyWith<$Res> implements $PathMilestoneCopyWith<$Res> {
  factory _$PathMilestoneCopyWith(_PathMilestone value, $Res Function(_PathMilestone) _then) = __$PathMilestoneCopyWithImpl;
@override @useResult
$Res call({
 int weekNum, String title, String goalDescription, List<String> targetSkills, int estimatedHours, String whyThisOrder, String expectedOutcome, bool locked, List<WeeklyTask> tasks
});




}
/// @nodoc
class __$PathMilestoneCopyWithImpl<$Res>
    implements _$PathMilestoneCopyWith<$Res> {
  __$PathMilestoneCopyWithImpl(this._self, this._then);

  final _PathMilestone _self;
  final $Res Function(_PathMilestone) _then;

/// Create a copy of PathMilestone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? weekNum = null,Object? title = null,Object? goalDescription = null,Object? targetSkills = null,Object? estimatedHours = null,Object? whyThisOrder = null,Object? expectedOutcome = null,Object? locked = null,Object? tasks = null,}) {
  return _then(_PathMilestone(
weekNum: null == weekNum ? _self.weekNum : weekNum // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,goalDescription: null == goalDescription ? _self.goalDescription : goalDescription // ignore: cast_nullable_to_non_nullable
as String,targetSkills: null == targetSkills ? _self._targetSkills : targetSkills // ignore: cast_nullable_to_non_nullable
as List<String>,estimatedHours: null == estimatedHours ? _self.estimatedHours : estimatedHours // ignore: cast_nullable_to_non_nullable
as int,whyThisOrder: null == whyThisOrder ? _self.whyThisOrder : whyThisOrder // ignore: cast_nullable_to_non_nullable
as String,expectedOutcome: null == expectedOutcome ? _self.expectedOutcome : expectedOutcome // ignore: cast_nullable_to_non_nullable
as String,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,tasks: null == tasks ? _self._tasks : tasks // ignore: cast_nullable_to_non_nullable
as List<WeeklyTask>,
  ));
}


}


/// @nodoc
mixin _$WeeklyTask {

 int get orderNum; String get taskType; String get title; bool get required; int? get contentId; String? get contentSlug; bool get completed;
/// Create a copy of WeeklyTask
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeeklyTaskCopyWith<WeeklyTask> get copyWith => _$WeeklyTaskCopyWithImpl<WeeklyTask>(this as WeeklyTask, _$identity);

  /// Serializes this WeeklyTask to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeeklyTask&&(identical(other.orderNum, orderNum) || other.orderNum == orderNum)&&(identical(other.taskType, taskType) || other.taskType == taskType)&&(identical(other.title, title) || other.title == title)&&(identical(other.required, required) || other.required == required)&&(identical(other.contentId, contentId) || other.contentId == contentId)&&(identical(other.contentSlug, contentSlug) || other.contentSlug == contentSlug)&&(identical(other.completed, completed) || other.completed == completed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderNum,taskType,title,required,contentId,contentSlug,completed);

@override
String toString() {
  return 'WeeklyTask(orderNum: $orderNum, taskType: $taskType, title: $title, required: $required, contentId: $contentId, contentSlug: $contentSlug, completed: $completed)';
}


}

/// @nodoc
abstract mixin class $WeeklyTaskCopyWith<$Res>  {
  factory $WeeklyTaskCopyWith(WeeklyTask value, $Res Function(WeeklyTask) _then) = _$WeeklyTaskCopyWithImpl;
@useResult
$Res call({
 int orderNum, String taskType, String title, bool required, int? contentId, String? contentSlug, bool completed
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
@pragma('vm:prefer-inline') @override $Res call({Object? orderNum = null,Object? taskType = null,Object? title = null,Object? required = null,Object? contentId = freezed,Object? contentSlug = freezed,Object? completed = null,}) {
  return _then(_self.copyWith(
orderNum: null == orderNum ? _self.orderNum : orderNum // ignore: cast_nullable_to_non_nullable
as int,taskType: null == taskType ? _self.taskType : taskType // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,contentId: freezed == contentId ? _self.contentId : contentId // ignore: cast_nullable_to_non_nullable
as int?,contentSlug: freezed == contentSlug ? _self.contentSlug : contentSlug // ignore: cast_nullable_to_non_nullable
as String?,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int orderNum,  String taskType,  String title,  bool required,  int? contentId,  String? contentSlug,  bool completed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeeklyTask() when $default != null:
return $default(_that.orderNum,_that.taskType,_that.title,_that.required,_that.contentId,_that.contentSlug,_that.completed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int orderNum,  String taskType,  String title,  bool required,  int? contentId,  String? contentSlug,  bool completed)  $default,) {final _that = this;
switch (_that) {
case _WeeklyTask():
return $default(_that.orderNum,_that.taskType,_that.title,_that.required,_that.contentId,_that.contentSlug,_that.completed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int orderNum,  String taskType,  String title,  bool required,  int? contentId,  String? contentSlug,  bool completed)?  $default,) {final _that = this;
switch (_that) {
case _WeeklyTask() when $default != null:
return $default(_that.orderNum,_that.taskType,_that.title,_that.required,_that.contentId,_that.contentSlug,_that.completed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WeeklyTask implements WeeklyTask {
  const _WeeklyTask({required this.orderNum, required this.taskType, required this.title, this.required = false, this.contentId, this.contentSlug, this.completed = false});
  factory _WeeklyTask.fromJson(Map<String, dynamic> json) => _$WeeklyTaskFromJson(json);

@override final  int orderNum;
@override final  String taskType;
@override final  String title;
@override@JsonKey() final  bool required;
@override final  int? contentId;
@override final  String? contentSlug;
@override@JsonKey() final  bool completed;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeeklyTask&&(identical(other.orderNum, orderNum) || other.orderNum == orderNum)&&(identical(other.taskType, taskType) || other.taskType == taskType)&&(identical(other.title, title) || other.title == title)&&(identical(other.required, required) || other.required == required)&&(identical(other.contentId, contentId) || other.contentId == contentId)&&(identical(other.contentSlug, contentSlug) || other.contentSlug == contentSlug)&&(identical(other.completed, completed) || other.completed == completed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderNum,taskType,title,required,contentId,contentSlug,completed);

@override
String toString() {
  return 'WeeklyTask(orderNum: $orderNum, taskType: $taskType, title: $title, required: $required, contentId: $contentId, contentSlug: $contentSlug, completed: $completed)';
}


}

/// @nodoc
abstract mixin class _$WeeklyTaskCopyWith<$Res> implements $WeeklyTaskCopyWith<$Res> {
  factory _$WeeklyTaskCopyWith(_WeeklyTask value, $Res Function(_WeeklyTask) _then) = __$WeeklyTaskCopyWithImpl;
@override @useResult
$Res call({
 int orderNum, String taskType, String title, bool required, int? contentId, String? contentSlug, bool completed
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
@override @pragma('vm:prefer-inline') $Res call({Object? orderNum = null,Object? taskType = null,Object? title = null,Object? required = null,Object? contentId = freezed,Object? contentSlug = freezed,Object? completed = null,}) {
  return _then(_WeeklyTask(
orderNum: null == orderNum ? _self.orderNum : orderNum // ignore: cast_nullable_to_non_nullable
as int,taskType: null == taskType ? _self.taskType : taskType // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,contentId: freezed == contentId ? _self.contentId : contentId // ignore: cast_nullable_to_non_nullable
as int?,contentSlug: freezed == contentSlug ? _self.contentSlug : contentSlug // ignore: cast_nullable_to_non_nullable
as String?,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
