/// 온보딩(최소 진단) 제출 상태 머신.
sealed class OnboardingState {
  const OnboardingState();
}

class OnboardingIdle extends OnboardingState {
  const OnboardingIdle();
}

class OnboardingSubmitting extends OnboardingState {
  const OnboardingSubmitting();
}

class OnboardingDone extends OnboardingState {
  const OnboardingDone();
}

class OnboardingError extends OnboardingState {
  const OnboardingError(this.message);
  final String message;
}
