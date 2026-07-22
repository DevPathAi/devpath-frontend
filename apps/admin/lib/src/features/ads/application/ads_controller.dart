import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ad_row.dart';
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
    );
    try {
      final rows = await ref.read(adsListProvider)(
        slot: state.slotFilter,
        status: state.statusFilter,
      );
      final enabled = await ref.read(adSettingsGetProvider)();
      state = AdsState(
        rows: rows,
        phase: AdsPhase.loaded,
        slotFilter: state.slotFilter,
        statusFilter: state.statusFilter,
        globalEnabled: enabled,
      );
    } on ApiException catch (e) {
      state = state.copyWith(phase: AdsPhase.failed, error: e.message);
    }
  }

  Future<void> setSlotFilter(String? slot) async {
    state = AdsState(
      phase: AdsPhase.loading,
      slotFilter: slot,
      statusFilter: state.statusFilter,
      globalEnabled: state.globalEnabled,
    );
    await load();
  }

  Future<void> setStatusFilter(String? status) async {
    state = AdsState(
      phase: AdsPhase.loading,
      slotFilter: state.slotFilter,
      statusFilter: status,
      globalEnabled: state.globalEnabled,
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
