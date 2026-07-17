import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_admin/src/features/users/application/users_controller.dart';
import 'package:devpath_admin/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Mock HTTP adapter — 요청을 캡처하고 미리 정해진 응답을 돌려준다.
// ---------------------------------------------------------------------------
class _CapturingAdapter implements HttpClientAdapter {
  final List<RequestOptions> captured = [];

  /// 기본값: 204 No Content (approve/preApprove 엔드포인트 규약)
  /// users 목록(GET /admin/users)은 빈 Page JSON 반환.
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);

    if (options.method == 'GET' && options.path.contains('/admin/users')) {
      // load() 내부의 GET /admin/users 호출 — 빈 페이지 반환
      return ResponseBody.fromString(
        jsonEncode({'data': [], 'limit': 20}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // POST /admin/users/{id}/approve  또는  POST /admin/allowlist — 204
    return ResponseBody.fromString('', 204, headers: {});
  }

  @override
  void close({bool force = false}) {}
}

// ---------------------------------------------------------------------------
// 헬퍼: apiClientProvider + adminUsersFetchProvider를 Mock으로 교체한 컨테이너
// ---------------------------------------------------------------------------
ProviderContainer _container(_CapturingAdapter adapter) {
  return ProviderContainer(
    overrides: [
      apiClientProvider.overrideWith((ref) {
        final client = ApiClient.create(
          const ApiConfig(baseUrl: 'http://test.local'),
        );
        client.dio.httpClientAdapter = adapter;
        return client;
      }),
    ],
  );
}

void main() {
  group('UsersController.approve()', () {
    test('approve("1") 는 POST /admin/users/1/approve 를 발행한다', () async {
      final adapter = _CapturingAdapter();
      final container = _container(adapter);
      addTearDown(container.dispose);

      await container.read(adminUsersProvider.notifier).approve('1');

      final posts = adapter.captured.where((r) => r.method == 'POST').toList();
      expect(posts, hasLength(1));
      expect(posts.first.path, '/admin/users/1/approve');
    });

    test('approve("1") 후 load() 가 재호출되어 GET /admin/users 가 발행된다', () async {
      final adapter = _CapturingAdapter();
      final container = _container(adapter);
      addTearDown(container.dispose);

      await container.read(adminUsersProvider.notifier).approve('1');

      final gets = adapter.captured
          .where((r) => r.method == 'GET' && r.path.contains('/admin/users'))
          .toList();
      expect(gets, hasLength(1));
    });
  });

  group('UsersController.preApprove()', () {
    test(
      'preApprove("x@y.com") 는 POST /admin/allowlist body {email: x@y.com} 를 발행한다',
      () async {
        final adapter = _CapturingAdapter();
        final container = _container(adapter);
        addTearDown(container.dispose);

        await container.read(adminUsersProvider.notifier).preApprove('x@y.com');

        final posts = adapter.captured
            .where((r) => r.method == 'POST')
            .toList();
        expect(posts, hasLength(1));
        expect(posts.first.path, '/admin/allowlist');
        expect((posts.first.data as Map<String, dynamic>)['email'], 'x@y.com');
      },
    );
  });
}
