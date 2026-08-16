import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/presentation/admin_shell.dart';
import '../../../design/admin_status_catalog.dart';
import '../../../widgets/admin_status_widgets.dart';
import '../application/support_controller.dart';
import '../data/support_request.dart';
import '../state/support_state.dart';

/// 오류 신고·문의 처리 화면.
class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(supportListProvider);
    final n = ref.read(supportListProvider.notifier);
    final current = s is SupportListLoaded ? s.status : 'OPEN';

    return Scaffold(
      body: Column(
        children: [
          DpPageHeader(
            // 제목은 kAdminDestinations가 유일한 출처다(admin_shell.dart).
            title: adminHeaderTitleFor('/support'),
            description: '사용자가 보낸 오류와 문의를 처리합니다',
            filters: [
              AdminStatusFilter(
                domain: AdminStatusDomain.support,
                selectedWire: current,
                onSelected: (wire) => n.load(status: wire),
              ),
            ],
          ),
          Expanded(
            child: switch (s) {
              SupportListLoading() => const DpLoading(),
              SupportListFailed(:final message) => DpError(
                message: message,
                onRetry: () => n.load(status: current),
              ),
              SupportListLoaded(:final rows) when rows.isEmpty => const DpEmpty(
                icon: DpIcons.empty,
                title: '해당하는 제보가 없어요',
              ),
              SupportListLoaded(:final rows) => Padding(
                padding: const EdgeInsets.all(DpSpacing.lg),
                // dp_design 은 data_table_2 에서 DataColumn2·DataRow2 만 re-export 한다.
                // ColumnSize 는 export 되지 않으므로 쓰지 않는다(users_page 와 동일).
                child: DpDataTable(
                  minWidth: 1040,
                  columns: [
                    DataColumn2(label: const Text('번호'), fixedWidth: 72),
                    DataColumn2(label: const Text('유형'), fixedWidth: 72),
                    DataColumn2(label: const Text('제목')),
                    DataColumn2(label: const Text('경로')),
                    DataColumn2(label: const Text('실패'), fixedWidth: 64),
                    DataColumn2(label: const Text('상태'), fixedWidth: 220),
                    DataColumn2(label: const Text('접수 시각')),
                  ],
                  rows: [
                    for (final r in rows)
                      DataRow2(
                        onTap: () => _openDetail(context, ref, r.id),
                        cells: [
                          DataCell(Text('${r.id}')),
                          DataCell(Text(r.typeLabel)),
                          DataCell(
                            Text(r.title, overflow: TextOverflow.ellipsis),
                          ),
                          DataCell(Text(r.pagePath ?? '-')),
                          DataCell(Text('${r.failureCount}')),
                          DataCell(
                            AdminStatusText(
                              domain: AdminStatusDomain.support,
                              wire: r.status,
                            ),
                          ),
                          DataCell(Text(r.createdAt ?? '-')),
                        ],
                      ),
                  ],
                ),
              ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, WidgetRef ref, int id) async {
    final n = ref.read(supportListProvider.notifier);
    final detail = await n.detail(id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _SupportDetailDialog(detail: detail),
    );
  }
}

class _SupportDetailDialog extends ConsumerStatefulWidget {
  const _SupportDetailDialog({required this.detail});
  final SupportRequestDetail detail;

  @override
  ConsumerState<_SupportDetailDialog> createState() =>
      _SupportDetailDialogState();
}

class _SupportDetailDialogState extends ConsumerState<_SupportDetailDialog> {
  late final TextEditingController _note = TextEditingController(
    text: widget.detail.adminNote ?? '',
  );
  bool _pending = false;
  String? _error;

  /// **동사** — 상태 필터(명사)와 낱말이 겹치지 않게 한다.
  static const _transitions = <(String, String)>[
    ('처리 시작', 'IN_PROGRESS'),
    ('처리 완료', 'RESOLVED'),
    ('보류로 표시', 'WONTFIX'),
    ('다시 열기', 'OPEN'),
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final c = context.dpColors;

    return AlertDialog(
      title: Text('#${d.id} ${d.title}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminStatusText(
                domain: AdminStatusDomain.support,
                wire: d.status,
              ),
              const SizedBox(height: DpSpacing.md),
              Text(d.body),
              const SizedBox(height: DpSpacing.md),
              _kv(context, '경로', d.pagePath),
              _kv(context, '빌드', d.appVersion),
              _kv(context, '화면', d.viewport),
              _kv(context, '브라우저', d.userAgent),
              _kv(context, '오류 코드', d.errorCode),
              _kv(context, 'trace', d.traceId),
              _kv(context, '발생 시각', d.occurredAt),
              _kv(context, '접수자', d.reporterId?.toString()),
              const SizedBox(height: DpSpacing.md),
              Text('최근 API 실패', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: DpSpacing.xs),
              if (d.failures.isEmpty)
                Text(
                  '기록 없음',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                ),
              for (final f in d.failures)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text('${f.seq}'),
                  title: Text('${f.method} ${f.path}'),
                  subtitle: Text(
                    '${f.statusLabel}'
                    '${f.errorCode == null ? '' : ' · ${f.errorCode}'}'
                    '${f.message == null ? '' : '\n${f.message}'}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                  trailing: Text(
                    f.occurredAt ?? '-',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: c.textSecondary),
                  ),
                ),
              const SizedBox(height: DpSpacing.md),
              TextField(
                key: const ValueKey('support-admin-note'),
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '내부 메모 (덮어쓰기)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: DpSpacing.sm),
                Semantics(
                  liveRegion: true,
                  label: '상태 저장 실패: $_error',
                  child: ExcludeSemantics(
                    child: Text(
                      _error!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: c.danger),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _pending ? null : () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        for (final (label, status) in _transitions)
          if (status != d.status)
            FilledButton.tonal(
              onPressed: _pending ? null : () => _transition(status),
              child: Text(label),
            ),
      ],
    );
  }

  Future<void> _transition(String status) async {
    final note = _note.text.trim();
    setState(() {
      _pending = true;
      _error = null;
    });
    final error = await ref
        .read(supportListProvider.notifier)
        .updateStatus(
          widget.detail.id,
          status,
          adminNote: note.isEmpty ? null : note,
        );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _pending = false;
      _error = error;
    });
  }

  Widget _kv(BuildContext context, String k, String? v) {
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final usesCodeFont = const {'경로', '빌드', '화면', '오류 코드', 'trace'}.contains(k);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: text.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: text.bodySmall?.copyWith(
                fontFamily: usesCodeFont ? DpTypography.codeFamily : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
