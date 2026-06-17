import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/onboarding/application/onboarding_controller.dart';
import 'package:devpath_web/src/features/onboarding/state/onboarding_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 최소 Mock 어댑터: /auth/refresh(PENDING) + /onboarding(DONE) 응답 제공.
class _MockOnboardingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    if (key == 'POST /auth/refresh') {
      return ResponseBody.fromString(
        jsonEncode({
          'access_token': 'mock-access',
          'user': {
            'id': 'u-mock',
            'email': 'learner@devpath.ai',
            'nickname': '지수',
            'role': 'LEARNER',
            'onboardingStatus': 'PENDING',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (key == 'POST /onboarding') {
      return ResponseBody.fromString(
        jsonEncode({
          'user': {
            'id': 'u-mock',
            'email': 'learner@devpath.ai',
            'nickname': '지수',
            'role': 'LEARNER',
            'onboardingStatus': 'DONE',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'error': 'no mock: $key'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('진단 제출 → 온보딩 완료 + auth 유저가 DONE으로 갱신', () async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWith((ref) {
          final client = ApiClient.create(
            const ApiConfig(baseUrl: 'http://test.local'),
          );
          client.dio.httpClientAdapter = _MockOnboardingAdapter();
          return client;
        }),
      ],
    );
    addTearDown(container.dispose);

    // 선행: bootstrapFromCallback()으로 인증(PENDING) — 새 OAuth 흐름 기준.
    await container
        .read(authControllerProvider.notifier)
        .bootstrapFromCallback();
    expect(
      (container.read(authControllerProvider) as AuthAuthenticated)
          .user
          .onboardingStatus,
      OnboardingStatus.pending,
    );

    await container
        .read(onboardingControllerProvider.notifier)
        .submit(githubHandle: 'jisoo-dev');

    expect(container.read(onboardingControllerProvider), isA<OnboardingDone>());
    final user =
        (container.read(authControllerProvider) as AuthAuthenticated).user;
    expect(user.onboardingStatus, OnboardingStatus.done);
  });
}
