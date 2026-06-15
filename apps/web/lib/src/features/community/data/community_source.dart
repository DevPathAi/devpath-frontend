import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 커서로 한 페이지 조회. 테스트에서 override해 다중 페이지 검증.
typedef CommunityFetch = Future<Page<CommunityPost>> Function({String? cursor});

final communityFetchProvider = Provider<CommunityFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({String? cursor}) async {
    final json = await client.get<Map<String, dynamic>>(
      '/community/posts',
      query: cursor == null ? null : {'cursor': cursor},
    );
    return Page.fromJson(
      json,
      (o) => CommunityPost.fromJson((o as Map).cast<String, dynamic>()),
    );
  };
});
