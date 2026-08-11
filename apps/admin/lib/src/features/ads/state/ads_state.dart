import '../data/ad_row.dart';
import '../data/ad_slot_config_row.dart';

enum AdsPhase { loading, loaded, failed }

class AdsState {
  const AdsState({
    this.rows = const [],
    this.phase = AdsPhase.loading,
    this.slotFilter,
    this.statusFilter,
    this.globalEnabled = false,
    this.error,
    this.selectedIds = const {},
    this.slotConfigs = const [],
  });

  final List<AdRow> rows;
  final AdsPhase phase;
  final String? slotFilter;
  final String? statusFilter;
  final bool globalEnabled;
  final String? error;
  final Set<int> selectedIds;
  final List<AdSlotConfigRow> slotConfigs;

  AdsState copyWith({
    List<AdRow>? rows,
    AdsPhase? phase,
    String? slotFilter,
    String? statusFilter,
    bool? globalEnabled,
    String? error,
    Set<int>? selectedIds,
    List<AdSlotConfigRow>? slotConfigs,
  }) => AdsState(
    rows: rows ?? this.rows,
    phase: phase ?? this.phase,
    slotFilter: slotFilter ?? this.slotFilter,
    statusFilter: statusFilter ?? this.statusFilter,
    globalEnabled: globalEnabled ?? this.globalEnabled,
    error: error,
    selectedIds: selectedIds ?? this.selectedIds,
    slotConfigs: slotConfigs ?? this.slotConfigs,
  );
}
