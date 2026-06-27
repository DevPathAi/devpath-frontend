import 'package:dp_core/dp_core.dart';

sealed class LearnState {
  const LearnState();
}

class LearnLoading extends LearnState {
  const LearnLoading();
}

class LearnLoaded extends LearnState {
  const LearnLoaded(this.path);
  final LearningPath path;
}

class LearnFailed extends LearnState {
  const LearnFailed(this.message);
  final String message;
}
