import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';

/// 앱-레벨 인터셉터: 응답이 403 ONBOARDING_INCOMPLETE면 [onOnboardingIncomplete]로
/// 온보딩 게이트 재평가를 트리거한다.
///
/// dp_core는 라우터/auth를 모른다(레이어링 보존) — 반응은 앱에서 주입한다.
/// 에러는 삼키지 않고 그대로 전파한다(정규화 인터셉터가 후속 처리).
class OnboardingGateInterceptor extends Interceptor {
  OnboardingGateInterceptor(this.onOnboardingIncomplete);

  final void Function() onOnboardingIncomplete;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (ApiException.fromDio(err).isOnboardingIncomplete) {
      onOnboardingIncomplete();
    }
    handler.next(err);
  }
}
