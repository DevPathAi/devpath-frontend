import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String nickname,
    @JsonKey(unknownEnumValue: UserRole.unknown) required UserRole role,
    @JsonKey(unknownEnumValue: OnboardingStatus.unknown)
    required OnboardingStatus onboardingStatus,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
