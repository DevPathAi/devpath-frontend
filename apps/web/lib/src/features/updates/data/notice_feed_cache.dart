import 'notice_feed_cache_web.dart'
    if (dart.library.io) 'notice_feed_cache_stub.dart';

const noticeFeedPayloadKey = 'leva.updates.feed.payload.v1';

abstract interface class NoticeFeedCache {
  String? readPayload();
  void write({required String payload});
}

class MemoryNoticeFeedCache implements NoticeFeedCache {
  String? _payload;

  @override
  String? readPayload() => _payload;

  @override
  void write({required String payload}) => _payload = payload;
}

NoticeFeedCache noticeFeedCache() => createNoticeFeedCache();
