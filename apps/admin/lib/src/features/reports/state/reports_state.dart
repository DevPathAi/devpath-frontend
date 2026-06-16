import '../data/report.dart';

sealed class ReportsState {
  const ReportsState();
}
class ReportsLoading extends ReportsState { const ReportsLoading(); }
class ReportsLoaded extends ReportsState {
  const ReportsLoaded(this.reports);
  final List<Report> reports;
}
class ReportsFailed extends ReportsState {
  const ReportsFailed(this.message);
  final String message;
}
