import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/content_state.dart';

/// 모바일 학습 뷰어 — 콘텐츠 조회 + 완료 표시(진척 보고).
class ContentController extends Notifier<ContentState> {
  @override
  ContentState build() => const ContentLoading();

  Future<void> load(String slug) async {
    state = const ContentLoading();
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/contents/$slug');
      state = ContentLoaded(LearningContent.fromJson(json));
    } on ApiException catch (e) {
      state = ContentFailed(e.message);
    }
  }

  /// 완료로 표시 — 진척 보고(scrollPct=1.0) 후 로컬 상태 갱신.
  Future<void> markComplete(String slug) async {
    final current = state;
    if (current is! ContentLoaded) return;
    try {
      final json = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/contents/$slug/progress',
            body: {'scrollPct': 1.0, 'dwellSec': 60},
          );
      final resp = ContentProgressUpdateResponse.fromJson(json);
      state = ContentLoaded(
        current.content.copyWith(
          progress: ContentProgress(
            scrollPct: resp.scrollPct,
            dwellSec: resp.dwellSec,
            completed: resp.completed,
            completedAt: resp.completedAt,
          ),
        ),
      );
    } on ApiException catch (e) {
      state = ContentFailed(e.message);
    }
  }

  /// 스크롤·체류 기반 자동 진척 보고. 완료 응답이면 진척 상태를 갱신하고 응답을 반환한다.
  /// 자동 보고 실패는 학습 흐름을 막지 않도록 조용히 무시한다(null 반환, 상태 유지).
  Future<ContentProgressUpdateResponse?> reportProgress(
    String slug, {
    required double scrollPct,
    required int dwellSec,
  }) async {
    try {
      final json = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/contents/$slug/progress',
            body: {'scrollPct': scrollPct, 'dwellSec': dwellSec},
          );
      final resp = ContentProgressUpdateResponse.fromJson(json);
      if (!ref.mounted) return resp;
      final latest = state;
      if (latest is ContentLoaded) {
        state = ContentLoaded(
          latest.content.copyWith(
            progress: ContentProgress(
              scrollPct: resp.scrollPct,
              dwellSec: resp.dwellSec,
              completed: resp.completed,
              completedAt: resp.completedAt,
            ),
          ),
        );
      }
      return resp;
    } on ApiException {
      return null;
    }
  }
}

final contentControllerProvider =
    NotifierProvider<ContentController, ContentState>(ContentController.new);
