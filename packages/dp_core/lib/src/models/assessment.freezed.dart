// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assessment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AssessmentQuestion {

 int get id; String get type; String get content; String? get options; String get bloomLevel; double get difficulty;
/// Create a copy of AssessmentQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssessmentQuestionCopyWith<AssessmentQuestion> get copyWith => _$AssessmentQuestionCopyWithImpl<AssessmentQuestion>(this as AssessmentQuestion, _$identity);

  /// Serializes this AssessmentQuestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssessmentQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.content, content) || other.content == content)&&(identical(other.options, options) || other.options == options)&&(identical(other.bloomLevel, bloomLevel) || other.bloomLevel == bloomLevel)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,content,options,bloomLevel,difficulty);

@override
String toString() {
  return 'AssessmentQuestion(id: $id, type: $type, content: $content, options: $options, bloomLevel: $bloomLevel, difficulty: $difficulty)';
}


}

/// @nodoc
abstract mixin class $AssessmentQuestionCopyWith<$Res>  {
  factory $AssessmentQuestionCopyWith(AssessmentQuestion value, $Res Function(AssessmentQuestion) _then) = _$AssessmentQuestionCopyWithImpl;
@useResult
$Res call({
 int id, String type, String content, String? options, String bloomLevel, double difficulty
});




}
/// @nodoc
class _$AssessmentQuestionCopyWithImpl<$Res>
    implements $AssessmentQuestionCopyWith<$Res> {
  _$AssessmentQuestionCopyWithImpl(this._self, this._then);

  final AssessmentQuestion _self;
  final $Res Function(AssessmentQuestion) _then;

/// Create a copy of AssessmentQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? content = null,Object? options = freezed,Object? bloomLevel = null,Object? difficulty = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,options: freezed == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as String?,bloomLevel: null == bloomLevel ? _self.bloomLevel : bloomLevel // ignore: cast_nullable_to_non_nullable
as String,difficulty: null == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [AssessmentQuestion].
extension AssessmentQuestionPatterns on AssessmentQuestion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssessmentQuestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssessmentQuestion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssessmentQuestion value)  $default,){
final _that = this;
switch (_that) {
case _AssessmentQuestion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssessmentQuestion value)?  $default,){
final _that = this;
switch (_that) {
case _AssessmentQuestion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String type,  String content,  String? options,  String bloomLevel,  double difficulty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssessmentQuestion() when $default != null:
return $default(_that.id,_that.type,_that.content,_that.options,_that.bloomLevel,_that.difficulty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String type,  String content,  String? options,  String bloomLevel,  double difficulty)  $default,) {final _that = this;
switch (_that) {
case _AssessmentQuestion():
return $default(_that.id,_that.type,_that.content,_that.options,_that.bloomLevel,_that.difficulty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String type,  String content,  String? options,  String bloomLevel,  double difficulty)?  $default,) {final _that = this;
switch (_that) {
case _AssessmentQuestion() when $default != null:
return $default(_that.id,_that.type,_that.content,_that.options,_that.bloomLevel,_that.difficulty);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AssessmentQuestion implements AssessmentQuestion {
  const _AssessmentQuestion({required this.id, required this.type, required this.content, this.options, required this.bloomLevel, required this.difficulty});
  factory _AssessmentQuestion.fromJson(Map<String, dynamic> json) => _$AssessmentQuestionFromJson(json);

@override final  int id;
@override final  String type;
@override final  String content;
@override final  String? options;
@override final  String bloomLevel;
@override final  double difficulty;

/// Create a copy of AssessmentQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssessmentQuestionCopyWith<_AssessmentQuestion> get copyWith => __$AssessmentQuestionCopyWithImpl<_AssessmentQuestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssessmentQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssessmentQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.content, content) || other.content == content)&&(identical(other.options, options) || other.options == options)&&(identical(other.bloomLevel, bloomLevel) || other.bloomLevel == bloomLevel)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,content,options,bloomLevel,difficulty);

@override
String toString() {
  return 'AssessmentQuestion(id: $id, type: $type, content: $content, options: $options, bloomLevel: $bloomLevel, difficulty: $difficulty)';
}


}

/// @nodoc
abstract mixin class _$AssessmentQuestionCopyWith<$Res> implements $AssessmentQuestionCopyWith<$Res> {
  factory _$AssessmentQuestionCopyWith(_AssessmentQuestion value, $Res Function(_AssessmentQuestion) _then) = __$AssessmentQuestionCopyWithImpl;
@override @useResult
$Res call({
 int id, String type, String content, String? options, String bloomLevel, double difficulty
});




}
/// @nodoc
class __$AssessmentQuestionCopyWithImpl<$Res>
    implements _$AssessmentQuestionCopyWith<$Res> {
  __$AssessmentQuestionCopyWithImpl(this._self, this._then);

  final _AssessmentQuestion _self;
  final $Res Function(_AssessmentQuestion) _then;

/// Create a copy of AssessmentQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? content = null,Object? options = freezed,Object? bloomLevel = null,Object? difficulty = null,}) {
  return _then(_AssessmentQuestion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,options: freezed == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as String?,bloomLevel: null == bloomLevel ? _self.bloomLevel : bloomLevel // ignore: cast_nullable_to_non_nullable
as String,difficulty: null == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$NextQuestion {

 AssessmentQuestion get question; int get index; int get total;
/// Create a copy of NextQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NextQuestionCopyWith<NextQuestion> get copyWith => _$NextQuestionCopyWithImpl<NextQuestion>(this as NextQuestion, _$identity);

  /// Serializes this NextQuestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NextQuestion&&(identical(other.question, question) || other.question == question)&&(identical(other.index, index) || other.index == index)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,question,index,total);

@override
String toString() {
  return 'NextQuestion(question: $question, index: $index, total: $total)';
}


}

/// @nodoc
abstract mixin class $NextQuestionCopyWith<$Res>  {
  factory $NextQuestionCopyWith(NextQuestion value, $Res Function(NextQuestion) _then) = _$NextQuestionCopyWithImpl;
@useResult
$Res call({
 AssessmentQuestion question, int index, int total
});


$AssessmentQuestionCopyWith<$Res> get question;

}
/// @nodoc
class _$NextQuestionCopyWithImpl<$Res>
    implements $NextQuestionCopyWith<$Res> {
  _$NextQuestionCopyWithImpl(this._self, this._then);

  final NextQuestion _self;
  final $Res Function(NextQuestion) _then;

/// Create a copy of NextQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? question = null,Object? index = null,Object? total = null,}) {
  return _then(_self.copyWith(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as AssessmentQuestion,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of NextQuestion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssessmentQuestionCopyWith<$Res> get question {
  
  return $AssessmentQuestionCopyWith<$Res>(_self.question, (value) {
    return _then(_self.copyWith(question: value));
  });
}
}


/// Adds pattern-matching-related methods to [NextQuestion].
extension NextQuestionPatterns on NextQuestion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NextQuestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NextQuestion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NextQuestion value)  $default,){
final _that = this;
switch (_that) {
case _NextQuestion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NextQuestion value)?  $default,){
final _that = this;
switch (_that) {
case _NextQuestion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AssessmentQuestion question,  int index,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NextQuestion() when $default != null:
return $default(_that.question,_that.index,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AssessmentQuestion question,  int index,  int total)  $default,) {final _that = this;
switch (_that) {
case _NextQuestion():
return $default(_that.question,_that.index,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AssessmentQuestion question,  int index,  int total)?  $default,) {final _that = this;
switch (_that) {
case _NextQuestion() when $default != null:
return $default(_that.question,_that.index,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NextQuestion implements NextQuestion {
  const _NextQuestion({required this.question, required this.index, required this.total});
  factory _NextQuestion.fromJson(Map<String, dynamic> json) => _$NextQuestionFromJson(json);

@override final  AssessmentQuestion question;
@override final  int index;
@override final  int total;

/// Create a copy of NextQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NextQuestionCopyWith<_NextQuestion> get copyWith => __$NextQuestionCopyWithImpl<_NextQuestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NextQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NextQuestion&&(identical(other.question, question) || other.question == question)&&(identical(other.index, index) || other.index == index)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,question,index,total);

@override
String toString() {
  return 'NextQuestion(question: $question, index: $index, total: $total)';
}


}

/// @nodoc
abstract mixin class _$NextQuestionCopyWith<$Res> implements $NextQuestionCopyWith<$Res> {
  factory _$NextQuestionCopyWith(_NextQuestion value, $Res Function(_NextQuestion) _then) = __$NextQuestionCopyWithImpl;
@override @useResult
$Res call({
 AssessmentQuestion question, int index, int total
});


@override $AssessmentQuestionCopyWith<$Res> get question;

}
/// @nodoc
class __$NextQuestionCopyWithImpl<$Res>
    implements _$NextQuestionCopyWith<$Res> {
  __$NextQuestionCopyWithImpl(this._self, this._then);

  final _NextQuestion _self;
  final $Res Function(_NextQuestion) _then;

/// Create a copy of NextQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? question = null,Object? index = null,Object? total = null,}) {
  return _then(_NextQuestion(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as AssessmentQuestion,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of NextQuestion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssessmentQuestionCopyWith<$Res> get question {
  
  return $AssessmentQuestionCopyWith<$Res>(_self.question, (value) {
    return _then(_self.copyWith(question: value));
  });
}
}


/// @nodoc
mixin _$AssessmentResult {

 String get diagnosedLevel; double? get confidenceWeight;
/// Create a copy of AssessmentResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssessmentResultCopyWith<AssessmentResult> get copyWith => _$AssessmentResultCopyWithImpl<AssessmentResult>(this as AssessmentResult, _$identity);

  /// Serializes this AssessmentResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssessmentResult&&(identical(other.diagnosedLevel, diagnosedLevel) || other.diagnosedLevel == diagnosedLevel)&&(identical(other.confidenceWeight, confidenceWeight) || other.confidenceWeight == confidenceWeight));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,diagnosedLevel,confidenceWeight);

@override
String toString() {
  return 'AssessmentResult(diagnosedLevel: $diagnosedLevel, confidenceWeight: $confidenceWeight)';
}


}

/// @nodoc
abstract mixin class $AssessmentResultCopyWith<$Res>  {
  factory $AssessmentResultCopyWith(AssessmentResult value, $Res Function(AssessmentResult) _then) = _$AssessmentResultCopyWithImpl;
@useResult
$Res call({
 String diagnosedLevel, double? confidenceWeight
});




}
/// @nodoc
class _$AssessmentResultCopyWithImpl<$Res>
    implements $AssessmentResultCopyWith<$Res> {
  _$AssessmentResultCopyWithImpl(this._self, this._then);

  final AssessmentResult _self;
  final $Res Function(AssessmentResult) _then;

/// Create a copy of AssessmentResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? diagnosedLevel = null,Object? confidenceWeight = freezed,}) {
  return _then(_self.copyWith(
diagnosedLevel: null == diagnosedLevel ? _self.diagnosedLevel : diagnosedLevel // ignore: cast_nullable_to_non_nullable
as String,confidenceWeight: freezed == confidenceWeight ? _self.confidenceWeight : confidenceWeight // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [AssessmentResult].
extension AssessmentResultPatterns on AssessmentResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssessmentResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssessmentResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssessmentResult value)  $default,){
final _that = this;
switch (_that) {
case _AssessmentResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssessmentResult value)?  $default,){
final _that = this;
switch (_that) {
case _AssessmentResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String diagnosedLevel,  double? confidenceWeight)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssessmentResult() when $default != null:
return $default(_that.diagnosedLevel,_that.confidenceWeight);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String diagnosedLevel,  double? confidenceWeight)  $default,) {final _that = this;
switch (_that) {
case _AssessmentResult():
return $default(_that.diagnosedLevel,_that.confidenceWeight);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String diagnosedLevel,  double? confidenceWeight)?  $default,) {final _that = this;
switch (_that) {
case _AssessmentResult() when $default != null:
return $default(_that.diagnosedLevel,_that.confidenceWeight);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AssessmentResult implements AssessmentResult {
  const _AssessmentResult({required this.diagnosedLevel, this.confidenceWeight});
  factory _AssessmentResult.fromJson(Map<String, dynamic> json) => _$AssessmentResultFromJson(json);

@override final  String diagnosedLevel;
@override final  double? confidenceWeight;

/// Create a copy of AssessmentResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssessmentResultCopyWith<_AssessmentResult> get copyWith => __$AssessmentResultCopyWithImpl<_AssessmentResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssessmentResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssessmentResult&&(identical(other.diagnosedLevel, diagnosedLevel) || other.diagnosedLevel == diagnosedLevel)&&(identical(other.confidenceWeight, confidenceWeight) || other.confidenceWeight == confidenceWeight));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,diagnosedLevel,confidenceWeight);

@override
String toString() {
  return 'AssessmentResult(diagnosedLevel: $diagnosedLevel, confidenceWeight: $confidenceWeight)';
}


}

/// @nodoc
abstract mixin class _$AssessmentResultCopyWith<$Res> implements $AssessmentResultCopyWith<$Res> {
  factory _$AssessmentResultCopyWith(_AssessmentResult value, $Res Function(_AssessmentResult) _then) = __$AssessmentResultCopyWithImpl;
@override @useResult
$Res call({
 String diagnosedLevel, double? confidenceWeight
});




}
/// @nodoc
class __$AssessmentResultCopyWithImpl<$Res>
    implements _$AssessmentResultCopyWith<$Res> {
  __$AssessmentResultCopyWithImpl(this._self, this._then);

  final _AssessmentResult _self;
  final $Res Function(_AssessmentResult) _then;

/// Create a copy of AssessmentResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? diagnosedLevel = null,Object? confidenceWeight = freezed,}) {
  return _then(_AssessmentResult(
diagnosedLevel: null == diagnosedLevel ? _self.diagnosedLevel : diagnosedLevel // ignore: cast_nullable_to_non_nullable
as String,confidenceWeight: freezed == confidenceWeight ? _self.confidenceWeight : confidenceWeight // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
