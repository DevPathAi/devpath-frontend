import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reports_source.dart';
import '../state/reports_state.dart';

/// 신고 처리. 경로가 `/admin/reports` 가 아니라 **`/community/admin/reports`** 인 이유:
/// 게이트웨이의 `platform-auth` 라우트가 `/admin/**` 를 선점해 platform-svc 로 보내므로
/// community-svc 의 신고 API 에 도달하지 못한다.
class ReportsController extends Notifier<ReportsState> {
  static const _pageSize = 50;
  int _loadRequest = 0;

  @override
  ReportsState build() {
    load();
    return const ReportsLoading();
  }

  Future<void> load({String? status = 'OPEN'}) async {
    final request = ++_loadRequest;
    state = ReportsLoading(status: status);
    try {
      final list = await ref.read(reportsListFetchProvider)(
        status: status,
        page: 0,
        size: _pageSize,
      );
      if (request != _loadRequest) return;
      state = ReportsLoaded(list, status: status);
    } on ApiException catch (e) {
      if (request != _loadRequest) return;
      state = ReportsFailed(e.message, status: status);
    } on Object {
      if (request != _loadRequest) return;
      state = ReportsFailed('신고를 불러오지 못했어요.', status: status);
    }
  }

  /// [action] = RESOLVE(처리완료) | REJECT(기각). 처리 후 현재 필터로 재조회한다.
  Future<String?> resolve(int id, String action) async {
    final current = state;
    final canDecide =
        current is ReportsLoaded &&
        current.reports.any(
          (report) => report.id == id && report.status == 'OPEN',
        );
    if (!canDecide || !const {'RESOLVE', 'REJECT'}.contains(action)) {
      return '현재 상태에서는 신고를 판정할 수 없어요.';
    }
    try {
      await ref.read(reportDecisionProvider)(id, action);
    } on ApiException catch (e) {
      return e.message;
    } on Object {
      return '신고 판정을 저장하지 못했어요.';
    }
    await load(status: state.status);
    return null;
  }
}

final reportsProvider = NotifierProvider<ReportsController, ReportsState>(
  ReportsController.new,
);
