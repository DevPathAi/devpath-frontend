import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/updates/data/notice_feed_cache.dart';
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

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => throw DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
  );

  @override
  void close({bool force = false}) {}
}

class _ThrowingCache implements NoticeFeedCache {
  _ThrowingCache({this.throwOnRead = false, this.throwOnWrite = false});

  final bool throwOnRead;
  final bool throwOnWrite;

  @override
  String? readPayload() {
    if (throwOnRead) throw StateError('storage read denied');
    return null;
  }

  @override
  void write({required String payload}) {
    if (throwOnWrite) throw StateError('storage write denied');
  }
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
            'summary': '담당자가 확인 후 초대 일정을 이메일로 안내해 드립니다.',
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

  test('네트워크 실패 시 마지막 정상 feed를 사용하고 캐시가 없으면 오류를 전달한다', () async {
    final cached = MemoryNoticeFeedCache()
      ..write(
        payload: jsonEncode({
          'schemaVersion': 1,
          'banners': [
            {
              'id': 'cached',
              'title': '캐시된 공지',
              'summary': '오프라인에서도 마지막 공지를 표시합니다.',
              'startsAt': '2026-09-01T00:00:00Z',
              'endsAt': '2026-10-01T00:00:00Z',
              'cta': {'label': '멘토 열기', 'href': '/mentor'},
            },
          ],
        }),
      );
    final dio = Dio()..httpClientAdapter = _FailingAdapter();
    final now = DateTime.parse('2026-09-05T00:00:00Z');

    final recovered = await NoticeFeedClient(
      dio: dio,
      cache: cached,
      homeBaseUrl: 'https://leva.ai.kr',
    ).loadActive(now);
    expect(recovered.single.id, 'cached');
    expect(recovered.single.ctaPath, '/mentor');

    final uncached = NoticeFeedClient(
      dio: dio,
      cache: MemoryNoticeFeedCache(),
      homeBaseUrl: 'https://leva.ai.kr',
    );
    await expectLater(uncached.loadActive(now), throwsA(isA<DioException>()));
  });

  test('지원하지 않는 schema와 20개 초과 배너는 거부한다', () async {
    final now = DateTime.parse('2026-09-05T00:00:00Z');
    for (final payload in <Map<String, dynamic>>[
      {'schemaVersion': 2, 'banners': const []},
      {
        'schemaVersion': 1,
        'banners': List.filled(21, const <String, dynamic>{}),
      },
    ]) {
      final dio = Dio()
        ..httpClientAdapter = _SequenceAdapter([_json(200, payload)]);
      final client = NoticeFeedClient(
        dio: dio,
        cache: MemoryNoticeFeedCache(),
        homeBaseUrl: 'https://leva.ai.kr',
      );
      await expectLater(
        client.loadActive(now),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('선택 캐시의 read/write 실패가 정상 feed를 막지 않는다', () async {
    Map<String, dynamic> payload(String id) => {
      'schemaVersion': 1,
      'banners': [
        {
          'id': id,
          'title': '공지',
          'summary': '내용',
          'startsAt': '2026-09-01T00:00:00Z',
          'endsAt': '2026-10-01T00:00:00Z',
          'cta': {'label': '열기', 'href': '/mentor'},
        },
      ],
    };
    final now = DateTime.parse('2026-09-05T00:00:00Z');

    for (final cache in [
      _ThrowingCache(throwOnRead: true),
      _ThrowingCache(throwOnWrite: true),
    ]) {
      final dio = Dio()
        ..httpClientAdapter = _SequenceAdapter([_json(200, payload('safe'))]);
      final result = await NoticeFeedClient(
        dio: dio,
        cache: cache,
        homeBaseUrl: 'https://leva.ai.kr',
      ).loadActive(now);
      expect(result.single.id, 'safe');
    }
  });

  test('VM fallback cache는 호출마다 격리된다', () {
    expect(noticeFeedCache(), isNot(same(noticeFeedCache())));
  });
}
