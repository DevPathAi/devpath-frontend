import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/mentor/application/mentor_invite_handoff.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InviteCallbackAdapter implements HttpClientAdapter {
  String? redeemedCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/mentor-access/redeem')) {
      redeemedCode = (options.data as Map<String, dynamic>)['code'] as String;
      return _json({
        'status': 'ACTIVE',
        'source': 'INVITE_CODE',
        'waitlistedAt': '2026-09-05T00:00:00Z',
        'activatedAt': '2026-09-05T01:00:00Z',
      });
    }
    return _json({
      'access_token': 'access',
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

  ResponseBody _json(Map<String, dynamic> value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('OAuth callback은 sessionStorage 상당의 raw code를 한 번 교환하고 지운다', () async {
    final adapter = _InviteCallbackAdapter();
    final handoff = MemoryMentorInviteHandoffStore()
      ..writeCode('B' * 43)
      ..rememberReturnTo('/mentor');
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

    expect(adapter.redeemedCode, 'B' * 43);
    expect(handoff.peekCode(), isNull);
    expect(handoff.takeReturnTo(), '/mentor', reason: '라우터가 소비할 때까지 보존');
  });
}
