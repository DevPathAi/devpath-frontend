import 'dart:convert';

import 'package:dio/dio.dart';

export 'notice_feed_cache.dart' show MemoryNoticeFeedCache;
import 'notice_feed_cache.dart';

class NoticeBanner {
  const NoticeBanner({
    required this.id,
    required this.title,
    required this.summary,
    required this.startsAt,
    required this.endsAt,
    required this.ctaLabel,
    required this.ctaPath,
  });

  final String id;
  final String title;
  final String summary;
  final DateTime startsAt;
  final DateTime endsAt;
  final String ctaLabel;
  final String ctaPath;
}

class NoticeFeedClient {
  NoticeFeedClient({
    required this.dio,
    required this.cache,
    required this.homeBaseUrl,
  });

  final Dio dio;
  final NoticeFeedCache cache;
  final String homeBaseUrl;

  Future<List<NoticeBanner>> loadActive(DateTime now) async {
    final cachedPayload = cache.readPayload();
    try {
      final response = await dio.get<Object?>(
        '$homeBaseUrl/updates/feed.json',
        options: Options(
          validateStatus: (status) => status == 200 || status == 304,
        ),
      );
      if (response.statusCode == 304) {
        return _activeFromPayload(cachedPayload, now);
      }
      final payload = response.data is String
          ? response.data! as String
          : jsonEncode(response.data);
      final parsed = _activeFromPayload(payload, now);
      cache.write(payload: payload, etag: response.headers.value('etag'));
      return parsed;
    } catch (_) {
      if (cachedPayload != null) return _activeFromPayload(cachedPayload, now);
      rethrow;
    }
  }

  List<NoticeBanner> _activeFromPayload(String? payload, DateTime now) {
    if (payload == null) return const [];
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
      throw const FormatException('unsupported updates feed');
    }
    final rawBanners = decoded['banners'];
    if (rawBanners is! List || rawBanners.length > 20) {
      throw const FormatException('invalid updates feed');
    }
    return rawBanners
        .whereType<Map<String, dynamic>>()
        .map(_parseBanner)
        .whereType<NoticeBanner>()
        .where(
          (banner) =>
              !now.isBefore(banner.startsAt) && !now.isAfter(banner.endsAt),
        )
        .toList(growable: false);
  }

  NoticeBanner? _parseBanner(Map<String, dynamic> json) {
    final cta = json['cta'];
    final startsAt = DateTime.tryParse(json['startsAt'] as String? ?? '');
    final endsAt = DateTime.tryParse(json['endsAt'] as String? ?? '');
    if (cta is! Map<String, dynamic> || startsAt == null || endsAt == null) {
      return null;
    }
    final path = _safeAppPath(cta['href'] as String?);
    final id = json['id'];
    final title = json['title'];
    final summary = json['summary'];
    final label = cta['label'];
    if (path == null ||
        id is! String ||
        id.isEmpty ||
        title is! String ||
        title.isEmpty ||
        summary is! String ||
        summary.isEmpty ||
        label is! String ||
        label.isEmpty ||
        startsAt.isAfter(endsAt)) {
      return null;
    }
    return NoticeBanner(
      id: id,
      title: title,
      summary: summary,
      startsAt: startsAt,
      endsAt: endsAt,
      ctaLabel: label,
      ctaPath: path,
    );
  }

  String? _safeAppPath(String? href) {
    if (href == null) return null;
    final uri = Uri.tryParse(href);
    if (uri == null) return null;
    if (!uri.hasScheme && href.startsWith('/') && !href.startsWith('//')) {
      return uri.path;
    }
    if (uri.scheme == 'https' && uri.host == 'app.leva.ai.kr') {
      return uri.path;
    }
    return null;
  }
}
