// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  email: json['email'] as String?,
  nickname: json['nickname'] as String,
  role: $enumDecode(
    _$UserRoleEnumMap,
    json['role'],
    unknownValue: UserRole.unknown,
  ),
  onboardingStatus: $enumDecode(
    _$OnboardingStatusEnumMap,
    json['onboardingStatus'],
    unknownValue: OnboardingStatus.unknown,
  ),
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'nickname': instance.nickname,
  'role': _$UserRoleEnumMap[instance.role]!,
  'onboardingStatus': _$OnboardingStatusEnumMap[instance.onboardingStatus]!,
};

const _$UserRoleEnumMap = {
  UserRole.public: 'PUBLIC',
  UserRole.authenticated: 'AUTHENTICATED',
  UserRole.learner: 'LEARNER',
  UserRole.pro: 'PRO',
  UserRole.admin: 'ADMIN',
  UserRole.owner: 'OWNER',
  UserRole.unknown: 'unknown',
};

const _$OnboardingStatusEnumMap = {
  OnboardingStatus.pending: 'PENDING',
  OnboardingStatus.inProgress: 'IN_PROGRESS',
  OnboardingStatus.done: 'DONE',
  OnboardingStatus.unknown: 'unknown',
};
