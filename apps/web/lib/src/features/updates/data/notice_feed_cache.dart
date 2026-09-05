import 'notice_feed_cache_web.dart'
    if (dart.library.io) 'notice_feed_cache_stub.dart';

const noticeFeedPayloadKey = 'leva.updates.feed.payload.v1';
const noticeFeedEtagKey = 'leva.updates.feed.etag.v1';

abstract interface class NoticeFeedCache {
  String? readPayload();
  String? readEtag();
  void write({required String payload, String? etag});
}

class MemoryNoticeFeedCache implements NoticeFeedCache {
  String? _payload;
  String? _etag;

  @override
  String? readPayload() => _payload;

  @override
  String? readEtag() => _etag;

  @override
  void write({required String payload, String? etag}) {
    _payload = payload;
    _etag = etag;
  }
}

NoticeFeedCache noticeFeedCache() => createNoticeFeedCache();
