import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/admin_status_catalog.dart';
import '../data/ad_row.dart';
import '../data/ad_slot_config_row.dart';
import '../data/ads_source.dart';
import '../state/ads_state.dart';

class AdsController extends Notifier<AdsState> {
  @override
  AdsState build() => const AdsState();

  Future<void> load() async {
    final previous = state;
    state = AdsState(
      phase: AdsPhase.loading,
      rows: previous.rows,
      slotFilter: previous.slotFilter,
      statusFilter: previous.statusFilter,
      globalEnabled: previous.globalEnabled,
      selectedIds: previous.selectedIds,
      slotConfigs: previous.slotConfigs,
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
        slotFilter: previous.slotFilter,
        statusFilter: previous.statusFilter,
        globalEnabled: enabled,
        slotConfigs: configs,
        selectedIds: {
          for (final row in rows)
            if (row.id case final id?)
              if (previous.selectedIds.contains(id) && _isKnown(row)) id,
        },
      );
    } on ApiException catch (e) {
      state = previous.copyWith(phase: AdsPhase.failed, error: e.message);
    } on Object {
      state = previous.copyWith(
        phase: AdsPhase.failed,
        error: '광고 목록을 불러오지 못했어요.',
      );
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

  Future<String?> create(AdRow draft) async {
    if (!_isKnown(draft)) return '알 수 없는 상태의 광고는 저장할 수 없어요.';
    try {
      await ref.read(adCreateProvider)(draft);
      await load();
      return null;
    } on Object catch (error) {
      return _mutationError(error, '광고를 저장하지 못했어요.');
    }
  }

  Future<String?> update(int id, AdRow draft) async {
    final current = _row(id);
    if (current == null || !_isKnown(current) || !_isKnown(draft)) {
      return '알 수 없는 상태의 광고는 변경할 수 없어요.';
    }
    try {
      await ref.read(adUpdateProvider)(id, draft);
      await load();
      return null;
    } on Object catch (error) {
      return _mutationError(error, '광고를 저장하지 못했어요.');
    }
  }

  Future<String?> remove(int id) async {
    final current = _row(id);
    if (current == null || !_isKnown(current)) {
      return '알 수 없는 상태의 광고는 삭제할 수 없어요.';
    }
    try {
      await ref.read(adDeleteProvider)(id);
      await load();
      return null;
    } on Object catch (error) {
      return _mutationError(error, '광고를 삭제하지 못했어요.');
    }
  }

  void toggleSelect(int id) {
    final row = _row(id);
    if (row == null || !_isKnown(row)) return;
    final next = {...state.selectedIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(selectedIds: next);
  }

  void selectAll(bool selected) => state = state.copyWith(
    selectedIds: selected
        ? state.rows.where(_isKnown).map((r) => r.id).whereType<int>().toSet()
        : <int>{},
  );

  void clearSelection() => state = state.copyWith(selectedIds: <int>{});

  /// 선택된 광고 일괄 삭제 후 목록 재조회(새 state로 선택 초기화).
  Future<String?> bulkDelete() async {
    if (state.selectedIds.isEmpty) return null;
    final eligible = state.rows
        .where((row) => _isKnown(row) && state.selectedIds.contains(row.id))
        .map((row) => row.id)
        .whereType<int>()
        .toList();
    if (eligible.isEmpty) return '삭제할 수 있는 광고가 없어요.';
    try {
      await ref.read(adBulkDeleteProvider)(eligible);
      clearSelection();
      await load();
      return null;
    } on Object catch (error) {
      return _mutationError(error, '광고를 삭제하지 못했어요.');
    }
  }

  Future<String?> toggleStatus(AdRow row) async {
    final current = row.id == null ? null : _row(row.id!);
    if (current == null || !_isKnown(current)) {
      return '알 수 없는 상태의 광고는 변경할 수 없어요.';
    }
    final next = current.status == 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
    try {
      await ref.read(adUpdateProvider)(
        current.id!,
        current.copyWith(status: next),
      );
      await load();
      return null;
    } on Object catch (error) {
      return _mutationError(error, '광고 상태를 저장하지 못했어요.');
    }
  }

  Future<String?> toggleGlobal(bool enabled) async {
    try {
      final result = await ref.read(adSettingsSetProvider)(enabled);
      state = state.copyWith(globalEnabled: result);
      return null;
    } on Object catch (error) {
      return _mutationError(error, '전역 광고 설정을 저장하지 못했어요.');
    }
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

  AdRow? _row(int id) {
    for (final row in state.rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  static bool _isKnown(AdRow row) =>
      AdminStatusCatalog.isKnown(AdminStatusDomain.ad, row.status);

  static String _mutationError(Object error, String fallback) =>
      error is ApiException ? error.message : fallback;
}

final adsProvider = NotifierProvider<AdsController, AdsState>(
  AdsController.new,
);
