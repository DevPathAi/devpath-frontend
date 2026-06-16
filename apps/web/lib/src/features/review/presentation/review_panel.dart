import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // F6-a: KILL_SWITCH 대체행동 라우팅(context.go)

import '../application/review_controller.dart';
import '../state/review_state.dart';

/// SBX 3페인의 리뷰 칸. 상태별 렌더(요청/생성중/결과/점검/한도/실패).
class ReviewPanel extends ConsumerWidget {
  const ReviewPanel({super.key, required this.onRequest});
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reviewControllerProvider);
    return switch (s) {
      ReviewIdle() => DpEmpty(
        icon: DpIcons.content,
        title: 'AI 코드리뷰',
        message: '코드를 작성하고 리뷰를 받아보세요.',
        actionLabel: 'AI 리뷰 요청',
        onAction: onRequest,
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
      ReviewFailed(:final message) => DpError(
        message: message,
        onRetry: onRequest,
      ),
      ReviewLoaded(:final review) => _ReviewBody(review: review),
    };
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.review});
  final CodeReview review;

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
      ],
    );
  }
}
