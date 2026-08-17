import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../dashboard/application/current_mission_controller.dart';
import '../../mission/state/mission_workspace_key.dart';
import '../state/review_state.dart';

/// Owner- and workspace-bound review polling coordinator.
///
/// A session identity is carried by every non-idle state. New-session polls
/// supersede older responses, while duplicate taps for the same session share
/// one request loop. The last valid review remains available through refresh
/// and failure states so transient delivery errors never blank the pane.
class ReviewController extends Notifier<ReviewState> {
  ReviewController([this.workspaceKey]);

  final MissionWorkspaceKey? workspaceKey;
  String? _ownerKey;
  var _generation = 0;
  var _disposed = false;
  int? _inFlightSessionId;
  Future<void>? _inFlight;

  @override
  ReviewState build() {
    _disposed = false;
    _inFlight = null;
    _inFlightSessionId = null;
    if (workspaceKey != null) {
      _ownerKey = ref.read(currentMissionOwnerKeyProvider);
      ref.listen(currentMissionOwnerKeyProvider, (_, nextOwner) {
        if (_disposed || nextOwner == _ownerKey) return;
        _ownerKey = nextOwner;
        _generation += 1;
        _inFlight = null;
        _inFlightSessionId = null;
        state = const ReviewIdle();
      });
    }
    ref.onDispose(() {
      _disposed = true;
      _generation += 1;
      _inFlight = null;
      _inFlightSessionId = null;
    });
    return const ReviewIdle();
  }

  /// Polls `GET /reviews?sandboxSessionId={id}` until a terminal review.
  Future<void> pollForSession(
    int sandboxSessionId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) {
    if (sandboxSessionId <= 0 ||
        sandboxSessionId > MissionWorkspaceKey.maxSafeInteger) {
      return Future.error(
        ArgumentError.value(
          sandboxSessionId,
          'sandboxSessionId',
          'must be a positive JS-safe ID',
        ),
      );
    }
    final active = _inFlight;
    if (active != null && _inFlightSessionId == sandboxSessionId) {
      return active;
    }

    _generation += 1;
    final generation = _generation;
    final ownerKey = _ownerKey;
    final previous = state.retainedReview;
    state = ReviewLoading(previous: previous, sessionId: sandboxSessionId);

    late final Future<void> tracked;
    tracked =
        _poll(
          sandboxSessionId,
          generation: generation,
          ownerKey: ownerKey,
          previous: previous,
          interval: interval,
          maxAttempts: maxAttempts,
        ).whenComplete(() {
          if (identical(_inFlight, tracked)) {
            _inFlight = null;
            _inFlightSessionId = null;
          }
        });
    _inFlightSessionId = sandboxSessionId;
    _inFlight = tracked;
    return tracked;
  }

  Future<void> _poll(
    int sandboxSessionId, {
    required int generation,
    required String? ownerKey,
    required CodeReview? previous,
    required Duration interval,
    required int maxAttempts,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!_isCurrent(generation, ownerKey)) return;
      try {
        final json = await ref
            .read(apiClientProvider)
            .get<Map<String, dynamic>>(
              '/reviews',
              query: {'sandboxSessionId': '$sandboxSessionId'},
            );
        if (!_isCurrent(generation, ownerKey)) return;
        final review = CodeReview.fromJson(json);
        switch (review.status) {
          case 'DONE':
            state = ReviewLoaded(review, sessionId: sandboxSessionId);
            return;
          case 'FAILED':
            state = ReviewFailed(
              'AI 리뷰 생성에 실패했습니다',
              previous: previous,
              sessionId: sandboxSessionId,
            );
            return;
          default:
            break;
        }
      } on ApiException catch (error) {
        if (!_isCurrent(generation, ownerKey)) return;
        if (error.isKillSwitch) {
          state = ReviewKillSwitch(
            previous: previous,
            sessionId: sandboxSessionId,
          );
          return;
        }
        if (error.isQuota) {
          state = ReviewQuota(
            error.retryAfterSeconds,
            previous: previous,
            sessionId: sandboxSessionId,
          );
          return;
        }
        // A review is created asynchronously; both normalized resource-not-
        // found and Spring's bare 404 mean "not ready yet".
        if (error.code != ApiErrorCode.resourceNotFound &&
            error.status != 404) {
          state = ReviewFailed(
            error.message,
            previous: previous,
            sessionId: sandboxSessionId,
          );
          return;
        }
      } on Object {
        if (_isCurrent(generation, ownerKey)) {
          state = ReviewFailed(
            '리뷰를 불러오지 못했어요.',
            previous: previous,
            sessionId: sandboxSessionId,
          );
        }
        return;
      }
      if (attempt + 1 < maxAttempts) {
        await Future<void>.delayed(interval);
      }
    }
    if (_isCurrent(generation, ownerKey)) {
      state = ReviewFailed(
        'AI 리뷰 시간이 초과되었습니다',
        previous: previous,
        sessionId: sandboxSessionId,
      );
    }
  }

  bool _isCurrent(int generation, String? ownerKey) =>
      !_disposed && generation == _generation && ownerKey == _ownerKey;
}

final reviewControllerFamilyProvider =
    NotifierProvider.family<
      ReviewController,
      ReviewState,
      MissionWorkspaceKey?
    >(ReviewController.new);

/// Backward-compatible standalone `/sandbox` review state.
final reviewControllerProvider = reviewControllerFamilyProvider(null);
