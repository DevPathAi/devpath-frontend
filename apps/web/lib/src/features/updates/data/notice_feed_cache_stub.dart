import 'notice_feed_cache.dart';

final _cache = MemoryNoticeFeedCache();

NoticeFeedCache createNoticeFeedCache() => _cache;
