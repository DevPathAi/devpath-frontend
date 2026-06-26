// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lcs_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LcsFieldUnavailable {

 String get field; String get reason;
/// Create a copy of LcsFieldUnavailable
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LcsFieldUnavailableCopyWith<LcsFieldUnavailable> get copyWith => _$LcsFieldUnavailableCopyWithImpl<LcsFieldUnavailable>(this as LcsFieldUnavailable, _$identity);

  /// Serializes this LcsFieldUnavailable to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LcsFieldUnavailable&&(identical(other.field, field) || other.field == field)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,field,reason);

@override
String toString() {
  return 'LcsFieldUnavailable(field: $field, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $LcsFieldUnavailableCopyWith<$Res>  {
  factory $LcsFieldUnavailableCopyWith(LcsFieldUnavailable value, $Res Function(LcsFieldUnavailable) _then) = _$LcsFieldUnavailableCopyWithImpl;
@useResult
$Res call({
 String field, String reason
});




}
/// @nodoc
class _$LcsFieldUnavailableCopyWithImpl<$Res>
    implements $LcsFieldUnavailableCopyWith<$Res> {
  _$LcsFieldUnavailableCopyWithImpl(this._self, this._then);

  final LcsFieldUnavailable _self;
  final $Res Function(LcsFieldUnavailable) _then;

/// Create a copy of LcsFieldUnavailable
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? field = null,Object? reason = null,}) {
  return _then(_self.copyWith(
field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LcsFieldUnavailable].
extension LcsFieldUnavailablePatterns on LcsFieldUnavailable {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LcsFieldUnavailable value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LcsFieldUnavailable() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LcsFieldUnavailable value)  $default,){
final _that = this;
switch (_that) {
case _LcsFieldUnavailable():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LcsFieldUnavailable value)?  $default,){
final _that = this;
switch (_that) {
case _LcsFieldUnavailable() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String field,  String reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LcsFieldUnavailable() when $default != null:
return $default(_that.field,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String field,  String reason)  $default,) {final _that = this;
switch (_that) {
case _LcsFieldUnavailable():
return $default(_that.field,_that.reason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String field,  String reason)?  $default,) {final _that = this;
switch (_that) {
case _LcsFieldUnavailable() when $default != null:
return $default(_that.field,_that.reason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LcsFieldUnavailable implements LcsFieldUnavailable {
  const _LcsFieldUnavailable({required this.field, required this.reason});
  factory _LcsFieldUnavailable.fromJson(Map<String, dynamic> json) => _$LcsFieldUnavailableFromJson(json);

@override final  String field;
@override final  String reason;

/// Create a copy of LcsFieldUnavailable
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LcsFieldUnavailableCopyWith<_LcsFieldUnavailable> get copyWith => __$LcsFieldUnavailableCopyWithImpl<_LcsFieldUnavailable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LcsFieldUnavailableToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LcsFieldUnavailable&&(identical(other.field, field) || other.field == field)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,field,reason);

@override
String toString() {
  return 'LcsFieldUnavailable(field: $field, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$LcsFieldUnavailableCopyWith<$Res> implements $LcsFieldUnavailableCopyWith<$Res> {
  factory _$LcsFieldUnavailableCopyWith(_LcsFieldUnavailable value, $Res Function(_LcsFieldUnavailable) _then) = __$LcsFieldUnavailableCopyWithImpl;
@override @useResult
$Res call({
 String field, String reason
});




}
/// @nodoc
class __$LcsFieldUnavailableCopyWithImpl<$Res>
    implements _$LcsFieldUnavailableCopyWith<$Res> {
  __$LcsFieldUnavailableCopyWithImpl(this._self, this._then);

  final _LcsFieldUnavailable _self;
  final $Res Function(_LcsFieldUnavailable) _then;

/// Create a copy of LcsFieldUnavailable
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field = null,Object? reason = null,}) {
  return _then(_LcsFieldUnavailable(
field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$LcsDraft {

 String get draftId; DateTime get expiresAt; Map<String, dynamic> get content; List<String> get fieldsAvailable; List<LcsFieldUnavailable> get fieldsUnavailable;
/// Create a copy of LcsDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LcsDraftCopyWith<LcsDraft> get copyWith => _$LcsDraftCopyWithImpl<LcsDraft>(this as LcsDraft, _$identity);

  /// Serializes this LcsDraft to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LcsDraft&&(identical(other.draftId, draftId) || other.draftId == draftId)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other.content, content)&&const DeepCollectionEquality().equals(other.fieldsAvailable, fieldsAvailable)&&const DeepCollectionEquality().equals(other.fieldsUnavailable, fieldsUnavailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,draftId,expiresAt,const DeepCollectionEquality().hash(content),const DeepCollectionEquality().hash(fieldsAvailable),const DeepCollectionEquality().hash(fieldsUnavailable));

@override
String toString() {
  return 'LcsDraft(draftId: $draftId, expiresAt: $expiresAt, content: $content, fieldsAvailable: $fieldsAvailable, fieldsUnavailable: $fieldsUnavailable)';
}


}

/// @nodoc
abstract mixin class $LcsDraftCopyWith<$Res>  {
  factory $LcsDraftCopyWith(LcsDraft value, $Res Function(LcsDraft) _then) = _$LcsDraftCopyWithImpl;
@useResult
$Res call({
 String draftId, DateTime expiresAt, Map<String, dynamic> content, List<String> fieldsAvailable, List<LcsFieldUnavailable> fieldsUnavailable
});




}
/// @nodoc
class _$LcsDraftCopyWithImpl<$Res>
    implements $LcsDraftCopyWith<$Res> {
  _$LcsDraftCopyWithImpl(this._self, this._then);

  final LcsDraft _self;
  final $Res Function(LcsDraft) _then;

/// Create a copy of LcsDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? draftId = null,Object? expiresAt = null,Object? content = null,Object? fieldsAvailable = null,Object? fieldsUnavailable = null,}) {
  return _then(_self.copyWith(
draftId: null == draftId ? _self.draftId : draftId // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,fieldsAvailable: null == fieldsAvailable ? _self.fieldsAvailable : fieldsAvailable // ignore: cast_nullable_to_non_nullable
as List<String>,fieldsUnavailable: null == fieldsUnavailable ? _self.fieldsUnavailable : fieldsUnavailable // ignore: cast_nullable_to_non_nullable
as List<LcsFieldUnavailable>,
  ));
}

}


/// Adds pattern-matching-related methods to [LcsDraft].
extension LcsDraftPatterns on LcsDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LcsDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LcsDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LcsDraft value)  $default,){
final _that = this;
switch (_that) {
case _LcsDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LcsDraft value)?  $default,){
final _that = this;
switch (_that) {
case _LcsDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String draftId,  DateTime expiresAt,  Map<String, dynamic> content,  List<String> fieldsAvailable,  List<LcsFieldUnavailable> fieldsUnavailable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LcsDraft() when $default != null:
return $default(_that.draftId,_that.expiresAt,_that.content,_that.fieldsAvailable,_that.fieldsUnavailable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String draftId,  DateTime expiresAt,  Map<String, dynamic> content,  List<String> fieldsAvailable,  List<LcsFieldUnavailable> fieldsUnavailable)  $default,) {final _that = this;
switch (_that) {
case _LcsDraft():
return $default(_that.draftId,_that.expiresAt,_that.content,_that.fieldsAvailable,_that.fieldsUnavailable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String draftId,  DateTime expiresAt,  Map<String, dynamic> content,  List<String> fieldsAvailable,  List<LcsFieldUnavailable> fieldsUnavailable)?  $default,) {final _that = this;
switch (_that) {
case _LcsDraft() when $default != null:
return $default(_that.draftId,_that.expiresAt,_that.content,_that.fieldsAvailable,_that.fieldsUnavailable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LcsDraft implements LcsDraft {
  const _LcsDraft({required this.draftId, required this.expiresAt, final  Map<String, dynamic> content = const <String, dynamic>{}, final  List<String> fieldsAvailable = const <String>[], final  List<LcsFieldUnavailable> fieldsUnavailable = const <LcsFieldUnavailable>[]}): _content = content,_fieldsAvailable = fieldsAvailable,_fieldsUnavailable = fieldsUnavailable;
  factory _LcsDraft.fromJson(Map<String, dynamic> json) => _$LcsDraftFromJson(json);

@override final  String draftId;
@override final  DateTime expiresAt;
 final  Map<String, dynamic> _content;
@override@JsonKey() Map<String, dynamic> get content {
  if (_content is EqualUnmodifiableMapView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_content);
}

 final  List<String> _fieldsAvailable;
@override@JsonKey() List<String> get fieldsAvailable {
  if (_fieldsAvailable is EqualUnmodifiableListView) return _fieldsAvailable;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fieldsAvailable);
}

 final  List<LcsFieldUnavailable> _fieldsUnavailable;
@override@JsonKey() List<LcsFieldUnavailable> get fieldsUnavailable {
  if (_fieldsUnavailable is EqualUnmodifiableListView) return _fieldsUnavailable;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fieldsUnavailable);
}


/// Create a copy of LcsDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LcsDraftCopyWith<_LcsDraft> get copyWith => __$LcsDraftCopyWithImpl<_LcsDraft>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LcsDraftToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LcsDraft&&(identical(other.draftId, draftId) || other.draftId == draftId)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other._content, _content)&&const DeepCollectionEquality().equals(other._fieldsAvailable, _fieldsAvailable)&&const DeepCollectionEquality().equals(other._fieldsUnavailable, _fieldsUnavailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,draftId,expiresAt,const DeepCollectionEquality().hash(_content),const DeepCollectionEquality().hash(_fieldsAvailable),const DeepCollectionEquality().hash(_fieldsUnavailable));

@override
String toString() {
  return 'LcsDraft(draftId: $draftId, expiresAt: $expiresAt, content: $content, fieldsAvailable: $fieldsAvailable, fieldsUnavailable: $fieldsUnavailable)';
}


}

/// @nodoc
abstract mixin class _$LcsDraftCopyWith<$Res> implements $LcsDraftCopyWith<$Res> {
  factory _$LcsDraftCopyWith(_LcsDraft value, $Res Function(_LcsDraft) _then) = __$LcsDraftCopyWithImpl;
@override @useResult
$Res call({
 String draftId, DateTime expiresAt, Map<String, dynamic> content, List<String> fieldsAvailable, List<LcsFieldUnavailable> fieldsUnavailable
});




}
/// @nodoc
class __$LcsDraftCopyWithImpl<$Res>
    implements _$LcsDraftCopyWith<$Res> {
  __$LcsDraftCopyWithImpl(this._self, this._then);

  final _LcsDraft _self;
  final $Res Function(_LcsDraft) _then;

/// Create a copy of LcsDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? draftId = null,Object? expiresAt = null,Object? content = null,Object? fieldsAvailable = null,Object? fieldsUnavailable = null,}) {
  return _then(_LcsDraft(
draftId: null == draftId ? _self.draftId : draftId // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,fieldsAvailable: null == fieldsAvailable ? _self._fieldsAvailable : fieldsAvailable // ignore: cast_nullable_to_non_nullable
as List<String>,fieldsUnavailable: null == fieldsUnavailable ? _self._fieldsUnavailable : fieldsUnavailable // ignore: cast_nullable_to_non_nullable
as List<LcsFieldUnavailable>,
  ));
}


}


/// @nodoc
mixin _$LcsSnapshotView {

 int get id; DateTime get createdAt; Map<String, dynamic> get content; String get renderedFor;
/// Create a copy of LcsSnapshotView
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LcsSnapshotViewCopyWith<LcsSnapshotView> get copyWith => _$LcsSnapshotViewCopyWithImpl<LcsSnapshotView>(this as LcsSnapshotView, _$identity);

  /// Serializes this LcsSnapshotView to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LcsSnapshotView&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.content, content)&&(identical(other.renderedFor, renderedFor) || other.renderedFor == renderedFor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,const DeepCollectionEquality().hash(content),renderedFor);

@override
String toString() {
  return 'LcsSnapshotView(id: $id, createdAt: $createdAt, content: $content, renderedFor: $renderedFor)';
}


}

/// @nodoc
abstract mixin class $LcsSnapshotViewCopyWith<$Res>  {
  factory $LcsSnapshotViewCopyWith(LcsSnapshotView value, $Res Function(LcsSnapshotView) _then) = _$LcsSnapshotViewCopyWithImpl;
@useResult
$Res call({
 int id, DateTime createdAt, Map<String, dynamic> content, String renderedFor
});




}
/// @nodoc
class _$LcsSnapshotViewCopyWithImpl<$Res>
    implements $LcsSnapshotViewCopyWith<$Res> {
  _$LcsSnapshotViewCopyWithImpl(this._self, this._then);

  final LcsSnapshotView _self;
  final $Res Function(LcsSnapshotView) _then;

/// Create a copy of LcsSnapshotView
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? createdAt = null,Object? content = null,Object? renderedFor = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,renderedFor: null == renderedFor ? _self.renderedFor : renderedFor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LcsSnapshotView].
extension LcsSnapshotViewPatterns on LcsSnapshotView {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LcsSnapshotView value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LcsSnapshotView() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LcsSnapshotView value)  $default,){
final _that = this;
switch (_that) {
case _LcsSnapshotView():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LcsSnapshotView value)?  $default,){
final _that = this;
switch (_that) {
case _LcsSnapshotView() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  DateTime createdAt,  Map<String, dynamic> content,  String renderedFor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LcsSnapshotView() when $default != null:
return $default(_that.id,_that.createdAt,_that.content,_that.renderedFor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  DateTime createdAt,  Map<String, dynamic> content,  String renderedFor)  $default,) {final _that = this;
switch (_that) {
case _LcsSnapshotView():
return $default(_that.id,_that.createdAt,_that.content,_that.renderedFor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  DateTime createdAt,  Map<String, dynamic> content,  String renderedFor)?  $default,) {final _that = this;
switch (_that) {
case _LcsSnapshotView() when $default != null:
return $default(_that.id,_that.createdAt,_that.content,_that.renderedFor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LcsSnapshotView implements LcsSnapshotView {
  const _LcsSnapshotView({required this.id, required this.createdAt, final  Map<String, dynamic> content = const <String, dynamic>{}, this.renderedFor = 'answerer'}): _content = content;
  factory _LcsSnapshotView.fromJson(Map<String, dynamic> json) => _$LcsSnapshotViewFromJson(json);

@override final  int id;
@override final  DateTime createdAt;
 final  Map<String, dynamic> _content;
@override@JsonKey() Map<String, dynamic> get content {
  if (_content is EqualUnmodifiableMapView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_content);
}

@override@JsonKey() final  String renderedFor;

/// Create a copy of LcsSnapshotView
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LcsSnapshotViewCopyWith<_LcsSnapshotView> get copyWith => __$LcsSnapshotViewCopyWithImpl<_LcsSnapshotView>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LcsSnapshotViewToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LcsSnapshotView&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.renderedFor, renderedFor) || other.renderedFor == renderedFor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,const DeepCollectionEquality().hash(_content),renderedFor);

@override
String toString() {
  return 'LcsSnapshotView(id: $id, createdAt: $createdAt, content: $content, renderedFor: $renderedFor)';
}


}

/// @nodoc
abstract mixin class _$LcsSnapshotViewCopyWith<$Res> implements $LcsSnapshotViewCopyWith<$Res> {
  factory _$LcsSnapshotViewCopyWith(_LcsSnapshotView value, $Res Function(_LcsSnapshotView) _then) = __$LcsSnapshotViewCopyWithImpl;
@override @useResult
$Res call({
 int id, DateTime createdAt, Map<String, dynamic> content, String renderedFor
});




}
/// @nodoc
class __$LcsSnapshotViewCopyWithImpl<$Res>
    implements _$LcsSnapshotViewCopyWith<$Res> {
  __$LcsSnapshotViewCopyWithImpl(this._self, this._then);

  final _LcsSnapshotView _self;
  final $Res Function(_LcsSnapshotView) _then;

/// Create a copy of LcsSnapshotView
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? content = null,Object? renderedFor = null,}) {
  return _then(_LcsSnapshotView(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,renderedFor: null == renderedFor ? _self.renderedFor : renderedFor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
