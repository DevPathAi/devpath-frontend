import 'package:web/web.dart' as web;

import 'notice_feed_cache.dart';

class _WebNoticeFeedCache implements NoticeFeedCache {
  const _WebNoticeFeedCache();

  @override
  String? readPayload() =>
      web.window.localStorage.getItem(noticeFeedPayloadKey);

  @override
  void write({required String payload}) {
    web.window.localStorage.setItem(noticeFeedPayloadKey, payload);
  }
}

NoticeFeedCache createNoticeFeedCache() => const _WebNoticeFeedCache();
