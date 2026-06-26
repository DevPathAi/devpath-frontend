import 'package:dp_core/dp_core.dart';

/// 대시보드 오프라인 캐시 추상화. 프로덕션=drift([DriftDashboardCache]),
/// 테스트=인메모리([InMemoryDashboardCache]).
abstract interface class DashboardCache {
  Future<DashboardSummary?> read();
  Future<void> write(DashboardSummary summary);
}

/// 테스트용 인메모리 캐시.
class InMemoryDashboardCache implements DashboardCache {
  DashboardSummary? _value;

  @override
  Future<DashboardSummary?> read() async => _value;

  @override
  Future<void> write(DashboardSummary summary) async => _value = summary;
}
