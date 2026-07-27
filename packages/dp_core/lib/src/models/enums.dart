import 'package:json_annotation/json_annotation.dart';

/// 백엔드 enum과 1:1 매핑. 각 enum에 unknown 멤버 + 필드에서 @JsonKey(unknownEnumValue:) 사용.
@JsonEnum()
enum UserRole {
  @JsonValue('PUBLIC')
  public,
  @JsonValue('AUTHENTICATED')
  authenticated,
  @JsonValue('LEARNER')
  learner,
  @JsonValue('PRO')
  pro,
  @JsonValue('ADMIN')
  admin,
  @JsonValue('OWNER')
  owner,
  unknown,
}

@JsonEnum()
enum OnboardingStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('IN_PROGRESS')
  inProgress,
  @JsonValue('DONE')
  done,
  unknown,
}

/// 개인정보/약관 동의 게이트 상태. `PENDING`=필수 동의 미완(회원가입 gate 노출),
/// `DONE`=필수 2종(TERMS·PRIVACY) 동의 완료. `onboardingStatus`와 평행하며
/// 라우터 게이트에서 consent가 onboarding보다 앞선다.
@JsonEnum()
enum ConsentStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('DONE')
  done,
  unknown,
}
