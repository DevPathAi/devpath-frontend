import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ad_row.dart';
import '../data/ad_slot_config_row.dart';
import '../data/ads_source.dart';
import '../state/ads_state.dart';

class AdsController extends Notifier<AdsState> {
  @override
  AdsState build() => const AdsState();

  Future<void> load() async {
    state = AdsState(
      phase: AdsPhase.loading,
      slotFilter: state.slotFilter,
      statusFilter: state.statusFilter,
      globalEnabled: state.globalEnabled,
      slotConfigs: state.slotConfigs,
    );
    try {
      final rows = await ref.read(adsListProvider)(
        slot: state.slotFilter,
        status: state.statusFilter,
      );
      final enabled = await ref.read(adSettingsGetProvider)();
      // 슬롯 설정은 부가 기능이다. 조회 실패가 광고 목록 화면 전체를 무너뜨리지
      // 않게 여기서 흡수한다(백엔드 미배포·권한·네트워크).
      List<AdSlotConfigRow> configs = const [];
      try {
        configs = await ref.read(adSlotConfigListProvider)();
      } on ApiException {
        configs = const [];
      }
      state = AdsState(
        rows: rows,
        phase: AdsPhase.loaded,
        slotFilter: state.slotFilter,
        statusFilter: state.statusFilter,
        globalEnabled: enabled,
        slotConfigs: configs,
      );
    } on ApiException catch (e) {
      state = state.copyWith(phase: AdsPhase.failed, error: e.message);
    }
  }

  /// 슬롯 설정 1행을 저장하고 목록을 갱신한다.
  Future<void> saveSlotConfig(AdSlotConfigRow row) async {
    final saved = await ref.read(adSlotConfigSaveProvider)(row);
    state = state.copyWith(
      slotConfigs: [
        for (final c in state.slotConfigs)
          if (c.slot == saved.slot) saved else c,
      ],
    );
  }

  Future<void> setSlotFilter(String? slot) async {
    state = AdsState(
      phase: AdsPhase.loading,
      slotFilter: slot,
      statusFilter: state.statusFilter,
      globalEnabled: state.globalEnabled,
      slotConfigs: state.slotConfigs,
    );
    await load();
  }

  Future<void> setStatusFilter(String? status) async {
    state = AdsState(
      phase: AdsPhase.loading,
      slotFilter: state.slotFilter,
      statusFilter: status,
      globalEnabled: state.globalEnabled,
      slotConfigs: state.slotConfigs,
    );
    await load();
  }

  Future<void> create(AdRow draft) async {
    await ref.read(adCreateProvider)(draft);
    await load();
  }

  Future<void> update(int id, AdRow draft) async {
    await ref.read(adUpdateProvider)(id, draft);
    await load();
  }

  Future<void> remove(int id) async {
    await ref.read(adDeleteProvider)(id);
    await load();
  }

  void toggleSelect(int id) {
    final next = {...state.selectedIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(selectedIds: next);
  }

  void selectAll(bool selected) => state = state.copyWith(
    selectedIds: selected
        ? state.rows.map((r) => r.id).whereType<int>().toSet()
        : <int>{},
  );

  void clearSelection() => state = state.copyWith(selectedIds: <int>{});

  /// 선택된 광고 일괄 삭제 후 목록 재조회(새 state로 선택 초기화).
  Future<void> bulkDelete() async {
    if (state.selectedIds.isEmpty) return;
    await ref.read(adBulkDeleteProvider)(state.selectedIds.toList());
    await load();
  }

  Future<void> toggleStatus(AdRow row) async {
    final next = row.status == 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
    await ref.read(adUpdateProvider)(row.id!, row.copyWith(status: next));
    await load();
  }

  Future<void> toggleGlobal(bool enabled) async {
    final result = await ref.read(adSettingsSetProvider)(enabled);
    state = state.copyWith(globalEnabled: result);
  }

  Future<void> uploadImage(
    int id,
    List<int> bytes,
    String filename,
    String? contentType,
  ) async {
    await ref.read(adImageUploadProvider)(id, bytes, filename, contentType);
    await load();
  }
}

final adsProvider = NotifierProvider<AdsController, AdsState>(
  AdsController.new,
);
