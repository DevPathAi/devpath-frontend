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
    this.selectedIds = const {},
  });

  final List<AdminUserRow> rows;
  final String? nextCursor;
  final String? statusFilter;
  final UsersPhase phase;
  final AdminUserRow? selected;
  final String? error;
  final Set<String> selectedIds;

  bool get hasMore => nextCursor != null;

  UsersState copyWith({
    List<AdminUserRow>? rows,
    String? nextCursor,
    String? statusFilter,
    UsersPhase? phase,
    AdminUserRow? selected,
    String? error,
    Set<String>? selectedIds,
  }) => UsersState(
    rows: rows ?? this.rows,
    nextCursor: nextCursor,
    statusFilter: statusFilter ?? this.statusFilter,
    phase: phase ?? this.phase,
    selected: selected ?? this.selected,
    error: error,
    selectedIds: selectedIds ?? this.selectedIds,
  );
}
