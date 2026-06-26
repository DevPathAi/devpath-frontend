import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../../services/connectivity_service.dart';
import '../data/dashboard_cache.dart';
import '../data/drift_dashboard_cache.dart';
import '../state/dashboard_state.dart';

/// 홈 대시보드 컨트롤러.
/// - 온라인: `GET /dashboard` → 캐시 저장 → DashLoaded(fromCache=false).
/// - 네트워크 실패: 캐시 읽기 → 있으면 DashLoaded(fromCache=true), 없으면 DashFailed.
/// - 재연결(오프라인→온라인): 자동 재동기화([load] 재호출).
class DashboardController extends Notifier<DashboardState> {
  ApiClient get _client => ref.read(apiClientProvider);
  DashboardCache get _cache => ref.read(dashboardCacheProvider);

  @override
  DashboardState build() {
    ref.listen(connectivityProvider, (prev, next) {
      final was = switch (prev) {
        AsyncData(:final value) => value,
        _ => null,
      };
      final now = switch (next) {
        AsyncData(:final value) => value,
        _ => null,
      };
      // 오프라인→온라인 전환에서만 재동기화.
      if (now == true && was == false) load();
    });
    return const DashLoading();
  }

  Future<void> load() async {
    state = const DashLoading();
    try {
      final json = await _client.get<Map<String, dynamic>>('/dashboard');
      final summary = DashboardSummary.fromJson(json);
      await _cache.write(summary);
      if (!ref.mounted) return;
      state = DashLoaded(summary);
    } on ApiException catch (e) {
      final cached = await _cache.read();
      if (!ref.mounted) return;
      state = cached != null
          ? DashLoaded(cached, fromCache: true)
          : DashFailed(e.message);
    }
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );
