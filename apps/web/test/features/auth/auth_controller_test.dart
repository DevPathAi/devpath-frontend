import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/application/oauth_launcher.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake OAuthLauncher — 테스트에서 실제 리다이렉트 대신 URL을 기록한다.
// ---------------------------------------------------------------------------
class _FakeOAuthLauncher implements OAuthLauncher {
  String? launchedUrl;

  @override
  void launch(String url) {
    launchedUrl = url;
  }
}

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
          'access_token': 'test-access-token',
          'user': {
            'id': 'u-1',
            'email': 'test@devpath.ai',
            'nickname': '테스터',
            'role': 'LEARNER',
            'onboardingStatus': 'PENDING',
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
  // -------------------------------------------------------------------------
  // login() — OAuth 리다이렉트 테스트
  // -------------------------------------------------------------------------
  group('login()', () {
    test('주입된 Launcher로 올바른 OAuth URL을 호출한다', () async {
      final fakeLauncher = _FakeOAuthLauncher();
      final container = ProviderContainer(
        overrides: [oauthLauncherProvider.overrideWithValue(fakeLauncher)],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).login();

      expect(fakeLauncher.launchedUrl, isNotNull);
      expect(
        fakeLauncher.launchedUrl,
        endsWith('/oauth2/authorization/github'),
        reason: 'login()은 OAuth 엔드포인트로 리다이렉트해야 한다',
      );
    });

    test('login() 호출 후 AuthState는 변하지 않는다(리다이렉트이므로)', () async {
      final fakeLauncher = _FakeOAuthLauncher();
      final container = ProviderContainer(
        overrides: [oauthLauncherProvider.overrideWithValue(fakeLauncher)],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).login();

      // 리다이렉트이므로 상태는 그대로 미인증
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    });
  });

  // -------------------------------------------------------------------------
  // bootstrapFromCallback() — /auth/refresh 세션 복원 테스트
  // -------------------------------------------------------------------------
  group('bootstrapFromCallback()', () {
    test('POST /auth/refresh 성공 시 AuthAuthenticated로 전이하고 user를 담는다', () async {
      final container = _containerWithAdapter(
        _MockRefreshAdapter(statusCode: 200),
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .bootstrapFromCallback();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      final auth = state as AuthAuthenticated;
      expect(auth.user.id, 'u-1');
      expect(auth.user.nickname, '테스터');
      expect(auth.user.onboardingStatus, OnboardingStatus.pending);
    });

    test('POST /auth/refresh 성공 시 access_token이 TokenStore에 저장된다', () async {
      final container = _containerWithAdapter(
        _MockRefreshAdapter(statusCode: 200),
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .bootstrapFromCallback();

      final stored = await container.read(tokenStoreProvider).readAccess();
      expect(stored, 'test-access-token');
    });

    test('POST /auth/refresh 실패(401) 시 AuthUnauthenticated로 전이한다', () async {
      final container = _containerWithAdapter(
        _MockRefreshAdapter(statusCode: 401),
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .bootstrapFromCallback();

      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 기존 유지: 초기 상태·logout
  // -------------------------------------------------------------------------
  test('초기 상태는 미인증', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('logout은 토큰을 비우고 미인증으로 전환', () async {
    final container = _containerWithAdapter(
      _MockRefreshAdapter(statusCode: 200),
    );
    addTearDown(container.dispose);

    final ctrl = container.read(authControllerProvider.notifier);
    await ctrl.bootstrapFromCallback(); // 먼저 인증 상태로 만든다
    await ctrl.logout();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    expect(await container.read(tokenStoreProvider).readAccess(), isNull);
  });
}
