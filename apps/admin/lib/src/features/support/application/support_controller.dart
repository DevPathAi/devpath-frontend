import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/support_request.dart';
import '../data/support_source.dart';
import '../state/support_state.dart';

/// 제보 처리.
///
/// 경로가 `/admin/support-requests` 인 것이 ③(신고)과 다르다 — ④는 소유가 platform-svc 라
/// 게이트웨이의 `/admin/**` 선점이 오히려 유리하게 작용해 우회 경로가 필요 없다.
class SupportListController extends Notifier<SupportListState> {
  static const _pageSize = 50;

  @override
  SupportListState build() {
    load();
    return const SupportListLoading();
  }

  Future<void> load({String? status = 'OPEN', String? type}) async {
    state = const SupportListLoading();
    try {
      final rows = await ref.read(supportListFetchProvider)(
        status: status,
        type: type,
        limit: _pageSize,
      );
      state = SupportListLoaded(rows, status: status, type: type);
    } on ApiException catch (e) {
      state = SupportListFailed(e.message);
    }
  }

  Future<SupportRequestDetail> detail(int id) async {
    return ref.read(supportDetailFetchProvider)(id);
  }

  /// 상태 전이 후 현재 필터로 재조회한다.
  /// 실패 문자열을 반환하며, 기존 목록·필터는 그대로 보존한다.
  Future<String?> updateStatus(
    int id,
    String status, {
    String? adminNote,
  }) async {
    final current = state;
    final keepStatus = current is SupportListLoaded ? current.status : 'OPEN';
    final keepType = current is SupportListLoaded ? current.type : null;
    try {
      await ref.read(supportStatusUpdateProvider)(
        id,
        status,
        adminNote: adminNote,
      );
    } on ApiException catch (e) {
      return e.message;
    } on Object {
      return '상태를 저장하지 못했어요.';
    }
    await load(status: keepStatus, type: keepType);
    return null;
  }
}

final supportListProvider =
    NotifierProvider<SupportListController, SupportListState>(
      SupportListController.new,
    );
