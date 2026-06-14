import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../state/onboarding_state.dart';

/// 최소 진단 제출(GitHub 핸들). 실제 문항은 외부 06_화면_기능_정의서로 정렬.
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
