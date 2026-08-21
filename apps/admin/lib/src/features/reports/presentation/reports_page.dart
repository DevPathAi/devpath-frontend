import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/presentation/admin_shell.dart';
import '../../../design/admin_status_catalog.dart';
import '../../../widgets/admin_danger_dialog.dart';
import '../../../widgets/admin_status_widgets.dart';
import '../application/reports_controller.dart';
import '../data/report.dart';
import '../data/reports_source.dart';
import '../data/revision.dart';
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
    final current = s.status;

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
                      onResolve: () =>
                          _confirmDecision(context, n, r, 'RESOLVE'),
                      onReject: () => _confirmDecision(context, n, r, 'REJECT'),
                      onTakedown: () => _confirmTakedown(context, ref, r),
                      onRevisions: () => _showRevisions(context, ref, r),
                    ),
                ],
              ),
            ),
          },
        ],
      ),
    );
  }

  Future<void> _confirmDecision(
    BuildContext context,
    ReportsController controller,
    AdminReport report,
    String action,
  ) async {
    final rejecting = action == 'REJECT';
    await showAdminDangerDialog(
      context: context,
      title: rejecting ? '신고 기각' : '신고 처리 완료',
      impact:
          '신고 #${report.id} 판정은 즉시 반영되며 현재 목록에서 사라질 수 있습니다. '
          '${rejecting ? '기각' : '처리 완료'} 여부를 다시 확인해 주세요.',
      confirmLabel: rejecting ? '기각 확정' : '처리 완료 확정',
      confirmationValue: '신고 #${report.id}',
      onConfirm: () => controller.resolve(report.id, action),
    );
  }

  /// 콘텐츠 내리기. 되돌릴 수 없고 평판까지 회수하므로 판정과 같은 무게의 확인을 거친다.
  Future<void> _confirmTakedown(
    BuildContext context,
    WidgetRef ref,
    AdminReport report,
  ) async {
    final ok = await showAdminDangerDialog(
      context: context,
      title: '${report.targetTypeLabel} 내리기',
      impact:
          '내리면 이용자에게 보이지 않고, 그 콘텐츠로 얻은 평판을 회수합니다. '
          '작성자 삭제와 달리 규정 위반 판단이며 되돌리는 API 는 아직 없습니다.',
      confirmLabel: '내리기 확정',
      confirmationValue: '${report.targetTypeLabel} #${report.targetId}',
      onConfirm: () =>
          ref.read(contentTakedownProvider)(report.targetType, report.targetId),
    );
    if (ok != true || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('내렸어요')));
  }

  /// 수정 이력. 「답변을 받고 질문을 통째로 바꿨는가」를 확인하는 근거다.
  Future<void> _showRevisions(
    BuildContext context,
    WidgetRef ref,
    AdminReport report,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    List<AdminRevision> list;
    try {
      list = await ref.read(revisionsFetchProvider)(
        report.targetType,
        report.targetId,
      );
    } on ApiException {
      messenger.showSnackBar(const SnackBar(content: Text('이력을 불러오지 못했어요')));
      return;
    }
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('수정 이력'),
        content: SizedBox(
          width: 480,
          child: list.isEmpty
              ? const Text('수정된 적이 없어요')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final v in list)
                      ListTile(
                        title: Text(v.title ?? '(제목 없음)'),
                        subtitle: Text(v.bodyMd ?? ''),
                        trailing: Text(v.createdAt ?? ''),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
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
    required this.onTakedown,
    required this.onRevisions,
  });

  final AdminReport report;
  final VoidCallback onResolve;
  final VoidCallback onReject;

  /// 콘텐츠를 HIDDEN 으로 내린다(평판 회수 포함).
  final VoidCallback onTakedown;

  /// 수정 이력 조회.
  final VoidCallback onRevisions;

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
            // 대상 위치를 노출해 수동 확인 경로도 남긴다(내리기는 아래 버튼).
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
                    TextButton(
                      key: ValueKey('revisions-${r.id}'),
                      onPressed: onRevisions,
                      child: const Text('수정 이력'),
                    ),
                    // 알 수 없는 대상 종류면 내릴 경로가 없다 — 눌러 봐야 실패하는 버튼을
                    // 보여 주는 대신 감춘다(경로 결정은 canTakedown 한 곳에서만 한다).
                    if (!r.isTargetGone && canTakedown(r.targetType))
                      TextButton(
                        key: ValueKey('takedown-${r.id}'),
                        onPressed: onTakedown,
                        child: const Text('내리기'),
                      ),
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
