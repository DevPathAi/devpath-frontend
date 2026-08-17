import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _CapturingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    final body = options.path.endsWith('/commit')
        ? <String, Object?>{
            'snapshotId': 71,
            'status': 'committed',
            'immutable': true,
          }
        : <String, Object?>{
            'draftId': 'mentor_draft_1',
            'expiresAt': '2026-08-16T12:10:00Z',
            'content': {
              'current_content': {
                'contentId': 3,
                'title': '예외 처리',
                'track': 'BACKEND_SPRING',
              },
              'current_code': 'throw StateError();',
            },
            'fieldsAvailable': ['current_content', 'current_code'],
            'fieldsUnavailable': [
              {'field': 'recent_output', 'reason': 'request_context_missing'},
            ],
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      options.path.endsWith('/commit') ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container(_CapturingAdapter adapter) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'))
    ..dio.httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(client)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('Mentor draft는 purpose와 선택 필드/요청 맥락만 정확히 보낸다', () async {
    final adapter = _CapturingAdapter();
    final container = _container(adapter);

    final draft = await container.read(mentorLcsDraftProvider)(
      contentId: 3,
      requestedFields: const [
        'current_content',
        'current_code',
        'recent_output',
      ],
      requestContext: const {
        'current_code': 'throw StateError();',
        'recent_output': {
          'stdout': '',
          'stderr': 'StateError',
          'truncated': false,
        },
      },
    );

    expect(draft.draftId, 'mentor_draft_1');
    expect(draft.fieldsAvailable, ['current_content', 'current_code']);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/lcs/snapshots/draft');
    expect(adapter.requests.single.data, {
      'purpose': 'mentor_prompt',
      'contentId': 3,
      'requestedFields': ['current_content', 'current_code', 'recent_output'],
      'requestContext': {
        'current_code': 'throw StateError();',
        'recent_output': {
          'stdout': '',
          'stderr': 'StateError',
          'truncated': false,
        },
      },
    });
  });

  test('Mentor draft의 optional contentId는 null일 때 body에서 생략한다', () async {
    final adapter = _CapturingAdapter();
    final container = _container(adapter);

    await container.read(mentorLcsDraftProvider)(
      requestedFields: const ['current_content'],
      requestContext: const {},
    );

    expect(adapter.requests.single.data, {
      'purpose': 'mentor_prompt',
      'requestedFields': ['current_content'],
      'requestContext': <String, Object?>{},
    });
  });

  test('Mentor draft는 non-positive contentId를 network 전에 거절한다', () async {
    final adapter = _CapturingAdapter();
    final container = _container(adapter);

    await expectLater(
      container.read(mentorLcsDraftProvider)(
        contentId: 0,
        requestedFields: const ['current_content'],
        requestContext: const {},
      ),
      throwsArgumentError,
    );
    expect(adapter.requests, isEmpty);
  });

  test('Mentor commit은 빈 객체만 보내고 positive JS-safe snapshot ID를 반환한다', () async {
    final adapter = _CapturingAdapter();
    final container = _container(adapter);

    final id = await container.read(mentorLcsCommitProvider)(
      draftId: 'mentor_draft_1',
    );

    expect(id, 71);
    expect(adapter.requests.single.method, 'POST');
    expect(
      adapter.requests.single.path,
      '/lcs/snapshots/mentor_draft_1/commit',
    );
    expect(adapter.requests.single.data, <String, Object?>{});
  });

  for (final invalid in <Object?>[
    null,
    0,
    -1,
    1.5,
    71.0,
    '71',
    9007199254740992,
  ]) {
    test('Mentor commit은 invalid snapshotId $invalid 를 거절한다', () async {
      final adapter = _InvalidSnapshotAdapter(invalid);
      final container = _container(adapter);

      await expectLater(
        container.read(mentorLcsCommitProvider)(draftId: 'mentor_draft_1'),
        throwsFormatException,
      );
    });
  }

  test('기존 Community draft/commit body는 그대로 유지된다', () async {
    final adapter = _CapturingAdapter();
    final container = _container(adapter);

    await container.read(lcsDraftProvider)(
      requestedFields: const ['current_content'],
      contentId: 3,
    );
    await container.read(lcsCommitProvider)(
      draftId: 'mentor_draft_1',
      attachedToId: 9,
      visibility: 'answerers_only',
    );

    expect(adapter.requests[0].data, {
      'purpose': 'question_attachment',
      'contentId': 3,
      'requestedFields': ['current_content'],
    });
    expect(adapter.requests[1].data, {
      'attachedToType': 'question',
      'attachedToId': 9,
      'visibility': 'answerers_only',
    });
  });
}

final class _InvalidSnapshotAdapter extends _CapturingAdapter {
  _InvalidSnapshotAdapter(this.value);

  final Object? value;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'snapshotId': value}),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
