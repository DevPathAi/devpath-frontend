import 'package:dp_core/dp_core.dart';

/// 인증 상태(sealed — 라우터 게이트가 분기).
sealed class AuthState {
  const AuthState();
}

/// 초기/세션 복원 중. 게이트는 이 동안 redirect를 보류한다(null 반환).
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// 미인증(토큰 없음). [error]는 직전 로그인 실패 메시지(옵션).
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.error});
  final String? error;
}

/// 인증됨. [user.onboardingStatus]로 온보딩 게이트 판정.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
}
