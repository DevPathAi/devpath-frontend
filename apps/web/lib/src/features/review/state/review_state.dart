import 'package:dp_core/dp_core.dart';

sealed class ReviewState {
  const ReviewState();

  int? get sandboxSessionId => null;
  CodeReview? get retainedReview => null;
}

class ReviewIdle extends ReviewState {
  const ReviewIdle();
}

class ReviewLoading extends ReviewState {
  const ReviewLoading({this.previous, this.sessionId});

  final CodeReview? previous;
  final int? sessionId;

  @override
  int? get sandboxSessionId => sessionId;
  @override
  CodeReview? get retainedReview => previous;
}

class ReviewLoaded extends ReviewState {
  const ReviewLoaded(this.review, {this.sessionId});
  final CodeReview review;
  final int? sessionId;

  @override
  int? get sandboxSessionId => sessionId;
  @override
  CodeReview get retainedReview => review;
}

class ReviewKillSwitch extends ReviewState {
  const ReviewKillSwitch({this.previous, this.sessionId});

  final CodeReview? previous;
  final int? sessionId;

  @override
  int? get sandboxSessionId => sessionId;
  @override
  CodeReview? get retainedReview => previous;
}
// F6-a: 대체행동(altActionLabel/onAltAction)은 P3 DpKillSwitch가 제공 —
// 상태가 아닌 위젯(ReviewPanel)에서 배선한다(라우팅 콜백이 상태에 들어가지 않게).

class ReviewQuota extends ReviewState {
  const ReviewQuota(this.retryAfterSeconds, {this.previous, this.sessionId});
  final int? retryAfterSeconds;
  final CodeReview? previous;
  final int? sessionId;

  @override
  int? get sandboxSessionId => sessionId;
  @override
  CodeReview? get retainedReview => previous;
}

class ReviewFailed extends ReviewState {
  const ReviewFailed(this.message, {this.previous, this.sessionId});
  final String message;
  final CodeReview? previous;
  final int? sessionId;

  @override
  int? get sandboxSessionId => sessionId;
  @override
  CodeReview? get retainedReview => previous;
}
