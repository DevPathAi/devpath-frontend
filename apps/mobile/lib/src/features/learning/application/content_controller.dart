import 'dart:async';
import 'dart:math' as math;

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../today/application/today_controller.dart';
import '../state/content_state.dart';

/// 모바일 학습 뷰어 — 콘텐츠 조회 + 완료 표시(진척 보고).
class ContentController extends Notifier<ContentState> {
  var _loadGeneration = 0;

  @override
  ContentState build() => const ContentLoading();

  Future<void> load(String slug) async {
    final generation = ++_loadGeneration;
    state = const ContentLoading();
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/contents/$slug');
      final content = LearningContent.fromJson(json);
      if (!_matches(content, slug)) {
        throw const FormatException('content identity mismatch');
      }
      if (!ref.mounted || generation != _loadGeneration) return;
      state = ContentLoaded(content);
    } on Object catch (error) {
      if (!ref.mounted || generation != _loadGeneration) return;
      state = ContentFailed(_loadFailure(error));
    }
  }

  /// 완료로 표시 — 진척 보고(scrollPct=1.0) 후 로컬 상태 갱신.
  Future<void> markComplete(String slug) async {
    final current = state;
    if (current is! ContentLoaded || !_matches(current.content, slug)) return;
    try {
      final json = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/contents/$slug/progress',
            body: {'scrollPct': 1.0, 'dwellSec': 60},
          );
      final resp = ContentProgressUpdateResponse.fromJson(json);
      if (!ref.mounted || state is! ContentLoaded) return;
      _applyProgress(slug, resp);
    } on Object catch (error) {
      if (!ref.mounted) return;
      final latest = state;
      if (latest is ContentLoaded && _matches(latest.content, slug)) {
        state = ContentLoaded(
          latest.content,
          progressFailureMessage: _progressFailure(error),
        );
      }
    }
  }

  /// 스크롤·체류 기반 자동 진척 보고. 완료 응답이면 진척 상태를 갱신하고 응답을 반환한다.
  /// 자동 보고 실패는 학습 흐름을 막지 않도록 조용히 무시한다(null 반환, 상태 유지).
  Future<ContentProgressUpdateResponse?> reportProgress(
    String slug, {
    required double scrollPct,
    required int dwellSec,
  }) async {
    final before = state;
    if (before is! ContentLoaded || !_matches(before.content, slug)) {
      return null;
    }
    try {
      final json = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/contents/$slug/progress',
            body: {'scrollPct': scrollPct, 'dwellSec': dwellSec},
          );
      final resp = ContentProgressUpdateResponse.fromJson(json);
      if (!ref.mounted) return resp;
      _applyProgress(slug, resp);
      return resp;
    } on Object catch (error) {
      if (ref.mounted) {
        final latest = state;
        if (latest is ContentLoaded && _matches(latest.content, slug)) {
          state = ContentLoaded(
            latest.content,
            progressFailureMessage: _progressFailure(error),
          );
        }
      }
      return null;
    }
  }

  void _applyProgress(String slug, ContentProgressUpdateResponse response) {
    final latest = state;
    if (latest is! ContentLoaded || !_matches(latest.content, slug)) return;
    final previous = latest.content.progress;
    final completedNow = !previous.completed && response.completed;
    state = ContentLoaded(
      latest.content.copyWith(
        progress: ContentProgress(
          scrollPct: math.max(previous.scrollPct, response.scrollPct),
          dwellSec: math.max(previous.dwellSec, response.dwellSec),
          completed: previous.completed || response.completed,
          completedAt: response.completedAt ?? previous.completedAt,
        ),
      ),
    );
    if (completedNow && ref.exists(todayControllerProvider)) {
      unawaited(
        ref.read(todayControllerProvider.notifier).invalidateAndRefetch(),
      );
    }
  }

  bool _matches(LearningContent content, String routeKey) =>
      content.slug == routeKey || content.id.toString() == routeKey;

  String _loadFailure(Object error) => switch (error) {
    ApiException(:final message) => message,
    FormatException() => '미션과 콘텐츠 연결을 확인하지 못했어요.',
    _ => '콘텐츠 형식을 확인하지 못했어요.',
  };

  String _progressFailure(Object error) => switch (error) {
    ApiException(:final message) => message,
    _ => '진행률을 저장하지 못했어요.',
  };
}

final contentControllerProvider =
    NotifierProvider<ContentController, ContentState>(ContentController.new);
