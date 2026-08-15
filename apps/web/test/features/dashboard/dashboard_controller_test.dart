import 'dart:async';

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
  Future<T> put<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => throw UnimplementedError();

  @override
  Stream<SseEvent> sse(String path, {Object? body}) =>
      throw UnimplementedError();

  @override
  Future<T> postMultipart<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
    String? contentType,
  }) => throw UnimplementedError();

  @override
  Dio get dio => throw UnimplementedError();
}

class _QueuedApiClient implements ApiClient {
  _QueuedApiClient(this.responses);

  final List<Future<Map<String, dynamic>>> responses;
  var calls = 0;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) {
    if (path != '/dashboard/me') throw StateError('unexpected GET $path');
    final response = responses[calls];
    calls += 1;
    return response as Future<T>;
  }

  @override
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> put<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => throw UnimplementedError();

  @override
  Stream<SseEvent> sse(String path, {Object? body}) =>
      throw UnimplementedError();

  @override
  Future<T> postMultipart<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
    String? contentType,
  }) => throw UnimplementedError();

  @override
  Dio get dio => throw UnimplementedError();
}

Map<String, dynamic> _summary(String owner, int streakDays) => {
  'streakDays': streakDays,
  'progressPercent': streakDays,
  'nextTaskTitle': '$owner next task',
  'badges': <String>[owner],
  'completedContentCount': streakDays,
};

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

  test('owner A 요청 중 B로 전환하면 B를 자동 조회하고 늦은 A 응답을 버린다', () async {
    final ownerA = Completer<Map<String, dynamic>>();
    final ownerB = Completer<Map<String, dynamic>>();
    final fake = _QueuedApiClient([ownerA.future, ownerB.future]);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(dashboardControllerProvider.notifier);
    notifier.synchronizeOwner('user-a');
    notifier.load();
    expect(fake.calls, 1, reason: '같은 owner의 동시 load는 한 요청을 공유해야 한다');

    notifier.synchronizeOwner('user-b');
    expect(container.read(dashboardControllerProvider), isA<DashLoading>());
    expect(fake.calls, 2, reason: '새 owner 지표는 화면이 살아 있어도 자동 조회해야 한다');

    ownerB.complete(_summary('user-b', 19));
    await ownerB.future;
    await Future<void>.delayed(Duration.zero);
    final afterB = container.read(dashboardControllerProvider) as DashLoaded;
    expect(afterB.summary.streakDays, 19);
    expect(afterB.summary.nextTaskTitle, 'user-b next task');

    ownerA.complete(_summary('user-a', 3));
    await ownerA.future;
    await Future<void>.delayed(Duration.zero);
    final afterLateA =
        container.read(dashboardControllerProvider) as DashLoaded;
    expect(afterLateA.summary.streakDays, 19);
    expect(afterLateA.summary.nextTaskTitle, 'user-b next task');
  });

  test('malformed/non-Api 응답은 원문을 숨긴 DashFailed로 종료한다', () async {
    const rawFailure = 'raw-sensitive-dashboard-payload';
    final fake = _QueuedApiClient([
      Future.value({
        'streakDays': rawFailure,
        'progressPercent': 20,
        'nextTaskTitle': 'task',
        'badges': <String>[],
      }),
    ]);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(dashboardControllerProvider.notifier).load();

    final failed = container.read(dashboardControllerProvider) as DashFailed;
    expect(failed.message, '학습 지표 형식을 확인하지 못했어요.');
    expect(failed.message, isNot(contains(rawFailure)));
  });
}
