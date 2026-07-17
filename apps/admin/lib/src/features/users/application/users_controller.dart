import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
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
    state = state.copyWith(statusFilter: status, nextCursor: state.nextCursor);
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
    await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/admin/users/$userId/sanction',
          body: {'action': action},
        );
  }

  /// 베타 대기(BETA_PENDING) 사용자를 승인한다 — POST /admin/users/{id}/approve (204).
  /// 승인 후 목록을 갱신해 해당 사용자가 필터에서 빠지도록 load()를 재호출한다.
  Future<void> approve(String userId) async {
    await ref
        .read(apiClientProvider)
        .post<void>('/admin/users/$userId/approve');
    await load();
  }

  /// 이메일을 허용 목록에 사전 등록한다 — POST /admin/allowlist {email} (204).
  Future<void> preApprove(String email) async {
    await ref
        .read(apiClientProvider)
        .post<void>('/admin/allowlist', body: {'email': email});
  }
}

final adminUsersProvider = NotifierProvider<UsersController, UsersState>(
  UsersController.new,
);
