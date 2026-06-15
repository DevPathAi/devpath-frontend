import 'package:dp_core/dp_core.dart';

sealed class DashboardState {
  const DashboardState();
}

class DashLoading extends DashboardState {
  const DashLoading();
}

class DashLoaded extends DashboardState {
  const DashLoaded(this.summary);
  final DashboardSummary summary;
}

class DashFailed extends DashboardState {
  const DashFailed(this.message);
  final String message;
}
