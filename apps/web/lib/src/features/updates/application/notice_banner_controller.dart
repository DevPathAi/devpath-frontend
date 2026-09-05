import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../data/notice_feed_cache.dart';
import '../data/notice_feed_client.dart';

sealed class NoticeBannerState {
  const NoticeBannerState();
}

class NoticeBannerLoading extends NoticeBannerState {
  const NoticeBannerLoading();
}

class NoticeBannerNone extends NoticeBannerState {
  const NoticeBannerNone();
}

class NoticeBannerReady extends NoticeBannerState {
  const NoticeBannerReady(this.banner);
  final NoticeBanner banner;
}

final noticeFeedDioProvider = Provider<Dio>((ref) => Dio());
final noticeFeedCacheProvider = Provider<NoticeFeedCache>(
  (ref) => noticeFeedCache(),
);
final noticeFeedClientProvider = Provider<NoticeFeedClient>(
  (ref) => NoticeFeedClient(
    dio: ref.watch(noticeFeedDioProvider),
    cache: ref.watch(noticeFeedCacheProvider),
    homeBaseUrl: ref.watch(appConfigProvider).homeBaseUrl,
  ),
);

class NoticeBannerController extends Notifier<NoticeBannerState> {
  Future<void>? _load;

  @override
  NoticeBannerState build() {
    Future.microtask(loadOnce);
    return const NoticeBannerLoading();
  }

  Future<void> loadOnce() => _load ??= _performLoad();

  Future<void> _performLoad() async {
    try {
      final active = await ref
          .read(noticeFeedClientProvider)
          .loadActive(DateTime.now());
      if (ref.mounted) {
        state = active.isEmpty
            ? const NoticeBannerNone()
            : NoticeBannerReady(active.first);
      }
    } catch (_) {
      if (ref.mounted) state = const NoticeBannerNone();
    }
  }
}

final noticeBannerControllerProvider =
    NotifierProvider<NoticeBannerController, NoticeBannerState>(
      NoticeBannerController.new,
    );
