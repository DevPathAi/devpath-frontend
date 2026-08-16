import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/presentation/admin_shell.dart';
import '../../../design/admin_status_catalog.dart';
import '../../../widgets/admin_danger_dialog.dart';
import '../../../widgets/admin_status_widgets.dart';
import '../../../widgets/bulk_action_bar.dart';
import '../application/ads_controller.dart';
import '../data/ad_row.dart';
import '../data/ad_slot_config_row.dart';
import '../data/ad_stats_row.dart';
import '../data/ads_source.dart';
import '../state/ads_state.dart';

const _kSlots = ['DASHBOARD_TOP', 'COMMUNITY_FEED', 'CONTENT_PAGE'];
const _kStatuses = ['ACTIVE', 'PAUSED'];
const _kSlotLabels = {
  'DASHBOARD_TOP': '대시보드 상단',
  'COMMUNITY_FEED': '커뮤니티 피드',
  'CONTENT_PAGE': '콘텐츠 페이지',
};

String _slotDisplayLabel(String wire) =>
    '${_kSlotLabels[wire] ?? '알 수 없는 슬롯'} ($wire)';

class AdminAdsPage extends ConsumerStatefulWidget {
  const AdminAdsPage({super.key});
  @override
  ConsumerState<AdminAdsPage> createState() => _AdsPageState();
}

