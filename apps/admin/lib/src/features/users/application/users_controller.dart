import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/admin_status_catalog.dart';
import '../data/admin_user_row.dart';
import '../data/users_source.dart';
import '../state/users_state.dart';

class UsersController extends Notifier<UsersState> {
  int _loadRequest = 0;

  @override
  UsersState build() => const UsersState();

  Future<void> load() async {
    final request = ++_loadRequest;
    final previous = state;
    state = UsersState(
      phase: UsersPhase.loading,
      rows: previous.rows,
      nextCursor: previous.nextCursor,
      statusFilter: previous.statusFilter,
      selected: previous.selected,
      selectedIds: previous.selectedIds,
    );
    try {
      final page = await ref.read(adminUsersFetchProvider)(
        status: previous.statusFilter,
      );
      if (request != _loadRequest) return;
      state = UsersState(
        rows: page.data,
        nextCursor: page.nextCursor,
        statusFilter: previous.statusFilter,
        phase: UsersPhase.loaded,
        selected: previous.selected,
        selectedIds: {
          for (final row in page.data)
            if (previous.selectedIds.contains(row.id) && _canBulkApprove(row))
              row.id,
        },
      );
    } on ApiException catch (e) {
      if (request != _loadRequest) return;
      state = previous.copyWith(
        phase: UsersPhase.failed,
        nextCursor: previous.nextCursor,
        error: e.message,
      );
    } on Object {
      if (request != _loadRequest) return;
      state = previous.copyWith(
        phase: UsersPhase.failed,
        nextCursor: previous.nextCursor,
        error: '사용자 목록을 불러오지 못했어요.',
      );
    }
  }

  Future<void> setStatusFilter(String? status) async {
    state = UsersState(
      rows: state.rows,
      nextCursor: state.nextCursor,
      statusFilter: status,
      phase: state.phase,
      selected: state.selected,
      error: state.error,
      selectedIds: state.selectedIds,
    );
    await load();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.phase != UsersPhase.loaded) return;
    final request = ++_loadRequest;
    final page = await ref.read(adminUsersFetchProvider)(
      cursor: state.nextCursor,
      status: state.statusFilter,
    );
    if (request != _loadRequest) return;
    state = state.copyWith(
      rows: [...state.rows, ...page.data],
      nextCursor: page.nextCursor,
    );
  }

  void select(AdminUserRow row) =>
      state = state.copyWith(selected: row, nextCursor: state.nextCursor);

  /// 제재(경고/7일/30일/밴) — 목 호출.
  Future<String?> sanction(String userId, String action) async {
    final row = _row(userId);
    if (row == null || !_isKnown(row) || row.status == 'BETA_PENDING') {
      return '현재 상태에서는 제재할 수 없어요.';
    }
    try {
      await ref.read(adminUserSanctionProvider)(userId, action);
      return null;
    } on Object catch (error) {
      return _mutationError(error, '제재를 저장하지 못했어요.');
    }
  }

  /// 베타 대기(BETA_PENDING) 사용자를 승인한다 — POST /admin/users/{id}/approve (204).
  /// 승인 후 목록을 갱신해 해당 사용자가 필터에서 빠지도록 load()를 재호출한다.
  Future<String?> approve(String userId) async {
    final row = _row(userId);
    if (row == null || !_canBulkApprove(row)) {
      return '승인 대기 중인 사용자만 승인할 수 있어요.';
    }
    try {
      await ref.read(adminUsersApproveProvider)(userId);
      await load();
      return null;
    } on Object catch (error) {
      return _mutationError(error, '승인을 저장하지 못했어요.');
    }
  }

  /// 이메일을 허용 목록에 사전 등록한다 — POST /admin/allowlist {email} (204).
  Future<void> preApprove(String email) async {
    await ref.read(adminUserPreApproveProvider)(email);
  }

  void toggleSelect(String id) {
    final row = _row(id);
    if (row == null || !_canBulkApprove(row)) return;
    final next = {...state.selectedIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(selectedIds: next, nextCursor: state.nextCursor);
  }

  void selectAll(bool selected) => state = state.copyWith(
    selectedIds: selected
        ? state.rows.where(_canBulkApprove).map((r) => r.id).toSet()
        : <String>{},
    nextCursor: state.nextCursor,
  );

  void clearSelection() => state = state.copyWith(
    selectedIds: <String>{},
    nextCursor: state.nextCursor,
  );

  /// 선택된 사용자 일괄 승인 후 목록 재조회(새 state로 선택 초기화).
  Future<String?> bulkApprove() async {
    if (state.selectedIds.isEmpty) return null;
    final eligible = state.rows
        .where(
          (row) => state.selectedIds.contains(row.id) && _canBulkApprove(row),
        )
        .map((row) => int.tryParse(row.id))
        .whereType<int>()
        .toList();
    if (eligible.isEmpty) {
      return '승인 가능한 숫자 사용자 ID가 없어요.';
    }
    try {
      await ref.read(adminUsersBulkApproveProvider)(eligible);
      clearSelection();
      await load();
      return null;
    } on Object catch (error) {
      return _mutationError(error, '일괄 승인을 저장하지 못했어요.');
    }
  }

  AdminUserRow? _row(String id) {
    for (final row in state.rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  static bool _isKnown(AdminUserRow row) =>
      AdminStatusCatalog.isKnown(AdminStatusDomain.user, row.status);

  static bool _canBulkApprove(AdminUserRow row) =>
      _isKnown(row) && row.status == 'BETA_PENDING';

  static String _mutationError(Object error, String fallback) =>
      error is ApiException ? error.message : fallback;
}

final adminUsersProvider = NotifierProvider<UsersController, UsersState>(
  UsersController.new,
);
