/// 백엔드 공통 에러 코드(스펙 §3.4). 알 수 없는 값은 [unknown]으로 방어.
enum ApiErrorCode {
  unauthorized,
  forbidden,
  onboardingIncomplete,
  resourceNotFound,
  validationFailed,
  conflict,
  quotaExceeded,
  aiKillSwitchActive,
  sandboxUnavailable,
  network,
  unknown;

  static ApiErrorCode fromWire(String? code) => switch (code) {
    'UNAUTHORIZED' => unauthorized,
    'FORBIDDEN' => forbidden,
    'ONBOARDING_INCOMPLETE' => onboardingIncomplete,
    'RESOURCE_NOT_FOUND' => resourceNotFound,
    'VALIDATION_FAILED' => validationFailed,
    'CONFLICT' => conflict,
    'QUOTA_EXCEEDED' => quotaExceeded,
    'AI_KILL_SWITCH_ACTIVE' => aiKillSwitchActive,
    'SANDBOX_UNAVAILABLE' => sandboxUnavailable,
    _ => unknown,
  };
}
