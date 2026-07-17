import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_admin/src/features/auth/application/auth_controller.dart';
import 'package:devpath_admin/src/features/auth/state/auth_state.dart';
import 'package:devpath_admin/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Mock HTTP adapter — /auth/refresh 응답을 제어한다.
// ---------------------------------------------------------------------------
class _MockRefreshAdapter implements HttpClientAdapter {
  final int statusCode;

  _MockRefreshAdapter({this.statusCode = 200});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (statusCode == 200) {
      return ResponseBody.fromString(
        jsonEncode({
          'access_token': 'admin-access-token',
          'user': {
            'id': 'admin-1',
            'email': 'admin@devpath.ai',
            'nickname': '운영자',
            'role': 'ADMIN',
            'onboardingStatus': 'DONE',
            'consentStatus': 'DONE',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    } else {
      // 401 — ApiException 발생 경로
      return ResponseBody.fromString(
        jsonEncode({'message': 'Unauthorized'}),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
  }

  @override
  void close({bool force = false}) {}
}

// ---------------------------------------------------------------------------
// 헬퍼: apiClientProvider를 Mock 어댑터로 교체한 ProviderContainer 생성.
// ---------------------------------------------------------------------------
ProviderContainer _containerWithAdapter(HttpClientAdapter adapter) {
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
  group('bootstrapFromCallback()', () {
    test(
      'POST /auth/refresh 성공(role=ADMIN) 시 AdminAuthed로 전이하고 isAdmin이 true다',
      () async {
        final container = _containerWithAdapter(
          _MockRefreshAdapter(statusCode: 200),
        );
        addTearDown(container.dispose);

        await container
            .read(adminAuthProvider.notifier)
            .bootstrapFromCallback();

        final state = container.read(adminAuthProvider);
        expect(state, isA<AdminAuthed>());
        final auth = state as AdminAuthed;
        expect(auth.user.id, 'admin-1');
        expect(auth.user.nickname, '운영자');
        expect(auth.isAdmin, isTrue);
      },
    );

    test('POST /auth/refresh 성공 시 access_token이 TokenStore에 저장된다', () async {
      final container = _containerWithAdapter(
        _MockRefreshAdapter(statusCode: 200),
      );
      addTearDown(container.dispose);

      await container.read(adminAuthProvider.notifier).bootstrapFromCallback();

      final stored = await container.read(tokenStoreProvider).readAccess();
      expect(stored, 'admin-access-token');
    });

    test(
      'POST /auth/refresh 실패(401/ApiException) 시 AdminUnauthed로 전이한다',
      () async {
        final container = _containerWithAdapter(
          _MockRefreshAdapter(statusCode: 401),
        );
        addTearDown(container.dispose);

        await container
            .read(adminAuthProvider.notifier)
            .bootstrapFromCallback();

        expect(container.read(adminAuthProvider), isA<AdminUnauthed>());
      },
    );
  });
}
