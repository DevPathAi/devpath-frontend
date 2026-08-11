import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../data/report.dart';
import '../state/reports_state.dart';

/// 신고 처리. 경로가 `/admin/reports` 가 아니라 **`/community/admin/reports`** 인 이유:
/// 게이트웨이의 `platform-auth` 라우트가 `/admin/**` 를 선점해 platform-svc 로 보내므로
/// community-svc 의 신고 API 에 도달하지 못한다.
class ReportsController extends Notifier<ReportsState> {
  static const _pageSize = 50;

  @override
  ReportsState build() {
    load();
    return const ReportsLoading();
  }

  Future<void> load({String? status = 'OPEN'}) async {
    state = const ReportsLoading();
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/community/admin/reports',
            query: {'status': ?status, 'page': 0, 'size': _pageSize},
          );
      final list = (json['items'] as List? ?? const [])
          .map((o) => AdminReport.fromJson((o as Map).cast<String, dynamic>()))
          .toList();
      state = ReportsLoaded(list, status: status);
    } on ApiException catch (e) {
      state = ReportsFailed(e.message);
    }
  }

  /// [action] = RESOLVE(처리완료) | REJECT(기각). 처리 후 현재 필터로 재조회한다.
  Future<void> resolve(int id, String action) async {
    final current = state;
    final keep = current is ReportsLoaded ? current.status : 'OPEN';
    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/community/admin/reports/$id/resolve',
            body: {'action': action},
          );
    } on ApiException catch (e) {
      state = ReportsFailed(e.message);
      return;
    }
    await load(status: keep);
  }
}

final reportsProvider = NotifierProvider<ReportsController, ReportsState>(
  ReportsController.new,
);
