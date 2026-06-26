import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../state/onboarding_state.dart';

/// 최소 진단 제출(GitHub 핸들). web `OnboardingController`와 동일 계약(`POST /onboarding`).
/// 성공 시 갱신된 사용자로 auth를 갱신 → 라우터 게이트가 진입점(/home)으로 보낸다.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingIdle();

  Future<void> submit({required String githubHandle}) async {
    state = const OnboardingSubmitting();
    try {
      final json = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/onboarding',
            body: {'githubHandle': githubHandle},
          );
      final user = User.fromJson((json['user'] as Map).cast<String, dynamic>());
      ref.read(authControllerProvider.notifier).onboardingCompleted(user);
      state = const OnboardingDone();
    } on ApiException catch (e) {
      state = OnboardingError(e.message);
    }
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
