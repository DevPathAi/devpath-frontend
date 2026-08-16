import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_user_row.dart';
import '../data/users_source.dart';
import '../state/users_state.dart';

class UsersController extends Notifier<UsersState> {
  @override
  UsersState build() => const UsersState();

  Future<void> load() async {
    state = UsersState(
      phase: UsersPhase.loading,
      statusFilter: state.statusFilter,
    );
    try {
      final page = await ref.read(adminUsersFetchProvider)(
        status: state.statusFilter,
      );
      state = UsersState(
        rows: page.data,
        nextCursor: page.nextCursor,
        statusFilter: state.statusFilter,
        phase: UsersPhase.loaded,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        phase: UsersPhase.failed,
        nextCursor: state.nextCursor,
        error: e.message,
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
    if (!state.hasMore) return;
    final page = await ref.read(adminUsersFetchProvider)(
      cursor: state.nextCursor,
      status: state.statusFilter,
    );
    state = state.copyWith(
      rows: [...state.rows, ...page.data],
      nextCursor: page.nextCursor,
    );
  }

  void select(AdminUserRow row) =>
      state = state.copyWith(selected: row, nextCursor: state.nextCursor);

  /// 제재(경고/7일/30일/밴) — 목 호출.
  Future<void> sanction(String userId, String action) async {
    await ref.read(adminUserSanctionProvider)(userId, action);
  }

  /// 베타 대기(BETA_PENDING) 사용자를 승인한다 — POST /admin/users/{id}/approve (204).
  /// 승인 후 목록을 갱신해 해당 사용자가 필터에서 빠지도록 load()를 재호출한다.
  Future<void> approve(String userId) async {
    await ref.read(adminUsersApproveProvider)(userId);
    await load();
  }

  /// 이메일을 허용 목록에 사전 등록한다 — POST /admin/allowlist {email} (204).
  Future<void> preApprove(String email) async {
    await ref.read(adminUserPreApproveProvider)(email);
  }

  void toggleSelect(String id) {
    final next = {...state.selectedIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(selectedIds: next, nextCursor: state.nextCursor);
  }

  void selectAll(bool selected) => state = state.copyWith(
    selectedIds: selected ? state.rows.map((r) => r.id).toSet() : <String>{},
    nextCursor: state.nextCursor,
  );

  void clearSelection() => state = state.copyWith(
    selectedIds: <String>{},
    nextCursor: state.nextCursor,
  );

  /// 선택된 사용자 일괄 승인 후 목록 재조회(새 state로 선택 초기화).
  Future<void> bulkApprove() async {
    if (state.selectedIds.isEmpty) return;
    await ref.read(adminUsersBulkApproveProvider)(
      state.selectedIds.map(int.parse).toList(),
    );
    await load();
  }
}

final adminUsersProvider = NotifierProvider<UsersController, UsersState>(
  UsersController.new,
);
