import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // F6-a: KILL_SWITCH 대체행동 라우팅(context.go)

import '../../dashboard/application/current_mission_controller.dart';
import '../../mission/state/mission_workspace_key.dart';
import '../../sandbox/application/run_controller.dart';
import '../../sandbox/state/run_state.dart';
import '../application/review_controller.dart';
import '../state/review_state.dart';
import '../../support/presentation/supportable_error.dart';

/// SBX 3페인의 리뷰 칸. 상태별 렌더(요청/생성중/결과/점검/한도/실패).
/// F6-e: RunDone.sandboxSessionId 감지 시 자동으로 pollForSession 트리거.
class ReviewPanel extends ConsumerStatefulWidget {
  const ReviewPanel({
    super.key,
    required this.onRequest,
    this.workspaceKey,
    this.nextAction,
  });

  /// 수동 리뷰 요청 또는 재시도 콜백(폴링 재시도 포함).
  final VoidCallback onRequest;
  final MissionWorkspaceKey? workspaceKey;
  final Widget? nextAction;

  @override
  ConsumerState<ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends ConsumerState<ReviewPanel> {
  /// 중복 폴링 가드. DB session 번호만 비교하면 다른 owner/workspace에서
  /// 같은 번호가 재사용될 때 새 리뷰를 건너뛸 수 있으므로 전체 identity를 묶는다.
  ({String? ownerKey, MissionWorkspaceKey? workspaceKey, int sessionId})?
  _lastPolled;

  @override
  Widget build(BuildContext context) {
    final runProvider = runControllerFamilyProvider(widget.workspaceKey);
    final reviewProvider = reviewControllerFamilyProvider(widget.workspaceKey);
    ref.listen<RunState>(runProvider, (_, next) => _maybePoll(next));
    final run = ref.watch(runProvider);
    final s = ref.watch(reviewProvider);
    final pollIdentity = _pollIdentity(run);
    if (pollIdentity != null &&
        pollIdentity != _lastPolled &&
        s.sandboxSessionId != pollIdentity.sessionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybePoll(ref.read(runProvider));
      });
    }

    if (s.retainedReview case final previous?) {
      if (s is! ReviewLoaded) {
        return _ReviewWithStatus(
          review: previous,
          status: s,
          onRetry: _requestCurrentSession,
        );
      }
    }
    return switch (s) {
      ReviewIdle() => DpEmpty(
        icon: DpIcons.content,
        title: 'AI 코드리뷰',
        message: '코드를 작성하고 리뷰를 받아보세요.',
        actionLabel: widget.workspaceKey == null ? 'AI 리뷰 요청' : null,
        onAction: widget.workspaceKey == null ? _requestCurrentSession : null,
      ),
      ReviewLoading() => const DpLoading(label: '리뷰 생성 중…'),
      // F6-a: P3 DpKillSwitch의 대체행동(altActionLabel/onAltAction)을 배선 —
      // 핵심가치 다운(DD4) 시 사용자에게 최소 1개 대체 경로 제공.
      ReviewKillSwitch() => DpKillSwitch(
        altActionLabel: '커뮤니티 둘러보기',
        onAltAction: () => context.go('/community'),
      ),
      // F6-b: Retry-After null 안전 — `?? 0`(0초 오안내) 제거.
      // null/음수면 DpQuota가 "잠시 후 다시 시도해 주세요" 무기한 문구로 분기.
      ReviewQuota(:final retryAfterSeconds) => DpQuota(
        retryAfterSeconds: retryAfterSeconds,
      ),
      ReviewFailed(:final message) =>
        widget.workspaceKey == null
            ? SupportableError(
                message: message,
                onRetry: _requestCurrentSession,
              )
            : _ContextualReviewFailure(
                message: message,
                onRetry: _requestCurrentSession,
              ),
      ReviewLoaded(:final review) => _ReviewBody(
        review: review,
        nextAction: widget.nextAction,
      ),
    };
  }

  void _maybePoll(RunState run) {
    final identity = _pollIdentity(run);
    if (identity == null || identity == _lastPolled) return;
    _lastPolled = identity;
    ref
        .read(reviewControllerFamilyProvider(widget.workspaceKey).notifier)
        .pollForSession(identity.sessionId);
  }

  void _requestCurrentSession() {
    final run = ref.read(runControllerFamilyProvider(widget.workspaceKey));
    final sessionId = _reviewableSessionId(run);
    if (sessionId == null) {
      widget.onRequest();
      return;
    }
    // Manual retry is intentional even if this session was auto-polled before.
    _lastPolled = _pollIdentity(run);
    ref
        .read(reviewControllerFamilyProvider(widget.workspaceKey).notifier)
        .pollForSession(sessionId);
  }

  int? _reviewableSessionId(RunState run) => switch (run) {
    RunDone(:final sandboxSessionId) => sandboxSessionId,
    RunTerminal(:final sandboxSessionId) => sandboxSessionId,
    _ => null,
  };

  ({String? ownerKey, MissionWorkspaceKey? workspaceKey, int sessionId})?
  _pollIdentity(RunState run) {
    final sessionId = _reviewableSessionId(run);
    if (sessionId == null) return null;
    return (
      ownerKey: widget.workspaceKey == null
          ? null
          : ref.read(currentMissionOwnerKeyProvider),
      workspaceKey: widget.workspaceKey,
      sessionId: sessionId,
    );
  }
}

