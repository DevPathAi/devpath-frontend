import 'package:json_annotation/json_annotation.dart';

/// 백엔드 enum과 1:1 매핑. 각 enum에 unknown 멤버 + 필드에서 @JsonKey(unknownEnumValue:) 사용.
@JsonEnum()
enum UserRole {
  @JsonValue('PUBLIC') public,
  @JsonValue('AUTHENTICATED') authenticated,
  @JsonValue('LEARNER') learner,
  @JsonValue('PRO') pro,
  @JsonValue('ADMIN') admin,
  @JsonValue('OWNER') owner,
  unknown,
}

@JsonEnum()
enum OnboardingStatus {
  @JsonValue('PENDING') pending,
  @JsonValue('IN_PROGRESS') inProgress,
  @JsonValue('DONE') done,
  unknown,
}
