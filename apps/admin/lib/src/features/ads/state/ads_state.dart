import '../data/ad_row.dart';

enum AdsPhase { loading, loaded, failed }

class AdsState {
  const AdsState({
    this.rows = const [],
    this.phase = AdsPhase.loading,
    this.slotFilter,
    this.statusFilter,
    this.globalEnabled = false,
    this.error,
  });

  final List<AdRow> rows;
  final AdsPhase phase;
  final String? slotFilter;
  final String? statusFilter;
  final bool globalEnabled;
  final String? error;

  AdsState copyWith({
    List<AdRow>? rows,
    AdsPhase? phase,
    String? slotFilter,
    String? statusFilter,
    bool? globalEnabled,
    String? error,
  }) => AdsState(
    rows: rows ?? this.rows,
    phase: phase ?? this.phase,
    slotFilter: slotFilter ?? this.slotFilter,
    statusFilter: statusFilter ?? this.statusFilter,
    globalEnabled: globalEnabled ?? this.globalEnabled,
    error: error,
  );
}
