import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ads_controller.dart';
import '../data/ad_row.dart';
import '../data/ad_stats_row.dart';
import '../data/ads_source.dart';
import '../state/ads_state.dart';

const _kSlots = ['DASHBOARD_TOP', 'COMMUNITY_FEED', 'CONTENT_PAGE'];
const _kStatuses = ['ACTIVE', 'PAUSED'];

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
      appBar: AppBar(
        title: const Text('광고 관리'),
        actions: [
          const Text('전역 노출'),
          Switch(value: s.globalEnabled, onChanged: (v) => n.toggleGlobal(v)),
          const SizedBox(width: DpSpacing.md),
          FilledButton.icon(
            icon: const Icon(DpIcons.edit),
            label: const Text('광고 생성'),
            onPressed: () => _openForm(context, n, null),
          ),
          const SizedBox(width: DpSpacing.lg),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
            child: Row(
              children: [
                const Text('슬롯:'),
                const SizedBox(width: DpSpacing.sm),
                for (final slot in _kSlots)
                  Padding(
                    padding: const EdgeInsets.only(right: DpSpacing.xs),
                    child: ChoiceChip(
                      label: Text(slot),
                      selected: s.slotFilter == slot,
                      onSelected: (sel) => n.setSlotFilter(sel ? slot : null),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: switch (s.phase) {
        AdsPhase.loading => const DpLoading(),
        AdsPhase.failed => DpError(message: s.error ?? '오류', onRetry: n.load),
        AdsPhase.loaded when s.rows.isEmpty => DpEmpty(
          icon: DpIcons.ads,
          title: '광고가 없어요',
          actionLabel: '광고 생성',
          onAction: () => _openForm(context, n, null),
        ),
        AdsPhase.loaded => DpDataTable(
          minWidth: 760,
          columns: [
            DataColumn2(label: const Text('제목')),
            DataColumn2(label: const Text('슬롯')),
            DataColumn2(label: const Text('가중치')),
            DataColumn2(label: const Text('상태')),
            DataColumn2(label: const Text('액션'), fixedWidth: 64),
          ],
          rows: [
            for (final r in s.rows)
              DataRow2(
                cells: [
                  DataCell(Text(r.title)),
                  DataCell(Text(r.slot)),
                  DataCell(Text('${r.weight}')),
                  DataCell(
                    Switch(
                      value: r.status == 'ACTIVE',
                      onChanged: (_) => n.toggleStatus(r),
                    ),
                  ),
                  DataCell(_rowMenu(context, n, r)),
                ],
              ),
          ],
        ),
      },
    );
  }

  Future<void> _openForm(
    BuildContext context,
    AdsController n,
    AdRow? existing,
  ) async {
    final result = await showDialog<AdRow>(
      context: context,
      builder: (_) => _AdFormDialog(existing: existing),
    );
    if (result == null) return;
    if (existing?.id == null) {
      await n.create(result);
    } else {
      await n.update(existing!.id!, result);
    }
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
          onPressed: () => n.remove(r.id!),
          child: const Text('삭제'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 생성/수정 폼 다이얼로그
// ---------------------------------------------------------------------------
class _AdFormDialog extends StatefulWidget {
  const _AdFormDialog({required this.existing});
  final AdRow? existing;
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
    return AlertDialog(
      title: Text(widget.existing == null ? '광고 생성' : '광고 수정'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              TextField(
                controller: _link,
                decoration: const InputDecoration(labelText: '링크 URL'),
              ),
              TextField(
                controller: _image,
                decoration: const InputDecoration(labelText: '이미지 URL(선택)'),
              ),
              TextField(
                controller: _weight,
                decoration: const InputDecoration(labelText: '가중치(1 이상)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: DpSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _slot,
                decoration: const InputDecoration(labelText: '슬롯'),
                items: [
                  for (final s in _kSlots)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _slot = v ?? _slot),
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: '상태'),
                items: [
                  for (final s in _kStatuses)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
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
            Navigator.of(context).pop(draft);
          },
          child: const Text('저장'),
        ),
      ],
    );
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
      content: SizedBox(
        width: 480,
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
