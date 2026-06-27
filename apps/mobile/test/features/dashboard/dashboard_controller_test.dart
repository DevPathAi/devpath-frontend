import 'dart:async';

import 'package:devpath_mobile/src/features/dashboard/application/dashboard_controller.dart';
import 'package:devpath_mobile/src/features/dashboard/data/dashboard_cache.dart';
import 'package:devpath_mobile/src/features/dashboard/data/drift_dashboard_cache.dart';
import 'package:devpath_mobile/src/features/dashboard/state/dashboard_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/services/connectivity_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ApiClient _client(Map<String, MockFixture> fx) {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'http://test.local'));
  c.dio.httpClientAdapter = MockHttpAdapter(fx);
  return c;
}

final Map<String, MockFixture> _dashOk = {
  'GET /dashboard': (
    200,
    {
      'streakDays': 7,
      'progressPercent': 62,
      'nextTaskTitle': '비동기 기초',
      'badges': ['첫 경로', '7일 연속'],
    },
  ),
};

ProviderContainer _container({
  Map<String, MockFixture>? fixtures,
  DashboardCache? cache,
  Stream<bool>? connectivity,
}) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(_client(fixtures ?? _dashOk)),
      dashboardCacheProvider.overrideWithValue(
        cache ?? InMemoryDashboardCache(),
      ),
      connectivityProvider.overrideWith(
        (ref) => connectivity ?? const Stream<bool>.empty(),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('DashboardController', () {
    test('온라인: /dashboard 로드 + 캐시 저장', () async {
      final cache = InMemoryDashboardCache();
      final c = _container(cache: cache);
      await c.read(dashboardControllerProvider.notifier).load();

      final s = c.read(dashboardControllerProvider);
      expect(s, isA<DashLoaded>());
      expect((s as DashLoaded).summary.streakDays, 7);
      expect(s.fromCache, isFalse);
      // 캐시에 기록됨
      expect((await cache.read())!.progressPercent, 62);
    });

    test('네트워크 실패 + 캐시 있음 → 캐시 복원(fromCache=true)', () async {
      final cache = InMemoryDashboardCache();
      await cache.write(
        const DashboardSummary(
          streakDays: 3,
          progressPercent: 40,
          nextTaskTitle: '캐시 과제',
          badges: [],
        ),
      );
      final c = _container(cache: cache, fixtures: const {});
      await c.read(dashboardControllerProvider.notifier).load();

      final s = c.read(dashboardControllerProvider);
      expect(s, isA<DashLoaded>());
      expect((s as DashLoaded).fromCache, isTrue);
      expect(s.summary.streakDays, 3);
    });

    test('네트워크 실패 + 캐시 없음 → 실패', () async {
      final c = _container(cache: InMemoryDashboardCache(), fixtures: const {});
      await c.read(dashboardControllerProvider.notifier).load();
      expect(c.read(dashboardControllerProvider), isA<DashFailed>());
    });

    test('재연결(오프라인→온라인) → 자동 재동기화', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      final c = _container(connectivity: controller.stream);
      // 화면(ref.watch)처럼 provider를 활성 구독해 연결성 리스너를 유지.
      final sub = c.listen(dashboardControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();

      controller.add(false);
      await pumpEventQueue();
      controller.add(true);
      await pumpEventQueue();

      final s = c.read(dashboardControllerProvider);
      expect(s, isA<DashLoaded>());
      expect((s as DashLoaded).summary.streakDays, 7);
    });

    test('연결 변화 없으면 자동 로드 안 함(초기 DashLoading 유지)', () async {
      final c = _container();
      final sub = c.listen(dashboardControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      expect(c.read(dashboardControllerProvider), isA<DashLoading>());
    });
  });
}
