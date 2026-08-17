import 'dart:math' as math;

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/content_state.dart';

class ContentController extends Notifier<ContentState> {
  @override
  ContentState build() => const ContentLoading();

  Future<void> load(String idOrSlug) async {
    state = const ContentLoading();
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/contents/$idOrSlug');
      state = ContentLoaded(LearningContent.fromJson(json));
    } on Object catch (error) {
      state = ContentFailed(_failureMessage(error, loading: true));
    }
  }

  Future<ContentProgressUpdateResponse?> reportProgress({
    required String idOrSlug,
    required double scrollPct,
    required int dwellSec,
  }) async {
    try {
      final json = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/contents/$idOrSlug/progress',
            body: {'scrollPct': scrollPct, 'dwellSec': dwellSec},
          );
      final response = ContentProgressUpdateResponse.fromJson(json);
      final current = state;
      if (current is ContentLoaded) {
        state = ContentLoaded(
          current.content.copyWith(
            progress: _mergeProgress(current.content.progress, response),
          ),
        );
      }
      return response;
    } on Object catch (error) {
      final current = state;
      if (current is ContentLoaded) {
        state = ContentLoaded(
          current.content,
          progressError: _failureMessage(error, loading: false),
        );
      }
      return null;
    }
  }

  String _failureMessage(Object error, {required bool loading}) =>
      switch (error) {
        ApiException(:final message) => message,
        _ => loading ? '콘텐츠 형식을 확인하지 못했어요.' : '진행률을 저장하지 못했어요.',
      };

  ContentProgress _mergeProgress(
    ContentProgress current,
    ContentProgressUpdateResponse response,
  ) => ContentProgress(
    scrollPct: math.max(current.scrollPct, response.scrollPct),
    dwellSec: math.max(current.dwellSec, response.dwellSec),
    completed: current.completed || response.completed,
    completedAt: response.completedAt ?? current.completedAt,
  );
}

final contentControllerProvider =
    NotifierProvider<ContentController, ContentState>(ContentController.new);
