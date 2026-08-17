import 'package:dp_core/dp_core.dart';

sealed class ContentState {
  const ContentState();
}

class ContentLoading extends ContentState {
  const ContentLoading();
}

class ContentLoaded extends ContentState {
  const ContentLoaded(this.content, {this.progressError});
  final LearningContent content;
  final String? progressError;
}

class ContentFailed extends ContentState {
  const ContentFailed(this.message);
  final String message;
}
