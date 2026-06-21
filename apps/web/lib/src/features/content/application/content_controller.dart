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
    } on ApiException catch (e) {
      state = ContentFailed(e.message);
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
    } on ApiException catch (e) {
      state = ContentFailed(e.message);
      return null;
    }
  }

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
