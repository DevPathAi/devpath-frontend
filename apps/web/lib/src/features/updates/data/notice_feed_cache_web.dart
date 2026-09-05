import 'package:web/web.dart' as web;

import 'notice_feed_cache.dart';

class _WebNoticeFeedCache implements NoticeFeedCache {
  const _WebNoticeFeedCache();

  @override
  String? readPayload() =>
      web.window.localStorage.getItem(noticeFeedPayloadKey);

  @override
  String? readEtag() => web.window.localStorage.getItem(noticeFeedEtagKey);

  @override
  void write({required String payload, String? etag}) {
    web.window.localStorage.setItem(noticeFeedPayloadKey, payload);
    if (etag == null || etag.isEmpty) {
      web.window.localStorage.removeItem(noticeFeedEtagKey);
    } else {
      web.window.localStorage.setItem(noticeFeedEtagKey, etag);
    }
  }
}

NoticeFeedCache createNoticeFeedCache() => const _WebNoticeFeedCache();
