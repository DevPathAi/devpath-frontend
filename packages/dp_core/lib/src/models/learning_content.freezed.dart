// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'learning_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LearningContent {

 int get id; String get slug; String get title; String get track; String get markdown; int? get estimatedMinutes; double? get difficulty; String? get bloomLevel; List<String> get conceptTags; ContentProgress get progress;
/// Create a copy of LearningContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LearningContentCopyWith<LearningContent> get copyWith => _$LearningContentCopyWithImpl<LearningContent>(this as LearningContent, _$identity);

  /// Serializes this LearningContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LearningContent&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.title, title) || other.title == title)&&(identical(other.track, track) || other.track == track)&&(identical(other.markdown, markdown) || other.markdown == markdown)&&(identical(other.estimatedMinutes, estimatedMinutes) || other.estimatedMinutes == estimatedMinutes)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty)&&(identical(other.bloomLevel, bloomLevel) || other.bloomLevel == bloomLevel)&&const DeepCollectionEquality().equals(other.conceptTags, conceptTags)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,title,track,markdown,estimatedMinutes,difficulty,bloomLevel,const DeepCollectionEquality().hash(conceptTags),progress);

@override
String toString() {
  return 'LearningContent(id: $id, slug: $slug, title: $title, track: $track, markdown: $markdown, estimatedMinutes: $estimatedMinutes, difficulty: $difficulty, bloomLevel: $bloomLevel, conceptTags: $conceptTags, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $LearningContentCopyWith<$Res>  {
  factory $LearningContentCopyWith(LearningContent value, $Res Function(LearningContent) _then) = _$LearningContentCopyWithImpl;
@useResult
$Res call({
 int id, String slug, String title, String track, String markdown, int? estimatedMinutes, double? difficulty, String? bloomLevel, List<String> conceptTags, ContentProgress progress
});


$ContentProgressCopyWith<$Res> get progress;

}
/// @nodoc
class _$LearningContentCopyWithImpl<$Res>
    implements $LearningContentCopyWith<$Res> {
  _$LearningContentCopyWithImpl(this._self, this._then);

  final LearningContent _self;
  final $Res Function(LearningContent) _then;

/// Create a copy of LearningContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? title = null,Object? track = null,Object? markdown = null,Object? estimatedMinutes = freezed,Object? difficulty = freezed,Object? bloomLevel = freezed,Object? conceptTags = null,Object? progress = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,track: null == track ? _self.track : track // ignore: cast_nullable_to_non_nullable
as String,markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,estimatedMinutes: freezed == estimatedMinutes ? _self.estimatedMinutes : estimatedMinutes // ignore: cast_nullable_to_non_nullable
as int?,difficulty: freezed == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as double?,bloomLevel: freezed == bloomLevel ? _self.bloomLevel : bloomLevel // ignore: cast_nullable_to_non_nullable
as String?,conceptTags: null == conceptTags ? _self.conceptTags : conceptTags // ignore: cast_nullable_to_non_nullable
as List<String>,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ContentProgress,
  ));
}
/// Create a copy of LearningContent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentProgressCopyWith<$Res> get progress {
  
  return $ContentProgressCopyWith<$Res>(_self.progress, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}


