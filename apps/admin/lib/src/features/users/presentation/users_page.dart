import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/bulk_action_bar.dart';
import '../application/users_controller.dart';
import '../data/admin_user_row.dart';
import '../state/users_state.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});
  @override
  ConsumerState<AdminUsersPage> createState() => _S();
}

class _S extends ConsumerState<AdminUsersPage> {
  // (변경 3) 사전승인 폼용 TextEditingController
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(adminUsersProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Widget _rowMenu(BuildContext context, UsersController n, AdminUserRow r) {
    return MenuAnchor(
      builder: (context, controller, child) => IconButton(
        icon: const Icon(DpIcons.moreVert),
        tooltip: '작업',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: r.status == 'BETA_PENDING'
          ? [
              MenuItemButton(
                onPressed: () => n.approve(r.id),
                child: const Text('승인'),
              ),
            ]
          : [
              for (final a in const ['경고', '7일 정지', '30일 정지', '영구 밴'])
                MenuItemButton(
                  onPressed: () => n.sanction(r.id, a),
                  child: Text(a),
                ),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(adminUsersProvider);
    final n = ref.read(adminUsersProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 관리'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
            child: Row(
              children: [
                const Text('상태:'),
                const SizedBox(width: DpSpacing.sm),
                // (변경 1) BETA_PENDING을 첫 번째로 추가
                for (final st in [
                  'BETA_PENDING',
                  'ACTIVE',
                  'WARNED',
                  'SUSPENDED',
                  'BANNED',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: DpSpacing.xs),
                    child: ChoiceChip(
                      label: Text(st),
                      selected: s.statusFilter == st,
                      onSelected: (_) => n.setStatusFilter(st),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // (변경 3) 사전승인 폼 — 화면 상단
          _PreApproveBar(
            emailCtrl: _emailCtrl,
            onSubmit: (email) async {
              await n.preApprove(email);
              _emailCtrl.clear();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('허용 목록에 추가됐습니다.')));
              }
            },
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: s.selectedIds.isEmpty
                ? const SizedBox.shrink()
                : BulkActionBar(
                    key: const Key('users-bulk-bar'),
                    count: s.selectedIds.length,
                    actionLabel: '승인',
                    onAction: n.bulkApprove,
                    onClear: n.clearSelection,
                  ),
          ),
          // 기존 body 내용
          Expanded(
            child: switch (s.phase) {
              UsersPhase.loading => const DpLoading(),
              UsersPhase.failed => DpError(
                message: s.error ?? '오류',
                onRetry: n.load,
              ),
              UsersPhase.loaded when s.rows.isEmpty => DpEmpty(
                icon: DpIcons.community,
                title: '조건에 맞는 사용자가 없어요',
                actionLabel: '필터 초기화',
                onAction: () => n.setStatusFilter('ACTIVE'),
              ),
              UsersPhase.loaded => DpDataTable(
                minWidth: 720,
                showCheckboxColumn: true,
                onSelectAll: (v) => n.selectAll(v ?? false),
                columns: [
                  DataColumn2(label: const Text('닉네임')),
                  DataColumn2(label: const Text('이메일')),
                  DataColumn2(label: const Text('역할')),
                  DataColumn2(label: const Text('상태')),
                  DataColumn2(label: const Text('작업'), fixedWidth: 64),
                ],
                rows: [
                  for (final r in s.rows)
                    DataRow2(
                      selected: s.selectedIds.contains(r.id),
                      onSelectChanged: (_) => n.toggleSelect(r.id),
                      cells: [
                        DataCell(Text(r.nickname)),
                        DataCell(Text(r.email)),
                        DataCell(Text(r.role.name)),
                        DataCell(Text(r.status)),
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
}

// ---------------------------------------------------------------------------
// (변경 3) 사전승인 폼 위젯
// ---------------------------------------------------------------------------
class _PreApproveBar extends StatelessWidget {
  const _PreApproveBar({required this.emailCtrl, required this.onSubmit});

  final TextEditingController emailCtrl;
  final Future<void> Function(String email) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.lg,
        vertical: DpSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: '사전승인 이메일',
                hintText: 'user@example.com',
                isDense: true,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(width: DpSpacing.sm),
          FilledButton(
            onPressed: () {
              final email = emailCtrl.text.trim();
              if (email.isNotEmpty) onSubmit(email);
            },
            child: const Text('허용리스트 추가'),
          ),
        ],
      ),
    );
  }
}
