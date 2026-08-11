import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/support/application/support_controller.dart';
import 'package:devpath_web/src/features/support/data/support_draft.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 요청 본문을 붙잡아 두는 어댑터.
class _CapturingAdapter implements HttpClientAdapter {
  Object? lastBody;
  String? lastPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastBody = options.data;
    return ResponseBody.fromString(
      jsonEncode({'id': 42}),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('접수 요청이 계약대로 조립된다 — 실패 목록·컨텍스트 포함', () async {
    final adapter = _CapturingAdapter();
    final log = ApiFailureLog();
    log.add(
      ApiFailureEntry(
        method: 'POST',
        path: '/learning-paths',
        statusCode: 500,
        errorCode: 'INTERNAL_ERROR',
        message: '일시적 오류',
        occurredAt: DateTime.utc(2026, 8, 3, 10, 11, 9),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://api.test',
            useMock: false,
            appVersion: '0.1.0+42',
          ),
        ),
        apiFailureLogProvider.overrideWithValue(log),
      ],
    );
    addTearDown(container.dispose);

    container.read(apiClientProvider).dio.httpClientAdapter = adapter;

    final id = await container
        .read(supportControllerProvider.notifier)
        .submit(
          const SupportDraft(type: 'ERROR', title: '제목', body: '본문'),
          SupportContext(
            pagePath: '/path',
            appVersion: '0.1.0+42',
            userAgent: 'UA',
            viewport: '1920x1080',
            errorCode: 'PATH_GENERATION_FAILED',
            occurredAt: DateTime.utc(2026, 8, 3, 10, 11, 12),
            failures: log.recent,
          ),
        );

    expect(id, 42);
    expect(adapter.lastPath, '/support/requests');

    final body = adapter.lastBody as Map<String, dynamic>;
    expect(body['type'], 'ERROR');
    expect(body['title'], '제목');
    final ctx = body['context'] as Map<String, dynamic>;
    expect(ctx['pagePath'], '/path');
    expect(ctx['appVersion'], '0.1.0+42');
    expect(ctx['occurredAt'], '2026-08-03T10:11:12.000Z');
    final failures = ctx['failures'] as List;
    expect(failures, hasLength(1));
    expect((failures.first as Map)['errorCode'], 'INTERNAL_ERROR');
  });

  test('pagePath 는 쿼리스트링을 뺀 채 나간다', () {
    final ctx = SupportContext(
      pagePath: '/path?token=abc',
      appVersion: 'dev',
      userAgent: 'UA',
      viewport: '800x600',
      occurredAt: DateTime.utc(2026, 8, 3),
      failures: const [],
    );
    expect(ctx.toJson()['pagePath'], '/path');
  });
}
