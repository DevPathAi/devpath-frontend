import '../data/admin_user_row.dart';

enum UsersPhase { loading, loaded, failed }

class UsersState {
  const UsersState({
    this.rows = const [],
    this.nextCursor,
    this.statusFilter,
    this.phase = UsersPhase.loading,
    this.selected,
    this.error,
  });

  final List<AdminUserRow> rows;
  final String? nextCursor;
  final String? statusFilter;
  final UsersPhase phase;
  final AdminUserRow? selected;
  final String? error;

  bool get hasMore => nextCursor != null;

  UsersState copyWith({
    List<AdminUserRow>? rows,
    String? nextCursor,
    String? statusFilter,
    UsersPhase? phase,
    AdminUserRow? selected,
    String? error,
  }) => UsersState(
    rows: rows ?? this.rows,
    nextCursor: nextCursor,
    statusFilter: statusFilter ?? this.statusFilter,
    phase: phase ?? this.phase,
    selected: selected ?? this.selected,
    error: error,
  );
}
