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

/// A stored session exists, but its owner could not be verified because the
/// transport/service is unavailable. This is retryable and must not be treated
/// as an explicit logout.
class AuthSessionUnavailable extends AuthState {
  const AuthSessionUnavailable(this.message);

  final String message;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
}
