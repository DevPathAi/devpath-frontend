import 'package:dp_core/dp_core.dart';

sealed class ReviewState {
  const ReviewState();
}

class ReviewIdle extends ReviewState {
  const ReviewIdle();
}

class ReviewLoading extends ReviewState {
  const ReviewLoading();
}

class ReviewLoaded extends ReviewState {
  const ReviewLoaded(this.review);
  final CodeReview review;
}

class ReviewKillSwitch extends ReviewState {
  const ReviewKillSwitch();
}
// F6-a: 대체행동(altActionLabel/onAltAction)은 P3 DpKillSwitch가 제공 —
// 상태가 아닌 위젯(ReviewPanel)에서 배선한다(라우팅 콜백이 상태에 들어가지 않게).

class ReviewQuota extends ReviewState {
  const ReviewQuota(this.retryAfterSeconds);
  final int? retryAfterSeconds;
}

class ReviewFailed extends ReviewState {
  const ReviewFailed(this.message);
  final String message;
}
