import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/mentor/application/mentor_invite_handoff.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InviteCallbackAdapter implements HttpClientAdapter {
  _InviteCallbackAdapter({List<int>? redeemStatuses})
    : redeemStatuses = redeemStatuses ?? [200];

  final List<int> redeemStatuses;
  String? redeemedCode;
  int refreshCalls = 0;
  var redeemed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/mentor-access/redeem')) {
      redeemedCode = (options.data as Map<String, dynamic>)['code'] as String;
      final status = redeemStatuses.removeAt(0);
      if (status != 200) {
        return _json({
          'error': {
            'code': status >= 500 ? 'INTERNAL_ERROR' : 'INVITE_CODE_INVALID',
            'message': status >= 500 ? '일시적인 오류' : '유효하지 않은 초대 코드',
          },
        }, status: status);
      }
      redeemed = true;
      return _json({
        'status': 'ACTIVE',
        'source': 'INVITE_CODE',
        'waitlistedAt': '2026-09-05T00:00:00Z',
        'activatedAt': '2026-09-05T01:00:00Z',
      });
    }
    refreshCalls++;
    return _json({
      'access_token': redeemed ? 'active-access' : 'waitlisted-access',
      'user': {
        'id': '7',
        'email': 'learner@example.com',
        'nickname': '학습자',
        'role': 'LEARNER',
        'onboardingStatus': 'DONE',
        'consentStatus': 'DONE',
      },
    });
  }

  ResponseBody _json(Map<String, dynamic> value, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('OAuth callback은 code 교환 뒤 ACTIVE access token을 다시 발급받고 지운다', () async {
    final adapter = _InviteCallbackAdapter();
    final tokenStore = InMemoryTokenStore();
    final handoff = MemoryMentorInviteHandoffStore()
      ..writeCode('B' * 43)
      ..rememberReturnTo('/mentor');
    final container = ProviderContainer(
      overrides: [
        mentorInviteHandoffStoreProvider.overrideWithValue(handoff),
        tokenStoreProvider.overrideWithValue(tokenStore),
        apiClientProvider.overrideWith((ref) {
          final client = ApiClient.create(
            const ApiConfig(baseUrl: 'https://api.leva.ai.kr'),
          );
          client.dio.httpClientAdapter = adapter;
          return client;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .bootstrapFromCallback();

    expect(adapter.redeemedCode, 'B' * 43);
    expect(adapter.refreshCalls, 2);
    expect(await tokenStore.readAccess(), 'active-access');
    expect(handoff.peekCode(), isNull);
    expect(handoff.takeReturnTo(), '/mentor', reason: '라우터가 소비할 때까지 보존');
  });

  test('일시적인 redeem 실패는 code를 보존하고 callback 재시도로 복구한다', () async {
    final adapter = _InviteCallbackAdapter(redeemStatuses: [503, 200]);
    final tokenStore = InMemoryTokenStore();
    final handoff = MemoryMentorInviteHandoffStore()..writeCode('C' * 43);
    final container = ProviderContainer(
      overrides: [
        mentorInviteHandoffStoreProvider.overrideWithValue(handoff),
        tokenStoreProvider.overrideWithValue(tokenStore),
        apiClientProvider.overrideWith((ref) {
          final client = ApiClient.create(
            const ApiConfig(baseUrl: 'https://api.leva.ai.kr'),
          );
          client.dio.httpClientAdapter = adapter;
          return client;
        }),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    await controller.bootstrapFromCallback();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    expect(handoff.peekCode(), 'C' * 43);

    await controller.bootstrapFromCallback();

    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    expect(handoff.peekCode(), isNull);
    expect(adapter.refreshCalls, 3);
    expect(await tokenStore.readAccess(), 'active-access');
  });

  test('terminal 4xx redeem 실패만 code를 폐기하고 로그인은 유지한다', () async {
    final adapter = _InviteCallbackAdapter(redeemStatuses: [400]);
    final handoff = MemoryMentorInviteHandoffStore()..writeCode('D' * 43);
    final container = ProviderContainer(
      overrides: [
        mentorInviteHandoffStoreProvider.overrideWithValue(handoff),
        apiClientProvider.overrideWith((ref) {
          final client = ApiClient.create(
            const ApiConfig(baseUrl: 'https://api.leva.ai.kr'),
          );
          client.dio.httpClientAdapter = adapter;
          return client;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .bootstrapFromCallback();

    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    expect(handoff.peekCode(), isNull);
    expect(adapter.refreshCalls, 1);
  });
}