/// The workspace-level Next Action Band remains the sole primary action.
/// Review retry is contextual recovery, so it stays a secondary action while
/// retaining the shared support/report affordance.
class _ContextualReviewFailure extends StatelessWidget {
  const _ContextualReviewFailure({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: SupportableError(message: message)),
      Padding(
        padding: const EdgeInsets.only(bottom: DpSpacing.md),
        child: TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ),
    ],
  );
}

class _ReviewWithStatus extends StatelessWidget {
  const _ReviewWithStatus({
    required this.review,
    required this.status,
    required this.onRetry,
  });

  final CodeReview review;
  final ReviewState status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: _ReviewBody(review: review)),
      Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          color: context.dpColors.accentSoft,
          padding: const EdgeInsets.symmetric(
            horizontal: DpSpacing.md,
            vertical: DpSpacing.sm,
          ),
          child: Row(
            children: [
              if (status is ReviewLoading) ...[
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: DpSpacing.sm),
              ] else
                Icon(DpIcons.error, size: 18, color: context.dpColors.danger),
              Expanded(child: Text(_message)),
              if (status is ReviewFailed)
                TextButton(onPressed: onRetry, child: const Text('다시 시도')),
              if (status is ReviewKillSwitch)
                TextButton(
                  onPressed: () => context.go('/community'),
                  child: const Text('커뮤니티'),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  String get _message => switch (status) {
    ReviewLoading() => '새 리뷰를 확인하는 중…',
    ReviewFailed(:final message) => message,
    ReviewKillSwitch() => 'AI 리뷰 기능을 점검하고 있어요.',
    ReviewQuota(:final retryAfterSeconds) =>
      retryAfterSeconds != null && retryAfterSeconds > 0
          ? '$retryAfterSeconds초 후 리뷰를 다시 시도해 주세요.'
          : '잠시 후 리뷰를 다시 시도해 주세요.',
    _ => '리뷰 상태를 다시 확인해 주세요.',
  };
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.review, this.nextAction});
  final CodeReview review;
  final Widget? nextAction;

  Color _sevColor(BuildContext context, String sev) {
    final c = context.dpColors;
    return switch (sev) {
      'error' => c.danger,
      'warning' => c.warning,
      _ => c.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    Widget issues(String title, List<ReviewIssue> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DpSpacing.md),
        Text(title, style: text.titleMedium),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(top: DpSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  DpIcons.dotSmall,
                  size: 8,
                  color: _sevColor(context, i.severity),
                ),
                const SizedBox(width: DpSpacing.sm),
                Expanded(
                  child: Text(
                    i.line != null ? 'L${i.line} · ${i.message}' : i.message,
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.all(DpSpacing.lg),
      children: [
        Row(
          children: [
            Text('신뢰도', style: text.titleMedium),
            const Spacer(),
            Text(
              '${review.confidence}%',
              style: text.titleMedium?.copyWith(color: c.primaryText),
            ),
          ],
        ),
        const SizedBox(height: DpSpacing.xs),
        LinearProgressIndicator(value: review.confidence / 100),
        if (review.strengths.isNotEmpty) ...[
          const SizedBox(height: DpSpacing.md),
          Text('잘한 점', style: text.titleMedium),
          for (final s in review.strengths)
            Padding(
              padding: const EdgeInsets.only(top: DpSpacing.xs),
              child: Row(
                children: [
                  Icon(DpIcons.stepDone, size: 16, color: c.success),
                  const SizedBox(width: DpSpacing.sm),
                  Expanded(child: Text(s, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
        if (review.improvements.isNotEmpty) issues('개선', review.improvements),
        if (review.security.isNotEmpty) issues('보안', review.security),
        const SizedBox(height: DpSpacing.lg),
        Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(DpIcons.thumbUp),
              tooltip: '도움됨',
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(DpIcons.thumbDown),
              tooltip: '아쉬움',
            ),
          ],
        ),
        if (nextAction case final action?) ...[
          const SizedBox(height: DpSpacing.md),
          action,
        ],
      ],
    );
  }
}