/// Adds pattern-matching-related methods to [LearningContent].
extension LearningContentPatterns on LearningContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LearningContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LearningContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LearningContent value)  $default,){
final _that = this;
switch (_that) {
case _LearningContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LearningContent value)?  $default,){
final _that = this;
switch (_that) {
case _LearningContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String slug,  String title,  String track,  String markdown,  int? estimatedMinutes,  double? difficulty,  String? bloomLevel,  List<String> conceptTags,  ContentProgress progress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LearningContent() when $default != null:
return $default(_that.id,_that.slug,_that.title,_that.track,_that.markdown,_that.estimatedMinutes,_that.difficulty,_that.bloomLevel,_that.conceptTags,_that.progress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String slug,  String title,  String track,  String markdown,  int? estimatedMinutes,  double? difficulty,  String? bloomLevel,  List<String> conceptTags,  ContentProgress progress)  $default,) {final _that = this;
switch (_that) {
case _LearningContent():
return $default(_that.id,_that.slug,_that.title,_that.track,_that.markdown,_that.estimatedMinutes,_that.difficulty,_that.bloomLevel,_that.conceptTags,_that.progress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String slug,  String title,  String track,  String markdown,  int? estimatedMinutes,  double? difficulty,  String? bloomLevel,  List<String> conceptTags,  ContentProgress progress)?  $default,) {final _that = this;
switch (_that) {
case _LearningContent() when $default != null:
return $default(_that.id,_that.slug,_that.title,_that.track,_that.markdown,_that.estimatedMinutes,_that.difficulty,_that.bloomLevel,_that.conceptTags,_that.progress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LearningContent implements LearningContent {
  const _LearningContent({required this.id, required this.slug, required this.title, required this.track, required this.markdown, this.estimatedMinutes, this.difficulty, this.bloomLevel, final  List<String> conceptTags = const <String>[], required this.progress}): _conceptTags = conceptTags;
  factory _LearningContent.fromJson(Map<String, dynamic> json) => _$LearningContentFromJson(json);

@override final  int id;
@override final  String slug;
@override final  String title;
@override final  String track;
@override final  String markdown;
@override final  int? estimatedMinutes;
@override final  double? difficulty;
@override final  String? bloomLevel;
 final  List<String> _conceptTags;
@override@JsonKey() List<String> get conceptTags {
  if (_conceptTags is EqualUnmodifiableListView) return _conceptTags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_conceptTags);
}

@override final  ContentProgress progress;

/// Create a copy of LearningContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LearningContentCopyWith<_LearningContent> get copyWith => __$LearningContentCopyWithImpl<_LearningContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LearningContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LearningContent&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.title, title) || other.title == title)&&(identical(other.track, track) || other.track == track)&&(identical(other.markdown, markdown) || other.markdown == markdown)&&(identical(other.estimatedMinutes, estimatedMinutes) || other.estimatedMinutes == estimatedMinutes)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty)&&(identical(other.bloomLevel, bloomLevel) || other.bloomLevel == bloomLevel)&&const DeepCollectionEquality().equals(other._conceptTags, _conceptTags)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,title,track,markdown,estimatedMinutes,difficulty,bloomLevel,const DeepCollectionEquality().hash(_conceptTags),progress);

@override
String toString() {
  return 'LearningContent(id: $id, slug: $slug, title: $title, track: $track, markdown: $markdown, estimatedMinutes: $estimatedMinutes, difficulty: $difficulty, bloomLevel: $bloomLevel, conceptTags: $conceptTags, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$LearningContentCopyWith<$Res> implements $LearningContentCopyWith<$Res> {
  factory _$LearningContentCopyWith(_LearningContent value, $Res Function(_LearningContent) _then) = __$LearningContentCopyWithImpl;
@override @useResult
$Res call({
 int id, String slug, String title, String track, String markdown, int? estimatedMinutes, double? difficulty, String? bloomLevel, List<String> conceptTags, ContentProgress progress
});


@override $ContentProgressCopyWith<$Res> get progress;

}
/// @nodoc
class __$LearningContentCopyWithImpl<$Res>
    implements _$LearningContentCopyWith<$Res> {
  __$LearningContentCopyWithImpl(this._self, this._then);

  final _LearningContent _self;
  final $Res Function(_LearningContent) _then;

/// Create a copy of LearningContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? title = null,Object? track = null,Object? markdown = null,Object? estimatedMinutes = freezed,Object? difficulty = freezed,Object? bloomLevel = freezed,Object? conceptTags = null,Object? progress = null,}) {
  return _then(_LearningContent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,track: null == track ? _self.track : track // ignore: cast_nullable_to_non_nullable
as String,markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,estimatedMinutes: freezed == estimatedMinutes ? _self.estimatedMinutes : estimatedMinutes // ignore: cast_nullable_to_non_nullable
as int?,difficulty: freezed == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as double?,bloomLevel: freezed == bloomLevel ? _self.bloomLevel : bloomLevel // ignore: cast_nullable_to_non_nullable
as String?,conceptTags: null == conceptTags ? _self._conceptTags : conceptTags // ignore: cast_nullable_to_non_nullable
as List<String>,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ContentProgress,
  ));
}

/// Create a copy of LearningContent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentProgressCopyWith<$Res> get progress {
  
  return $ContentProgressCopyWith<$Res>(_self.progress, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}


/// @nodoc
mixin _$ContentProgress {

 double get scrollPct; int get dwellSec; bool get completed; String? get completedAt;
/// Create a copy of ContentProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContentProgressCopyWith<ContentProgress> get copyWith => _$ContentProgressCopyWithImpl<ContentProgress>(this as ContentProgress, _$identity);

  /// Serializes this ContentProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContentProgress&&(identical(other.scrollPct, scrollPct) || other.scrollPct == scrollPct)&&(identical(other.dwellSec, dwellSec) || other.dwellSec == dwellSec)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scrollPct,dwellSec,completed,completedAt);

@override
String toString() {
  return 'ContentProgress(scrollPct: $scrollPct, dwellSec: $dwellSec, completed: $completed, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $ContentProgressCopyWith<$Res>  {
  factory $ContentProgressCopyWith(ContentProgress value, $Res Function(ContentProgress) _then) = _$ContentProgressCopyWithImpl;
@useResult
$Res call({
 double scrollPct, int dwellSec, bool completed, String? completedAt
});




}
/// @nodoc
class _$ContentProgressCopyWithImpl<$Res>
    implements $ContentProgressCopyWith<$Res> {
  _$ContentProgressCopyWithImpl(this._self, this._then);

  final ContentProgress _self;
  final $Res Function(ContentProgress) _then;

/// Create a copy of ContentProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scrollPct = null,Object? dwellSec = null,Object? completed = null,Object? completedAt = freezed,}) {
  return _then(_self.copyWith(
scrollPct: null == scrollPct ? _self.scrollPct : scrollPct // ignore: cast_nullable_to_non_nullable
as double,dwellSec: null == dwellSec ? _self.dwellSec : dwellSec // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ContentProgress].
extension ContentProgressPatterns on ContentProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContentProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContentProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContentProgress value)  $default,){
final _that = this;
switch (_that) {
case _ContentProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContentProgress value)?  $default,){
final _that = this;
switch (_that) {
case _ContentProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double scrollPct,  int dwellSec,  bool completed,  String? completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContentProgress() when $default != null:
return $default(_that.scrollPct,_that.dwellSec,_that.completed,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double scrollPct,  int dwellSec,  bool completed,  String? completedAt)  $default,) {final _that = this;
switch (_that) {
case _ContentProgress():
return $default(_that.scrollPct,_that.dwellSec,_that.completed,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double scrollPct,  int dwellSec,  bool completed,  String? completedAt)?  $default,) {final _that = this;
switch (_that) {
case _ContentProgress() when $default != null:
return $default(_that.scrollPct,_that.dwellSec,_that.completed,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ContentProgress implements ContentProgress {
  const _ContentProgress({required this.scrollPct, required this.dwellSec, this.completed = false, this.completedAt});
  factory _ContentProgress.fromJson(Map<String, dynamic> json) => _$ContentProgressFromJson(json);

@override final  double scrollPct;
@override final  int dwellSec;
@override@JsonKey() final  bool completed;
@override final  String? completedAt;

/// Create a copy of ContentProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContentProgressCopyWith<_ContentProgress> get copyWith => __$ContentProgressCopyWithImpl<_ContentProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContentProgressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContentProgress&&(identical(other.scrollPct, scrollPct) || other.scrollPct == scrollPct)&&(identical(other.dwellSec, dwellSec) || other.dwellSec == dwellSec)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scrollPct,dwellSec,completed,completedAt);

@override
String toString() {
  return 'ContentProgress(scrollPct: $scrollPct, dwellSec: $dwellSec, completed: $completed, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$ContentProgressCopyWith<$Res> implements $ContentProgressCopyWith<$Res> {
  factory _$ContentProgressCopyWith(_ContentProgress value, $Res Function(_ContentProgress) _then) = __$ContentProgressCopyWithImpl;
@override @useResult
$Res call({
 double scrollPct, int dwellSec, bool completed, String? completedAt
});




}
/// @nodoc
class __$ContentProgressCopyWithImpl<$Res>
    implements _$ContentProgressCopyWith<$Res> {
  __$ContentProgressCopyWithImpl(this._self, this._then);

  final _ContentProgress _self;
  final $Res Function(_ContentProgress) _then;

/// Create a copy of ContentProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scrollPct = null,Object? dwellSec = null,Object? completed = null,Object? completedAt = freezed,}) {
  return _then(_ContentProgress(
scrollPct: null == scrollPct ? _self.scrollPct : scrollPct // ignore: cast_nullable_to_non_nullable
as double,dwellSec: null == dwellSec ? _self.dwellSec : dwellSec // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ContentProgressUpdateResponse {

 double get scrollPct; int get dwellSec; bool get completed; String? get completedAt;
/// Create a copy of ContentProgressUpdateResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContentProgressUpdateResponseCopyWith<ContentProgressUpdateResponse> get copyWith => _$ContentProgressUpdateResponseCopyWithImpl<ContentProgressUpdateResponse>(this as ContentProgressUpdateResponse, _$identity);

  /// Serializes this ContentProgressUpdateResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContentProgressUpdateResponse&&(identical(other.scrollPct, scrollPct) || other.scrollPct == scrollPct)&&(identical(other.dwellSec, dwellSec) || other.dwellSec == dwellSec)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scrollPct,dwellSec,completed,completedAt);

@override
String toString() {
  return 'ContentProgressUpdateResponse(scrollPct: $scrollPct, dwellSec: $dwellSec, completed: $completed, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $ContentProgressUpdateResponseCopyWith<$Res>  {
  factory $ContentProgressUpdateResponseCopyWith(ContentProgressUpdateResponse value, $Res Function(ContentProgressUpdateResponse) _then) = _$ContentProgressUpdateResponseCopyWithImpl;
@useResult
$Res call({
 double scrollPct, int dwellSec, bool completed, String? completedAt
});




}
/// @nodoc
class _$ContentProgressUpdateResponseCopyWithImpl<$Res>
    implements $ContentProgressUpdateResponseCopyWith<$Res> {
  _$ContentProgressUpdateResponseCopyWithImpl(this._self, this._then);

  final ContentProgressUpdateResponse _self;
  final $Res Function(ContentProgressUpdateResponse) _then;

/// Create a copy of ContentProgressUpdateResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scrollPct = null,Object? dwellSec = null,Object? completed = null,Object? completedAt = freezed,}) {
  return _then(_self.copyWith(
scrollPct: null == scrollPct ? _self.scrollPct : scrollPct // ignore: cast_nullable_to_non_nullable
as double,dwellSec: null == dwellSec ? _self.dwellSec : dwellSec // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ContentProgressUpdateResponse].
extension ContentProgressUpdateResponsePatterns on ContentProgressUpdateResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContentProgressUpdateResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContentProgressUpdateResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContentProgressUpdateResponse value)  $default,){
final _that = this;
switch (_that) {
case _ContentProgressUpdateResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContentProgressUpdateResponse value)?  $default,){
final _that = this;
switch (_that) {
case _ContentProgressUpdateResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double scrollPct,  int dwellSec,  bool completed,  String? completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContentProgressUpdateResponse() when $default != null:
return $default(_that.scrollPct,_that.dwellSec,_that.completed,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double scrollPct,  int dwellSec,  bool completed,  String? completedAt)  $default,) {final _that = this;
switch (_that) {
case _ContentProgressUpdateResponse():
return $default(_that.scrollPct,_that.dwellSec,_that.completed,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double scrollPct,  int dwellSec,  bool completed,  String? completedAt)?  $default,) {final _that = this;
switch (_that) {
case _ContentProgressUpdateResponse() when $default != null:
return $default(_that.scrollPct,_that.dwellSec,_that.completed,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ContentProgressUpdateResponse implements ContentProgressUpdateResponse {
  const _ContentProgressUpdateResponse({required this.scrollPct, required this.dwellSec, this.completed = false, this.completedAt});
  factory _ContentProgressUpdateResponse.fromJson(Map<String, dynamic> json) => _$ContentProgressUpdateResponseFromJson(json);

@override final  double scrollPct;
@override final  int dwellSec;
@override@JsonKey() final  bool completed;
@override final  String? completedAt;

/// Create a copy of ContentProgressUpdateResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContentProgressUpdateResponseCopyWith<_ContentProgressUpdateResponse> get copyWith => __$ContentProgressUpdateResponseCopyWithImpl<_ContentProgressUpdateResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContentProgressUpdateResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContentProgressUpdateResponse&&(identical(other.scrollPct, scrollPct) || other.scrollPct == scrollPct)&&(identical(other.dwellSec, dwellSec) || other.dwellSec == dwellSec)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scrollPct,dwellSec,completed,completedAt);

@override
String toString() {
  return 'ContentProgressUpdateResponse(scrollPct: $scrollPct, dwellSec: $dwellSec, completed: $completed, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$ContentProgressUpdateResponseCopyWith<$Res> implements $ContentProgressUpdateResponseCopyWith<$Res> {
  factory _$ContentProgressUpdateResponseCopyWith(_ContentProgressUpdateResponse value, $Res Function(_ContentProgressUpdateResponse) _then) = __$ContentProgressUpdateResponseCopyWithImpl;
@override @useResult
$Res call({
 double scrollPct, int dwellSec, bool completed, String? completedAt
});




}
/// @nodoc
class __$ContentProgressUpdateResponseCopyWithImpl<$Res>
    implements _$ContentProgressUpdateResponseCopyWith<$Res> {
  __$ContentProgressUpdateResponseCopyWithImpl(this._self, this._then);

  final _ContentProgressUpdateResponse _self;
  final $Res Function(_ContentProgressUpdateResponse) _then;

/// Create a copy of ContentProgressUpdateResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scrollPct = null,Object? dwellSec = null,Object? completed = null,Object? completedAt = freezed,}) {
  return _then(_ContentProgressUpdateResponse(
scrollPct: null == scrollPct ? _self.scrollPct : scrollPct // ignore: cast_nullable_to_non_nullable
as double,dwellSec: null == dwellSec ? _self.dwellSec : dwellSec // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
