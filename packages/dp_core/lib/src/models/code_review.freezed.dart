// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'code_review.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodeReview {

 int get confidence; List<String> get strengths; List<ReviewIssue> get improvements; List<ReviewIssue> get security; String? get id; String? get status;
/// Create a copy of CodeReview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodeReviewCopyWith<CodeReview> get copyWith => _$CodeReviewCopyWithImpl<CodeReview>(this as CodeReview, _$identity);

  /// Serializes this CodeReview to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodeReview&&(identical(other.confidence, confidence) || other.confidence == confidence)&&const DeepCollectionEquality().equals(other.strengths, strengths)&&const DeepCollectionEquality().equals(other.improvements, improvements)&&const DeepCollectionEquality().equals(other.security, security)&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,confidence,const DeepCollectionEquality().hash(strengths),const DeepCollectionEquality().hash(improvements),const DeepCollectionEquality().hash(security),id,status);

@override
String toString() {
  return 'CodeReview(confidence: $confidence, strengths: $strengths, improvements: $improvements, security: $security, id: $id, status: $status)';
}


}

/// @nodoc
abstract mixin class $CodeReviewCopyWith<$Res>  {
  factory $CodeReviewCopyWith(CodeReview value, $Res Function(CodeReview) _then) = _$CodeReviewCopyWithImpl;
@useResult
$Res call({
 int confidence, List<String> strengths, List<ReviewIssue> improvements, List<ReviewIssue> security, String? id, String? status
});




}
/// @nodoc
class _$CodeReviewCopyWithImpl<$Res>
    implements $CodeReviewCopyWith<$Res> {
  _$CodeReviewCopyWithImpl(this._self, this._then);

  final CodeReview _self;
  final $Res Function(CodeReview) _then;

/// Create a copy of CodeReview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? confidence = null,Object? strengths = null,Object? improvements = null,Object? security = null,Object? id = freezed,Object? status = freezed,}) {
  return _then(_self.copyWith(
confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as int,strengths: null == strengths ? _self.strengths : strengths // ignore: cast_nullable_to_non_nullable
as List<String>,improvements: null == improvements ? _self.improvements : improvements // ignore: cast_nullable_to_non_nullable
as List<ReviewIssue>,security: null == security ? _self.security : security // ignore: cast_nullable_to_non_nullable
as List<ReviewIssue>,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CodeReview].
extension CodeReviewPatterns on CodeReview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CodeReview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CodeReview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CodeReview value)  $default,){
final _that = this;
switch (_that) {
case _CodeReview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CodeReview value)?  $default,){
final _that = this;
switch (_that) {
case _CodeReview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int confidence,  List<String> strengths,  List<ReviewIssue> improvements,  List<ReviewIssue> security,  String? id,  String? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CodeReview() when $default != null:
return $default(_that.confidence,_that.strengths,_that.improvements,_that.security,_that.id,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int confidence,  List<String> strengths,  List<ReviewIssue> improvements,  List<ReviewIssue> security,  String? id,  String? status)  $default,) {final _that = this;
switch (_that) {
case _CodeReview():
return $default(_that.confidence,_that.strengths,_that.improvements,_that.security,_that.id,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int confidence,  List<String> strengths,  List<ReviewIssue> improvements,  List<ReviewIssue> security,  String? id,  String? status)?  $default,) {final _that = this;
switch (_that) {
case _CodeReview() when $default != null:
return $default(_that.confidence,_that.strengths,_that.improvements,_that.security,_that.id,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CodeReview implements CodeReview {
  const _CodeReview({required this.confidence, final  List<String> strengths = const <String>[], final  List<ReviewIssue> improvements = const <ReviewIssue>[], final  List<ReviewIssue> security = const <ReviewIssue>[], this.id, this.status}): _strengths = strengths,_improvements = improvements,_security = security;
  factory _CodeReview.fromJson(Map<String, dynamic> json) => _$CodeReviewFromJson(json);

@override final  int confidence;
 final  List<String> _strengths;
@override@JsonKey() List<String> get strengths {
  if (_strengths is EqualUnmodifiableListView) return _strengths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_strengths);
}

 final  List<ReviewIssue> _improvements;
@override@JsonKey() List<ReviewIssue> get improvements {
  if (_improvements is EqualUnmodifiableListView) return _improvements;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_improvements);
}

 final  List<ReviewIssue> _security;
@override@JsonKey() List<ReviewIssue> get security {
  if (_security is EqualUnmodifiableListView) return _security;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_security);
}

@override final  String? id;
@override final  String? status;

/// Create a copy of CodeReview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodeReviewCopyWith<_CodeReview> get copyWith => __$CodeReviewCopyWithImpl<_CodeReview>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodeReviewToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodeReview&&(identical(other.confidence, confidence) || other.confidence == confidence)&&const DeepCollectionEquality().equals(other._strengths, _strengths)&&const DeepCollectionEquality().equals(other._improvements, _improvements)&&const DeepCollectionEquality().equals(other._security, _security)&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,confidence,const DeepCollectionEquality().hash(_strengths),const DeepCollectionEquality().hash(_improvements),const DeepCollectionEquality().hash(_security),id,status);

@override
String toString() {
  return 'CodeReview(confidence: $confidence, strengths: $strengths, improvements: $improvements, security: $security, id: $id, status: $status)';
}


}

/// @nodoc
abstract mixin class _$CodeReviewCopyWith<$Res> implements $CodeReviewCopyWith<$Res> {
  factory _$CodeReviewCopyWith(_CodeReview value, $Res Function(_CodeReview) _then) = __$CodeReviewCopyWithImpl;
@override @useResult
$Res call({
 int confidence, List<String> strengths, List<ReviewIssue> improvements, List<ReviewIssue> security, String? id, String? status
});




}
/// @nodoc
class __$CodeReviewCopyWithImpl<$Res>
    implements _$CodeReviewCopyWith<$Res> {
  __$CodeReviewCopyWithImpl(this._self, this._then);

  final _CodeReview _self;
  final $Res Function(_CodeReview) _then;

/// Create a copy of CodeReview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? confidence = null,Object? strengths = null,Object? improvements = null,Object? security = null,Object? id = freezed,Object? status = freezed,}) {
  return _then(_CodeReview(
confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as int,strengths: null == strengths ? _self._strengths : strengths // ignore: cast_nullable_to_non_nullable
as List<String>,improvements: null == improvements ? _self._improvements : improvements // ignore: cast_nullable_to_non_nullable
as List<ReviewIssue>,security: null == security ? _self._security : security // ignore: cast_nullable_to_non_nullable
as List<ReviewIssue>,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ReviewIssue {

 String get message; int? get line; String get severity;
/// Create a copy of ReviewIssue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewIssueCopyWith<ReviewIssue> get copyWith => _$ReviewIssueCopyWithImpl<ReviewIssue>(this as ReviewIssue, _$identity);

  /// Serializes this ReviewIssue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewIssue&&(identical(other.message, message) || other.message == message)&&(identical(other.line, line) || other.line == line)&&(identical(other.severity, severity) || other.severity == severity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,line,severity);

@override
String toString() {
  return 'ReviewIssue(message: $message, line: $line, severity: $severity)';
}


}

/// @nodoc
abstract mixin class $ReviewIssueCopyWith<$Res>  {
  factory $ReviewIssueCopyWith(ReviewIssue value, $Res Function(ReviewIssue) _then) = _$ReviewIssueCopyWithImpl;
@useResult
$Res call({
 String message, int? line, String severity
});




}
/// @nodoc
class _$ReviewIssueCopyWithImpl<$Res>
    implements $ReviewIssueCopyWith<$Res> {
  _$ReviewIssueCopyWithImpl(this._self, this._then);

  final ReviewIssue _self;
  final $Res Function(ReviewIssue) _then;

/// Create a copy of ReviewIssue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? line = freezed,Object? severity = null,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewIssue].
extension ReviewIssuePatterns on ReviewIssue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewIssue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewIssue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewIssue value)  $default,){
final _that = this;
switch (_that) {
case _ReviewIssue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewIssue value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewIssue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  int? line,  String severity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewIssue() when $default != null:
return $default(_that.message,_that.line,_that.severity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  int? line,  String severity)  $default,) {final _that = this;
switch (_that) {
case _ReviewIssue():
return $default(_that.message,_that.line,_that.severity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  int? line,  String severity)?  $default,) {final _that = this;
switch (_that) {
case _ReviewIssue() when $default != null:
return $default(_that.message,_that.line,_that.severity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReviewIssue implements ReviewIssue {
  const _ReviewIssue({required this.message, this.line, this.severity = 'info'});
  factory _ReviewIssue.fromJson(Map<String, dynamic> json) => _$ReviewIssueFromJson(json);

@override final  String message;
@override final  int? line;
@override@JsonKey() final  String severity;

/// Create a copy of ReviewIssue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewIssueCopyWith<_ReviewIssue> get copyWith => __$ReviewIssueCopyWithImpl<_ReviewIssue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReviewIssueToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewIssue&&(identical(other.message, message) || other.message == message)&&(identical(other.line, line) || other.line == line)&&(identical(other.severity, severity) || other.severity == severity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,line,severity);

@override
String toString() {
  return 'ReviewIssue(message: $message, line: $line, severity: $severity)';
}


}

/// @nodoc
abstract mixin class _$ReviewIssueCopyWith<$Res> implements $ReviewIssueCopyWith<$Res> {
  factory _$ReviewIssueCopyWith(_ReviewIssue value, $Res Function(_ReviewIssue) _then) = __$ReviewIssueCopyWithImpl;
@override @useResult
$Res call({
 String message, int? line, String severity
});




}
/// @nodoc
class __$ReviewIssueCopyWithImpl<$Res>
    implements _$ReviewIssueCopyWith<$Res> {
  __$ReviewIssueCopyWithImpl(this._self, this._then);

  final _ReviewIssue _self;
  final $Res Function(_ReviewIssue) _then;

/// Create a copy of ReviewIssue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? line = freezed,Object? severity = null,}) {
  return _then(_ReviewIssue(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
