import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/users_controller.dart';
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
              UsersPhase.loaded => Row(
                children: [
                  // 테이블
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('닉네임')),
                          DataColumn(label: Text('이메일')),
                          DataColumn(label: Text('역할')),
                          DataColumn(label: Text('상태')),
                        ],
                        rows: [
                          for (final r in s.rows)
                            DataRow(
                              selected: s.selected?.id == r.id,
                              onSelectChanged: (_) => n.select(r),
                              cells: [
                                DataCell(Text(r.nickname)),
                                DataCell(Text(r.email)),
                                DataCell(Text(r.role.name)),
                                DataCell(Text(r.status)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  // 상세·제재 패널 (변경 2: onApprove 콜백 추가)
                  Expanded(
                    flex: 2,
                    child: _SanctionPanel(
                      selected: s.selected,
                      onSanction: n.sanction,
                      onApprove: (id) => n.approve(id),
                    ),
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

// ---------------------------------------------------------------------------
// 상세·제재 패널 (변경 2: BETA_PENDING이면 승인 버튼, 아니면 기존 제재 버튼)
// ---------------------------------------------------------------------------
class _SanctionPanel extends StatelessWidget {
  const _SanctionPanel({
    required this.selected,
    required this.onSanction,
    required this.onApprove,
  });

  final dynamic selected; // AdminUserRow?
  final Future<void> Function(String userId, String action) onSanction;
  final Future<void> Function(String userId) onApprove;

  @override
  Widget build(BuildContext context) {
    if (selected == null) {
      return const Center(child: Text('행을 선택하면 상세가 표시됩니다.'));
    }
    final r = selected;
    return Padding(
      padding: const EdgeInsets.all(DpSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.nickname, style: Theme.of(context).textTheme.titleMedium),
          Text(r.email, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: DpSpacing.lg),
          // (변경 2) BETA_PENDING → 승인 버튼, 그 외 → 기존 제재 버튼
          if (r.status == 'BETA_PENDING') ...[
            Text('베타 승인', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: DpSpacing.sm),
            FilledButton(
              onPressed: () => onApprove(r.id),
              child: const Text('승인'),
            ),
          ] else ...[
            Text('제재', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: DpSpacing.sm),
            Wrap(
              spacing: DpSpacing.sm,
              children: [
                for (final a in const ['경고', '7일 정지', '30일 정지', '영구 밴'])
                  OutlinedButton(
                    onPressed: () => onSanction(r.id, a),
                    child: Text(a),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
