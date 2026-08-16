import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/presentation/admin_shell.dart';
import '../../../design/admin_status_catalog.dart';
import '../../../widgets/bulk_action_bar.dart';
import '../../../widgets/admin_danger_dialog.dart';
import '../../../widgets/admin_status_widgets.dart';
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
    final known = AdminStatusCatalog.isKnown(AdminStatusDomain.user, r.status);
    if (!known) {
      return const Tooltip(
        message: '알 수 없는 상태는 읽기 전용입니다',
        child: Icon(DpIcons.error),
      );
    }
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
                onPressed: () => _confirmApprove(context, n, r),
                child: const Text('승인'),
              ),
            ]
          : [
              for (final a in const ['경고', '7일 정지', '30일 정지', '영구 밴'])
                MenuItemButton(
                  onPressed: () => _confirmSanction(context, n, r, a),
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
      body: Column(
        children: [
          DpPageHeader(
            // 제목은 kAdminDestinations가 유일한 출처다(admin_shell.dart).
            title: adminHeaderTitleFor('/users'),
            description: '가입 승인과 제재를 처리합니다',
            filters: [
              AdminStatusFilter(
                domain: AdminStatusDomain.user,
                selectedWire: s.statusFilter,
                onSelected: n.setStatusFilter,
              ),
            ],
          ),
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
                    onAction: () =>
                        _confirmBulkApprove(context, n, s.selectedIds.length),
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
                onAction: () => n.setStatusFilter(null),
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
                      onSelectChanged:
                          r.status == 'BETA_PENDING' &&
                              AdminStatusCatalog.isKnown(
                                AdminStatusDomain.user,
                                r.status,
                              )
                          ? (_) => n.toggleSelect(r.id)
                          : null,
                      cells: [
                        DataCell(Text(r.nickname)),
                        DataCell(Text(r.email)),
                        DataCell(Text(r.role.name)),
                        DataCell(
                          AdminStatusText(
                            domain: AdminStatusDomain.user,
                            wire: r.status,
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

  Future<void> _confirmSanction(
    BuildContext context,
    UsersController controller,
    AdminUserRow row,
    String action,
  ) async {
    await showAdminDangerDialog(
      context: context,
      title: '$action 적용',
      impact:
          '${row.nickname} (${row.email}) 사용자에게 $action 조치를 적용합니다. '
          '계정 사용에 즉시 영향을 줄 수 있습니다.',
      confirmLabel: '조치 적용',
      onConfirm: () => controller.sanction(row.id, action),
    );
  }

  Future<void> _confirmApprove(
    BuildContext context,
    UsersController controller,
    AdminUserRow row,
  ) async {
    await showAdminDangerDialog(
      context: context,
      title: '사용자 승인',
      impact:
          '${row.nickname} (${row.email}) 사용자에게 베타 접근 권한을 부여합니다. '
          '승인 즉시 서비스를 이용할 수 있습니다.',
      confirmLabel: '승인 확정',
      onConfirm: () => controller.approve(row.id),
    );
  }

  Future<void> _confirmBulkApprove(
    BuildContext context,
    UsersController controller,
    int count,
  ) async {
    await showAdminDangerDialog(
      context: context,
      title: '선택한 사용자 $count명 승인',
      impact:
          '선택한 승인 대기 사용자 $count명에게 베타 접근 권한을 부여합니다. '
          '현재 상태를 다시 검증한 뒤 승인 가능한 사용자만 처리합니다.',
      confirmLabel: '$count명 승인',
      onConfirm: controller.bulkApprove,
    );
  }
}

// ---------------------------------------------------------------------------
// (변경 3) 사전승인 폼 위젯
// ---------------------------------------------------------------------------
class _PreApproveBar extends StatefulWidget {
  const _PreApproveBar({required this.emailCtrl, required this.onSubmit});

  final TextEditingController emailCtrl;
  final Future<void> Function(String email) onSubmit;

  @override
  State<_PreApproveBar> createState() => _PreApproveBarState();
}

class _PreApproveBarState extends State<_PreApproveBar> {
  bool _pending = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final stack =
        context.windowClass == DpWindowClass.compact ||
        MediaQuery.textScalerOf(context).scale(14) >= 20;
    final field = TextField(
      controller: widget.emailCtrl,
      enabled: !_pending,
      decoration: const InputDecoration(
        labelText: '사전승인 이메일',
        hintText: 'user@example.com',
        isDense: true,
      ),
      keyboardType: TextInputType.emailAddress,
    );
    final action = FilledButton(
      onPressed: _pending ? null : _submit,
      child: _pending
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('허용리스트 추가'),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.lg,
        vertical: DpSpacing.sm,
      ),
      child: stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                if (_error != null) ...[
                  const SizedBox(height: DpSpacing.xs),
                  _errorText(context),
                ],
                const SizedBox(height: DpSpacing.sm),
                action,
              ],
            )
          : Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: DpSpacing.sm),
                action,
                if (_error != null) ...[
                  const SizedBox(width: DpSpacing.sm),
                  Flexible(child: _errorText(context)),
                ],
              ],
            ),
    );
  }

  Widget _errorText(BuildContext context) => Semantics(
    liveRegion: true,
    label: '허용 목록 추가 실패: $_error',
    child: ExcludeSemantics(
      child: Text(
        _error!,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.dpColors.danger),
      ),
    ),
  );

  Future<void> _submit() async {
    final email = widget.emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(email);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException ? error.message : '허용 목록에 추가하지 못했어요.';
      });
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}
