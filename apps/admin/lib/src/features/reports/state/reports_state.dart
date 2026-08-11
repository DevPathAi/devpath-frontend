import '../data/report.dart';

sealed class ReportsState {
  const ReportsState();
}

class ReportsLoading extends ReportsState {
  const ReportsLoading();
}

class ReportsLoaded extends ReportsState {
  const ReportsLoaded(this.reports, {this.status = 'OPEN'});

  final List<AdminReport> reports;

  /// 현재 필터. null 이면 전체. 재조회 시 이 값을 유지한다.
  final String? status;
}

class ReportsFailed extends ReportsState {
  const ReportsFailed(this.message);
  final String message;
}
