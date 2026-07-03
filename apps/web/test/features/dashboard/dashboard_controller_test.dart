import 'package:devpath_web/src/features/dashboard/application/dashboard_controller.dart';
import 'package:devpath_web/src/features/dashboard/state/dashboard_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 경로 캡처 fake — load()가 실서버 대시보드 경로 `GET /dashboard/me`를 호출하는지 검증한다.
/// 백엔드 `DashboardController @RequestMapping("/dashboard")+@GetMapping("/me")` 계약 정합(조각 2).
class _CapturingApiClient implements ApiClient {
  String? capturedPath;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    capturedPath = path;
    return <String, dynamic>{
          'streakDays': 5,
          'progressPercent': 50,
          'nextTaskTitle': '다음 과제',
          'badges': <String>['배지'],
        }
        as T;
  }

  @override
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Stream<SseEvent> sse(String path, {Object? body}) =>
      throw UnimplementedError();

  @override
  Dio get dio => throw UnimplementedError();
}

void main() {
  test('load()는 실서버 대시보드 경로 GET /dashboard/me를 호출한다', () async {
    final fake = _CapturingApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(dashboardControllerProvider.notifier).load();

    expect(fake.capturedPath, '/dashboard/me');
    expect(container.read(dashboardControllerProvider), isA<DashLoaded>());
  });
}
