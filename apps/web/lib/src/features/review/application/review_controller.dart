import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/review_state.dart';

class ReviewController extends Notifier<ReviewState> {
  @override
  ReviewState build() => const ReviewIdle();

  Future<void> request(String code) async {
    state = const ReviewLoading();
    try {
      // F6-e: 본 프로토는 동기 POST — 완성 리뷰를 즉시 반환받는다.
      // 계약(§9.2)의 "비동기 결과는 폴링/알림 후 조회"와의 격차는 후속에서 폴링으로 전환
      // (CodeReview.id/status 자리 선확보로 전환 비용 절감). 리스크 절 참조.
      final json = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>('/reviews', body: {'code': code});
      state = ReviewLoaded(CodeReview.fromJson(json));
    } on ApiException catch (e) {
      state = switch (e) {
        _ when e.isKillSwitch => const ReviewKillSwitch(),
        _ when e.isQuota => ReviewQuota(e.retryAfterSeconds),
        _ => ReviewFailed(e.message),
      };
    }
  }
}

final reviewControllerProvider =
    NotifierProvider<ReviewController, ReviewState>(ReviewController.new);
