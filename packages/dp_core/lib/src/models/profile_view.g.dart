// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_view.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileView _$ProfileViewFromJson(Map<String, dynamic> json) => _ProfileView(
  avatar: json['avatar'] as String?,
  bio: json['bio'] as String?,
  learningGoal: json['learningGoal'] as String?,
  targetTrack: json['targetTrack'] as String?,
  experienceYears: (json['experienceYears'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProfileViewToJson(_ProfileView instance) =>
    <String, dynamic>{
      'avatar': instance.avatar,
      'bio': instance.bio,
      'learningGoal': instance.learningGoal,
      'targetTrack': instance.targetTrack,
      'experienceYears': instance.experienceYears,
    };
