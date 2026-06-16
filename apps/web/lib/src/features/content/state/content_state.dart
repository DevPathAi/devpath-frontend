sealed class ContentState {
  const ContentState();
}

class ContentLoading extends ContentState {
  const ContentLoading();
}

class ContentLoaded extends ContentState {
  const ContentLoaded(this.markdown);
  final String markdown;
}

class ContentFailed extends ContentState {
  const ContentFailed(this.message);
  final String message;
}
