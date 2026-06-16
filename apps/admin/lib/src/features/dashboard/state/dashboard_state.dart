sealed class AdminDashState {
  const AdminDashState();
}
class AdminDashLoading extends AdminDashState { const AdminDashLoading(); }
class AdminDashLoaded extends AdminDashState {
  const AdminDashLoaded(this.stats);
  final Map<String, int> stats;
}
class AdminDashFailed extends AdminDashState {
  const AdminDashFailed(this.message);
  final String message;
}
