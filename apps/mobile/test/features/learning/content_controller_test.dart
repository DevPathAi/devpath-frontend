import 'package:devpath_mobile/src/features/learning/application/content_controller.dart';
import 'package:devpath_mobile/src/features/learning/state/content_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

Map<String, dynamic> _content({required bool completed}) => {
  'id': 1,
  'slug': 'future-async-await',
  'title': 'Future/async-await 정리',
  'track': 'BACKEND',
  'markdown': '# 비동기 기초\n본문',
  'estimatedMinutes': 8,
  'conceptTags': <String>[],
  'progress': {
    'scrollPct': 0.2,
    'dwellSec': 12,
    'completed': completed,
    'completedAt': null,
  },
};

final Map<String, MockFixture> _fx = {
  'GET /contents/future-async-await': (200, _content(completed: false)),
  'POST /contents/future-async-await/progress': (
    200,
    {
      'scrollPct': 1.0,
      'dwellSec': 60,
      'completed': true,
      'completedAt': '2026-06-27T10:00:00Z',
    },
  ),
};

ProviderContainer _container(Map<String, MockFixture> fx) {
  final c = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(mockApiClient(fx))],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ContentController', () {
    test('load 성공 → ContentLoaded(마크다운)', () async {
      final c = _container(_fx);
      await c
          .read(contentControllerProvider.notifier)
          .load('future-async-await');
      final s = c.read(contentControllerProvider);
      expect(s, isA<ContentLoaded>());
      expect((s as ContentLoaded).content.title, 'Future/async-await 정리');
      expect(s.content.progress.completed, isFalse);
    });

    test('markComplete → 진척 completed=true 반영', () async {
      final c = _container(_fx);
      final n = c.read(contentControllerProvider.notifier);
      await n.load('future-async-await');
      await n.markComplete('future-async-await');
      final s = c.read(contentControllerProvider);
      expect(s, isA<ContentLoaded>());
      expect((s as ContentLoaded).content.progress.completed, isTrue);
    });

    test('load 실패 → ContentFailed', () async {
      final c = _container(const {});
      await c.read(contentControllerProvider.notifier).load('missing');
      expect(c.read(contentControllerProvider), isA<ContentFailed>());
    });

    test('reportProgress → 응답 반환 + 진척(completed) 상태 반영', () async {
      final c = _container(_fx);
      final n = c.read(contentControllerProvider.notifier);
      await n.load('future-async-await');

      final resp = await n.reportProgress(
        'future-async-await',
        scrollPct: 0.85,
        dwellSec: 50,
      );

      expect(resp, isNotNull);
      expect(resp!.completed, isTrue);
      final s = c.read(contentControllerProvider);
      expect((s as ContentLoaded).content.progress.completed, isTrue);
    });

    test(
      'reportProgress 실패 → null 반환, 상태는 ContentLoaded 유지(흐름 방해 없음)',
      () async {
        final c = _container({
          'GET /contents/future-async-await': (200, _content(completed: false)),
        });
        final n = c.read(contentControllerProvider.notifier);
        await n.load('future-async-await');

        final resp = await n.reportProgress(
          'future-async-await',
          scrollPct: 0.5,
          dwellSec: 30,
        );

        expect(resp, isNull);
        expect(c.read(contentControllerProvider), isA<ContentLoaded>());
      },
    );
  });
}
