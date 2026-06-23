import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/review_state.dart';

class ReviewController extends Notifier<ReviewState> {
  @override
  ReviewState build() => const ReviewIdle();

  /// 실행 완료 후 sandboxSessionId로 리뷰가 DONE/FAILED로 수렴할 때까지 폴링.
  /// GET /reviews?sandboxSessionId={id} — status PENDING→재시도, DONE→ReviewLoaded,
  /// FAILED→ReviewFailed. killSwitch/quota ApiException→각 상태. 타임아웃→ReviewFailed.
  Future<void> pollForSession(
    int sandboxSessionId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) async {
    state = const ReviewLoading();
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final json = await ref
            .read(apiClientProvider)
            .get<Map<String, dynamic>>(
              '/reviews',
              query: {'sandboxSessionId': '$sandboxSessionId'},
            );
        final review = CodeReview.fromJson(json);
        switch (review.status) {
          case 'DONE':
            state = ReviewLoaded(review);
            return;
          case 'FAILED':
            state = const ReviewFailed('AI 리뷰 생성에 실패했습니다');
            return;
          default:
            // PENDING 또는 null — 계속 폴링
            break;
        }
      } on ApiException catch (e) {
        if (e.isKillSwitch) {
          state = const ReviewKillSwitch();
          return;
        }
        if (e.isQuota) {
          state = ReviewQuota(e.retryAfterSeconds);
          return;
        }
        // RESOURCE_NOT_FOUND: 아직 리뷰 미생성 — 계속 폴링
        if (e.code == ApiErrorCode.resourceNotFound) {
          // fall through to delay and retry
        } else {
          state = ReviewFailed(e.message);
          return;
        }
      }
      await Future<void>.delayed(interval);
    }
    state = const ReviewFailed('AI 리뷰 시간이 초과되었습니다');
  }

  // ignore: unused_element
  /// @deprecated 동기 POST 프로토(F6-e 이전). 폴링 전환 후 미사용.
  Future<void> request(String code) async {
    state = const ReviewLoading();
    try {
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