class _AdsPageState extends ConsumerState<AdminAdsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(adsProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(adsProvider);
    final n = ref.read(adsProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          DpPageHeader(
            // 제목은 kAdminDestinations가 유일한 출처다(admin_shell.dart).
            title: adminHeaderTitleFor('/ads'),
            description: '하우스·스폰서 광고를 운영합니다',
            actions: [
              FilledButton.icon(
                icon: const Icon(DpIcons.edit),
                label: const Text('광고 생성'),
                onPressed: () => _openForm(context, n, null),
              ),
            ],
            filters: [
              _AdSlotFilter(
                selectedWire: s.slotFilter,
                onSelected: n.setSlotFilter,
              ),
              AdminStatusFilter(
                domain: AdminStatusDomain.ad,
                selectedWire: s.statusFilter,
                onSelected: n.setStatusFilter,
              ),
            ],
          ),
          _AdsOperationsBar(
            globalEnabled: s.globalEnabled,
            onGlobalChanged: n.toggleGlobal,
            onOpenSlotConfig: () => _openSlotConfig(context, n, s.slotConfigs),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: s.selectedIds.isEmpty
                ? const SizedBox.shrink()
                : BulkActionBar(
                    key: const Key('ads-bulk-bar'),
                    count: s.selectedIds.length,
                    actionLabel: '삭제',
                    onAction: () =>
                        _confirmBulkDelete(context, n, s.selectedIds.length),
                    onClear: n.clearSelection,
                  ),
          ),
          Expanded(
            child: switch (s.phase) {
              AdsPhase.loading => const DpLoading(),
              AdsPhase.failed => DpError(
                message: s.error ?? '오류',
                onRetry: n.load,
              ),
              AdsPhase.loaded when s.rows.isEmpty => DpEmpty(
                icon: DpIcons.ads,
                title: '광고가 없어요',
                actionLabel: '광고 생성',
                onAction: () => _openForm(context, n, null),
              ),
              AdsPhase.loaded => DpDataTable(
                minWidth: 760,
                showCheckboxColumn: true,
                onSelectAll: (v) => n.selectAll(v ?? false),
                columns: [
                  DataColumn2(label: const Text('제목')),
                  DataColumn2(label: const Text('슬롯')),
                  DataColumn2(label: const Text('가중치')),
                  DataColumn2(label: const Text('상태'), fixedWidth: 260),
                  DataColumn2(label: const Text('액션'), fixedWidth: 64),
                ],
                rows: [
                  for (final r in s.rows)
                    DataRow2(
                      selected: s.selectedIds.contains(r.id),
                      onSelectChanged: (_) => n.toggleSelect(r.id!),
                      cells: [
                        DataCell(Text(r.title)),
                        DataCell(Text(r.slot)),
                        DataCell(Text('${r.weight}')),
                        DataCell(
                          _AdStatusSwitch(
                            row: r,
                            onChanged: () => n.toggleStatus(r),
                          ),
                        ),
                        DataCell(_rowMenu(context, n, r)),
                      ],
                    ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    AdsController n,
    AdRow? existing,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AdFormDialog(
        existing: existing,
        onSave: (draft) => existing?.id == null
            ? n.create(draft)
            : n.update(existing!.id!, draft),
      ),
    );
  }

  Future<void> _openSlotConfig(
    BuildContext context,
    AdsController n,
    List<AdSlotConfigRow> configs,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SlotConfigDialog(
        configs: configs,
        onSave: (rows) async {
          for (final row in rows) {
            await n.saveSlotConfig(row);
          }
        },
      ),
    );
  }

  Future<void> _openStats(BuildContext context, AdRow row) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AdStatsDialog(adId: row.id!, title: row.title),
    );
  }

  Widget _rowMenu(BuildContext context, AdsController n, AdRow r) {
    return MenuAnchor(
      builder: (context, controller, child) => IconButton(
        icon: const Icon(DpIcons.moreVert),
        tooltip: '작업',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => _openForm(context, n, r),
          child: const Text('수정'),
        ),
        MenuItemButton(
          onPressed: () => _openStats(context, r),
          child: const Text('통계'),
        ),
        MenuItemButton(
          onPressed: () => _confirmDelete(context, n, r),
          child: const Text('삭제'),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdsController controller,
    AdRow row,
  ) async {
    await showAdminDangerDialog(
      context: context,
      title: '광고 삭제',
      impact:
          '${row.title} 광고가 운영 노출에서 즉시 제거됩니다. '
          '삭제한 광고는 복구할 수 없습니다.',
      confirmLabel: '광고 삭제',
      onConfirm: () => controller.remove(row.id!),
    );
  }

  Future<void> _confirmBulkDelete(
    BuildContext context,
    AdsController controller,
    int count,
  ) async {
    await showAdminDangerDialog(
      context: context,
      title: '선택한 광고 $count개 삭제',
      impact:
          '선택한 광고 $count개가 운영 노출에서 즉시 제거됩니다. '
          '삭제한 광고는 복구할 수 없습니다.',
      confirmLabel: '$count개 삭제',
      onConfirm: controller.bulkDelete,
    );
  }
}

class _AdSlotFilter extends StatelessWidget {
  const _AdSlotFilter({required this.selectedWire, required this.onSelected});

  static const _all = '__ALL_AD_SLOTS__';

  final String? selectedWire;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = selectedWire ?? _all;
    return Semantics(
      label:
          '슬롯 필터: ${selectedWire == null ? '전체 슬롯' : _slotDisplayLabel(selectedWire!)}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: InputDecorator(
          decoration: const InputDecoration(labelText: '슬롯', isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: _all,
                  child: Text('전체 슬롯', overflow: TextOverflow.ellipsis),
                ),
                for (final slot in _kSlots)
                  DropdownMenuItem(
                    value: slot,
                    child: Text(
                      _slotDisplayLabel(slot),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                onSelected(value == _all ? null : value);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AdsOperationsBar extends StatelessWidget {
  const _AdsOperationsBar({
    required this.globalEnabled,
    required this.onGlobalChanged,
    required this.onOpenSlotConfig,
  });

  final bool globalEnabled;
  final ValueChanged<bool> onGlobalChanged;
  final VoidCallback onOpenSlotConfig;

  @override
  Widget build(BuildContext context) => Material(
    color: context.dpColors.surfaceMuted,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.lg,
        vertical: DpSpacing.sm,
      ),
      child: Wrap(
        spacing: DpSpacing.md,
        runSpacing: DpSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.end,
        children: [
          Semantics(
            label: '전역 광고 노출',
            toggled: globalEnabled,
            child: ExcludeSemantics(
              child: Wrap(
                spacing: DpSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    globalEnabled ? '전역 노출 켜짐' : '전역 노출 꺼짐',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Switch(value: globalEnabled, onChanged: onGlobalChanged),
                ],
              ),
            ),
          ),
          OutlinedButton(
            onPressed: onOpenSlotConfig,
            child: const Text('슬롯 설정'),
          ),
        ],
      ),
    ),
  );
}

class _AdStatusSwitch extends StatelessWidget {
  const _AdStatusSwitch({required this.row, required this.onChanged});

  final AdRow row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final status = AdminStatusCatalog.resolve(AdminStatusDomain.ad, row.status);
    final active = row.status == 'ACTIVE';
    return Semantics(
      label: '${row.title} 광고 상태: ${status.displayLabel}',
      toggled: active,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AdminStatusText(
                domain: AdminStatusDomain.ad,
                wire: row.status,
              ),
            ),
            const SizedBox(width: DpSpacing.xs),
            Switch(value: active, onChanged: (_) => onChanged()),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 생성/수정 폼 다이얼로그
// ---------------------------------------------------------------------------
class _AdFormDialog extends StatefulWidget {
  const _AdFormDialog({required this.existing, required this.onSave});
  final AdRow? existing;
  final Future<void> Function(AdRow draft) onSave;
  @override
  State<_AdFormDialog> createState() => _AdFormDialogState();
}

class _AdFormDialogState extends State<_AdFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _link;
  late final TextEditingController _image;
  late final TextEditingController _weight;
  late String _slot;
  late String _status;
  bool _pending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _link = TextEditingController(text: e?.linkUrl ?? '');
    _image = TextEditingController(text: e?.imageUrl ?? '');
    _weight = TextEditingController(text: '${e?.weight ?? 1}');
    _slot = e?.slot ?? _kSlots.first;
    _status = e?.status ?? 'ACTIVE';
  }

  @override
  void dispose() {
    _title.dispose();
    _link.dispose();
    _image.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slots = [..._kSlots, if (!_kSlots.contains(_slot)) _slot];
    final statuses = [
      ..._kStatuses,
      if (!_kStatuses.contains(_status)) _status,
    ];
    return PopScope(
      canPop: !_pending,
      child: AlertDialog(
        title: Text(widget.existing == null ? '광고 생성' : '광고 수정'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _title,
                  enabled: !_pending,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                TextField(
                  controller: _link,
                  enabled: !_pending,
                  decoration: const InputDecoration(labelText: '링크 URL'),
                ),
                TextField(
                  controller: _image,
                  enabled: !_pending,
                  decoration: const InputDecoration(labelText: '이미지 URL(선택)'),
                ),
                TextField(
                  controller: _weight,
                  enabled: !_pending,
                  decoration: const InputDecoration(labelText: '가중치(1 이상)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: DpSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: _slot,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '슬롯'),
                  items: [
                    for (final s in slots)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          _slotDisplayLabel(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _pending
                      ? null
                      : (v) => setState(() => _slot = v ?? _slot),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '상태'),
                  items: [
                    for (final s in statuses)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          AdminStatusCatalog.resolve(
                            AdminStatusDomain.ad,
                            s,
                          ).displayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _pending
                      ? null
                      : (v) => setState(() => _status = v ?? _status),
                ),
                if (widget.existing?.id != null)
                  Padding(
                    padding: const EdgeInsets.only(top: DpSpacing.md),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '이미지 파일 업로드는 저장 후 목록의 수정에서 지원됩니다.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: DpSpacing.md),
                  _InlineFormError(message: _error!),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _pending ? null : () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: _pending ? null : _save,
            child: _pending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final weight = int.tryParse(_weight.text.trim()) ?? 1;
    final draft = AdRow(
      id: widget.existing?.id,
      title: _title.text.trim(),
      imageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
      linkUrl: _link.text.trim(),
      slot: _slot,
      weight: weight < 1 ? 1 : weight,
      status: _status,
      startsAt: widget.existing?.startsAt,
      endsAt: widget.existing?.endsAt,
    );
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.onSave(draft);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _error = _formErrorMessage(error);
      });
    }
  }
}

// ---------------------------------------------------------------------------
// 통계 다이얼로그 (최근 7일 기본, 테이블 + 합계)
// ---------------------------------------------------------------------------
class _AdStatsDialog extends ConsumerWidget {
  const _AdStatsDialog({required this.adId, required this.title});
  final int adId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 6));
    return AlertDialog(
      title: Text('통계 · $title'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: FutureBuilder<List<AdStatsRow>>(
          future: ref.read(adStatsProvider)(adId, from, to),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return const Text('통계를 불러오지 못했어요.');
            }
            final rows = snap.data ?? const [];
            final impr = rows.fold<int>(0, (a, r) => a + r.impressions);
            final clk = rows.fold<int>(0, (a, r) => a + r.clicks);
            final ctr = impr == 0 ? 0.0 : clk * 100 / impr;
            return SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('날짜')),
                    DataColumn(label: Text('노출')),
                    DataColumn(label: Text('클릭')),
                    DataColumn(label: Text('CTR')),
                  ],
                  rows: [
                    for (final r in rows)
                      DataRow(
                        cells: [
                          DataCell(Text('${r.date.month}/${r.date.day}')),
                          DataCell(Text('${r.impressions}')),
                          DataCell(Text('${r.clicks}')),
                          DataCell(
                            Text(
                              r.impressions == 0
                                  ? '-'
                                  : '${(r.clicks * 100 / r.impressions).toStringAsFixed(1)}%',
                            ),
                          ),
                        ],
                      ),
                    DataRow(
                      cells: [
                        const DataCell(Text('합계')),
                        DataCell(Text('$impr')),
                        DataCell(Text('$clk')),
                        DataCell(Text('${ctr.toStringAsFixed(1)}%')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 슬롯 설정 다이얼로그 — 슬롯별 광고 소스와 애드센스 단위 ID
// ---------------------------------------------------------------------------
const _kSourceLabels = {'HOUSE': '하우스 광고', 'ADSENSE': '애드센스', 'OFF': '끄기'};

class _SlotConfigDialog extends StatefulWidget {
  const _SlotConfigDialog({required this.configs, required this.onSave});
  final List<AdSlotConfigRow> configs;
  final Future<void> Function(List<AdSlotConfigRow> rows) onSave;
  @override
  State<_SlotConfigDialog> createState() => _SlotConfigDialogState();
}

class _SlotConfigDialogState extends State<_SlotConfigDialog> {
  late List<AdSlotConfigRow> _rows;
  late final Map<String, TextEditingController> _unitIds;
  bool _pending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rows = [...widget.configs];
    _unitIds = {
      for (final r in _rows)
        r.slot: TextEditingController(text: r.adsenseSlotId ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _unitIds.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_pending,
      child: AlertDialog(
        title: const Text('슬롯 설정'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _rows.length; i++) _row(context, i),
                if (_error != null) _InlineFormError(message: _error!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _pending ? null : () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: _pending ? null : _save,
            child: _pending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final saved = [
      for (final r in _rows)
        r.copyWith(
          adsenseSlotId: _unitIds[r.slot]!.text.trim().isEmpty
              ? null
              : _unitIds[r.slot]!.text.trim(),
        ),
    ];
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.onSave(saved);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _error = _formErrorMessage(error);
      });
    }
  }

  Widget _row(BuildContext context, int i) {
    final row = _rows[i];
    final isAdsense = row.source == 'ADSENSE';
    final unitIdEmpty = _unitIds[row.slot]!.text.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: DpSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _slotDisplayLabel(row.slot),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: DpSpacing.xs),
          DropdownButtonFormField<String>(
            initialValue: row.source,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '소스'),
            items: [
              for (final e in _kSourceLabels.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: _pending
                ? null
                : (v) => setState(() {
                    _rows[i] = row.copyWith(source: v ?? row.source);
                  }),
          ),
          if (isAdsense) ...[
            const SizedBox(height: DpSpacing.xs),
            TextField(
              controller: _unitIds[row.slot],
              enabled: !_pending,
              decoration: const InputDecoration(labelText: '애드센스 단위 ID'),
              onChanged: (_) => setState(() {}),
            ),
            if (unitIdEmpty)
              Padding(
                padding: const EdgeInsets.only(top: DpSpacing.xs),
                child: Text(
                  '단위 ID가 없으면 이 슬롯은 노출되지 않습니다',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.dpColors.warning,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

String _formErrorMessage(Object error) => error is ApiException
    ? error.message
    : '저장하지 못했어요. 입력 내용을 확인하고 다시 시도해 주세요.';

class _InlineFormError extends StatelessWidget {
  const _InlineFormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: '저장 실패: $message',
    child: ExcludeSemantics(
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.dpColors.danger),
      ),
    ),
  );
}
