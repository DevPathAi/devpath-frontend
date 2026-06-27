import 'package:dp_core/dp_core.dart';

sealed class CommunityState {
  const CommunityState();
}

class CommunityLoading extends CommunityState {
  const CommunityLoading();
}

class CommunityLoaded extends CommunityState {
  const CommunityLoaded(this.posts);
  final List<CommunityPostSummary> posts;
}

class CommunityFailed extends CommunityState {
  const CommunityFailed(this.message);
  final String message;
}
