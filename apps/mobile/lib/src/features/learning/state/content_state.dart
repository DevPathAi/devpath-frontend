import 'package:dp_core/dp_core.dart';

sealed class ContentState {
  const ContentState();
}

class ContentLoading extends ContentState {
  const ContentLoading();
}

class ContentLoaded extends ContentState {
  const ContentLoaded(this.content);
  final LearningContent content;
}

class ContentFailed extends ContentState {
  const ContentFailed(this.message);
  final String message;
}
