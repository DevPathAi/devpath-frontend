import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/updates/data/notice_feed_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.responses);
  final List<ResponseBody> responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body, {String? etag}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (etag != null) 'etag': [etag],
      },
    );

void main() {
  test('첫 200을 LKG로 저장하고 브라우저가 관리하는 ETag 304 캐시를 사용한다', () async {
    final adapter = _SequenceAdapter([
      _json(200, {
        'schemaVersion': 1,
        'banners': [
          {
            'id': 'mentor-invite',
            'title': 'AI 멘토 순차 초대 안내',
            'summary': '보통 1일 안에 초대 메일이 갑니다.',
            'startsAt': '2026-09-01T00:00:00+09:00',
            'endsAt': '2026-10-01T00:00:00+09:00',
            'cta': {
              'label': 'AI 멘토 보기',
              'href': 'https://app.leva.ai.kr/mentor',
            },
          },
        ],
      }, etag: '"feed-v1"'),
      ResponseBody.fromString('', 304),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final cache = MemoryNoticeFeedCache();
    final client = NoticeFeedClient(
      dio: dio,
      cache: cache,
      homeBaseUrl: 'https://leva.ai.kr',
    );
    final now = DateTime.parse('2026-09-05T00:00:00Z');

    final first = await client.loadActive(now);
    final second = await client.loadActive(now);

    expect(first.single.title, 'AI 멘토 순차 초대 안내');
    expect(second.single.id, 'mentor-invite');
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[1].headers, isNot(contains('if-none-match')));
    expect(cache.readPayload(), isNot(contains('rawCode')));
  });

  test('기간 밖 배너와 외부 CTA는 노출하지 않는다', () async {
    final adapter = _SequenceAdapter([
      _json(200, {
        'schemaVersion': 1,
        'banners': [
          {
            'id': 'expired',
            'title': '종료',
            'summary': '종료',
            'startsAt': '2026-08-01T00:00:00Z',
            'endsAt': '2026-08-02T00:00:00Z',
            'cta': {'label': '열기', 'href': '/mentor'},
          },
          {
            'id': 'external',
            'title': '외부',
            'summary': '외부',
            'startsAt': '2026-09-01T00:00:00Z',
            'endsAt': '2026-10-01T00:00:00Z',
            'cta': {'label': '열기', 'href': 'https://evil.test'},
          },
        ],
      }),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = NoticeFeedClient(
      dio: dio,
      cache: MemoryNoticeFeedCache(),
      homeBaseUrl: 'https://leva.ai.kr',
    );

    expect(
      await client.loadActive(DateTime.parse('2026-09-05T00:00:00Z')),
      isEmpty,
    );
  });
}
