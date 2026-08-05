import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/reports_controller.dart';
import '../data/report.dart';
import '../state/reports_state.dart';

/// 신고 처리 화면.
///
/// 이번 범위에서 관리자는 **판정만** 한다 — 콘텐츠를 내리는 기능이 백엔드에 아직 없다.
/// 대신 대상 경로를 함께 보여줘 수동 대응 경로를 남긴다.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  /// (라벨, status 값). null 은 전체.
  ///
  /// 필터는 **상태**, 버튼은 **행동**이라 말을 구분한다 — 둘 다 "처리완료"로 두면 화면에
  /// 같은 낱말이 두 뜻으로 나타난다.
  static const _filters = <(String, String?)>[
    ('미처리', 'OPEN'),
    ('처리됨', 'RESOLVED'),
    ('기각됨', 'REJECTED'),
    ('전체', null),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reportsProvider);
    final n = ref.read(reportsProvider.notifier);
    final current = s is ReportsLoaded ? s.status : 'OPEN';

    return Scaffold(
      body: Column(
        children: [
          const DpPageHeader(
            title: '신고 처리',
            description: '커뮤니티 신고를 검토하고 판정합니다',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DpSpacing.lg,
              DpSpacing.md,
              DpSpacing.lg,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String?>(
                segments: [
                  for (final (label, value) in _filters)
                    ButtonSegment(value: value, label: Text(label)),
                ],
                selected: {current},
                showSelectedIcon: false,
                onSelectionChanged: (sel) => n.load(status: sel.first),
              ),
            ),
          ),
          Expanded(
            child: switch (s) {
              ReportsLoading() => const DpLoading(),
              ReportsFailed(:final message) => DpError(
                message: message,
                onRetry: () => n.load(status: current),
              ),
              ReportsLoaded(:final reports) when reports.isEmpty =>
                const DpEmpty(icon: DpIcons.empty, title: '해당하는 신고가 없어요'),
              ReportsLoaded(:final reports) => ListView(
                padding: const EdgeInsets.all(DpSpacing.lg),
                children: [
                  for (final r in reports)
                    _ReportCard(
                      report: r,
                      onResolve: () => n.resolve(r.id, 'RESOLVE'),
                      onReject: () => n.resolve(r.id, 'REJECT'),
                    ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onResolve,
    required this.onReject,
  });

  final AdminReport report;
  final VoidCallback onResolve;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final r = report;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _chip(context, r.targetTypeLabel),
                const SizedBox(width: DpSpacing.xs),
                _chip(context, r.categoryLabel, tone: c.chart4),
                if (r.reportCount > 1) ...[
                  const SizedBox(width: DpSpacing.xs),
                  _chip(context, '${r.reportCount}명 신고', tone: c.danger),
                ],
                const Spacer(),
                if (r.status != 'OPEN')
                  Text(
                    r.status == 'RESOLVED' ? '처리됨' : '기각됨',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: DpSpacing.xs),
            Text(
              r.isTargetGone ? '삭제된 콘텐츠' : r.targetTitle!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: r.isTargetGone ? c.textSecondary : null,
                fontStyle: r.isTargetGone ? FontStyle.italic : null,
              ),
            ),
            if (r.targetExcerpt != null && r.targetExcerpt!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                r.targetExcerpt!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ],
            if (r.reason != null && r.reason!.isNotEmpty) ...[
              const SizedBox(height: DpSpacing.xs),
              Text(
                '신고 사유: ${r.reason}',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: DpSpacing.xs),
            Row(
              children: [
                // 조치 기능이 없는 대신 대상 위치를 노출해 수동 대응 경로를 남긴다.
                if (r.targetPath != null)
                  Text(
                    r.targetPath!,
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                const Spacer(),
                if (r.status == 'OPEN') ...[
                  TextButton(onPressed: onReject, child: const Text('기각')),
                  const SizedBox(width: DpSpacing.xs),
                  FilledButton(onPressed: onResolve, child: const Text('처리완료')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, {Color? tone}) {
    final c = context.dpColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: tone ?? c.textSecondary),
      ),
    );
  }
}
