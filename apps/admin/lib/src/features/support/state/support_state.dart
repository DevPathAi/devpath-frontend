import '../data/support_request.dart';

sealed class SupportListState {
  const SupportListState();
}

class SupportListLoading extends SupportListState {
  const SupportListLoading();
}

class SupportListLoaded extends SupportListState {
  const SupportListLoaded(this.rows, {this.status = 'OPEN', this.type});

  final List<SupportRequestRow> rows;

  /// 현재 필터. null 이면 전체. 재조회 시 유지한다.
  final String? status;
  final String? type;
}

class SupportListFailed extends SupportListState {
  const SupportListFailed(this.message);
  final String message;
}
