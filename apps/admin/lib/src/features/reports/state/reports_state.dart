import '../data/report.dart';

sealed class ReportsState {
  const ReportsState({this.status = 'OPEN'});

  /// 현재 필터. null 이면 전체이며 loading/failed/retry에서도 보존한다.
  final String? status;
}

class ReportsLoading extends ReportsState {
  const ReportsLoading({super.status});
}

class ReportsLoaded extends ReportsState {
  const ReportsLoaded(this.reports, {super.status});

  final List<AdminReport> reports;
}

class ReportsFailed extends ReportsState {
  const ReportsFailed(this.message, {super.status});
  final String message;
}
