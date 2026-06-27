import 'package:dp_core/dp_core.dart';

/// 인증 상태 머신. 라우터 게이트(gateRedirect)가 sealed 패턴으로 분기한다.
sealed class AuthState {
  const AuthState();
}

/// 세션 복원 진행 중(앱 부팅 1회) — 모든 리다이렉트 보류.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.error});
  final String? error;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
}
