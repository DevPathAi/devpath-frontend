import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/presentation/admin_shell.dart';
import '../../../design/admin_status_catalog.dart';
import '../../../widgets/admin_status_widgets.dart';
import '../application/reports_controller.dart';
import '../data/report.dart';
import '../state/reports_state.dart';

/// 신고 처리 화면.
///
/// 이번 범위에서 관리자는 **판정만** 한다 — 콘텐츠를 내리는 기능이 백엔드에 아직 없다.
/// 대신 대상 경로를 함께 보여줘 수동 대응 경로를 남긴다.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reportsProvider);
    final n = ref.read(reportsProvider.notifier);
    final current = s is ReportsLoaded ? s.status : 'OPEN';

    // 문서형 화면 — 헤더(필터 슬롯 포함)를 첫 sliver로 실어 본문과 함께
    // 스크롤시킨다(DESIGN.md §9). 필터는 Task 9에서 이미 헤더 슬롯으로 옮겼다.
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DpPageHeader(
              // 제목은 kAdminDestinations가 유일한 출처다(admin_shell.dart).
              title: adminHeaderTitleFor('/reports'),
              description: '커뮤니티 신고를 검토하고 판정합니다',
              filters: [
                AdminStatusFilter(
                  domain: AdminStatusDomain.report,
                  selectedWire: current,
                  onSelected: (wire) => n.load(status: wire),
                ),
              ],
            ),
          ),
          switch (s) {
            ReportsLoading() => const SliverFillRemaining(
              hasScrollBody: false,
              child: DpLoading(),
            ),
            ReportsFailed(:final message) => SliverFillRemaining(
              hasScrollBody: false,
              child: DpError(
                message: message,
                onRetry: () => n.load(status: current),
              ),
            ),
            ReportsLoaded(:final reports) when reports.isEmpty =>
              const SliverFillRemaining(
                hasScrollBody: false,
                child: DpEmpty(icon: DpIcons.empty, title: '해당하는 신고가 없어요'),
              ),
            ReportsLoaded(:final reports) => SliverPadding(
              padding: const EdgeInsets.all(DpSpacing.lg),
              sliver: SliverList.list(
                children: [
                  for (final r in reports)
                    _ReportCard(
                      report: r,
                      onResolve: () => n.resolve(r.id, 'RESOLVE'),
                      onReject: () => n.resolve(r.id, 'REJECT'),
                    ),
                ],
              ),
            ),
          },
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
            Wrap(
              spacing: DpSpacing.xs,
              runSpacing: DpSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DpTag(label: r.targetTypeLabel),
                DpTag(label: r.categoryLabel, tone: c.chart4),
                if (r.reportCount > 1)
                  DpTag(label: '${r.reportCount}명 신고', tone: c.danger),
                AdminStatusText(
                  domain: AdminStatusDomain.report,
                  wire: r.status,
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ],
            if (r.reason != null && r.reason!.isNotEmpty) ...[
              const SizedBox(height: DpSpacing.xs),
              Text(
                '신고 사유: ${r.reason}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ],
            const SizedBox(height: DpSpacing.xs),
            // 조치 기능이 없는 대신 대상 위치를 노출해 수동 대응 경로를 남긴다.
            if (r.targetPath != null)
              Text(
                r.targetPath!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                  fontFamily: DpTypography.codeFamily,
                ),
              ),
            if (r.status == 'OPEN')
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: DpSpacing.xs,
                  children: [
                    TextButton(onPressed: onReject, child: const Text('기각')),
                    FilledButton(
                      onPressed: onResolve,
                      child: const Text('처리완료'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
