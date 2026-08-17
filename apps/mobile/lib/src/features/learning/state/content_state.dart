import 'package:dp_core/dp_core.dart';

sealed class ContentState {
  const ContentState();
}

class ContentLoading extends ContentState {
  const ContentLoading();
}

class ContentLoaded extends ContentState {
  const ContentLoaded(
    this.content, {
    this.progressFailureMessage,
    this.loadFailureMessage,
    this.isRefreshing = false,
    this.isStale = false,
    this.fromOfflineCache = false,
    this.cachedAt,
  });
  final LearningContent content;
  final String? progressFailureMessage;
  final String? loadFailureMessage;
  final bool isRefreshing;
  final bool isStale;
  final bool fromOfflineCache;
  final DateTime? cachedAt;

  ContentLoaded copyWith({
    LearningContent? content,
    String? progressFailureMessage,
    String? loadFailureMessage,
    bool? isRefreshing,
    bool? isStale,
    bool? fromOfflineCache,
    DateTime? cachedAt,
  }) => ContentLoaded(
    content ?? this.content,
    progressFailureMessage: progressFailureMessage,
    loadFailureMessage: loadFailureMessage,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isStale: isStale ?? this.isStale,
    fromOfflineCache: fromOfflineCache ?? this.fromOfflineCache,
    cachedAt: cachedAt ?? this.cachedAt,
  );
}

class ContentFailed extends ContentState {
  const ContentFailed(this.message);
  final String message;
}
