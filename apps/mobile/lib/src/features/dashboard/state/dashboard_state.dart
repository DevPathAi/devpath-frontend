import 'package:dp_core/dp_core.dart';

sealed class DashboardState {
  const DashboardState();
}

class DashLoading extends DashboardState {
  const DashLoading();
}

class DashLoaded extends DashboardState {
  const DashLoaded(this.summary, {this.fromCache = false});

  final DashboardSummary summary;

  /// 네트워크 실패로 오프라인 캐시에서 복원했는지 여부(오프라인 배너 표시).
  final bool fromCache;
}

class DashFailed extends DashboardState {
  const DashFailed(this.message);

  final String message;
}
