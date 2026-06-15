import 'package:dp_core/dp_core.dart';

sealed class QnaDetailState {
  const QnaDetailState();
}

class QnaLoading extends QnaDetailState {
  const QnaLoading();
}

class QnaLoaded extends QnaDetailState {
  const QnaLoaded(this.post);
  final CommunityPost post;
}

class QnaFailed extends QnaDetailState {
  const QnaFailed(this.message);
  final String message;
}
