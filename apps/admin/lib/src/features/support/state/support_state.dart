import '../data/support_request.dart';

sealed class SupportListState {
  const SupportListState({this.status = 'OPEN', this.type});

  final String? status;
  final String? type;
}

class SupportListLoading extends SupportListState {
  const SupportListLoading({super.status, super.type});
}

class SupportListLoaded extends SupportListState {
  const SupportListLoaded(this.rows, {super.status, super.type});

  final List<SupportRequestRow> rows;
}

class SupportListFailed extends SupportListState {
  const SupportListFailed(this.message, {super.status, super.type});
  final String message;
}
