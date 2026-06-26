import 'package:devpath_mobile/src/features/dashboard/data/dashboard_cache.dart';
import 'package:devpath_mobile/src/features/dashboard/data/drift_dashboard_cache.dart';
import 'package:devpath_mobile/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/providers/theme_provider.dart';
import 'package:devpath_mobile/src/services/connectivity_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
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

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(theme: DpTheme.light(), home: const DashboardPage()),
);

ProviderContainer _container({
  Map<String, MockFixture>? fixtures,
  DashboardCache? cache,
}) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(_client(fixtures ?? _dashOk)),
      dashboardCacheProvider.overrideWithValue(
        cache ?? InMemoryDashboardCache(),
      ),
      connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('로드 성공 → 스트릭·진척·다음 과제 표시', (tester) async {
    await tester.pumpWidget(_host(_container()));
    await tester.pumpAndSettle();

    expect(find.text('7일'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('비동기 기초'), findsOneWidget);
    expect(find.byType(DpOfflineBanner), findsNothing);
  });

  testWidgets('네트워크 실패 + 캐시 → 오프라인 배너 + 캐시 데이터', (tester) async {
    final cache = InMemoryDashboardCache();
    await cache.write(
      const DashboardSummary(
        streakDays: 3,
        progressPercent: 40,
        nextTaskTitle: '캐시 과제',
        badges: [],
      ),
    );
    await tester.pumpWidget(
      _host(_container(fixtures: const {}, cache: cache)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DpOfflineBanner), findsOneWidget);
    expect(find.text('3일'), findsOneWidget);
    expect(find.text('캐시 과제'), findsOneWidget);
  });

  testWidgets('테마 토글 버튼 → 다크모드 전환', (tester) async {
    final c = _container();
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(c.read(themeModeProvider), ThemeMode.system);
    await tester.tap(find.byTooltip('테마 전환'));
    await tester.pump();
    expect(c.read(themeModeProvider), ThemeMode.dark);
  });
}
