import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import 'ad_slot_content.dart';

typedef AdFetch = Future<AdSlotContent?> Function(String slot);
typedef AdEvent = Future<void> Function(int id, String type);

/// GET /ads?slot= — 200이면 봉투 파싱, 204/에러/미지의 type이면 null(fail-silent).
final adFetchProvider = Provider<AdFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (slot) async {
    try {
      final json = await client.get<Map<String, dynamic>?>(
        '/ads',
        query: {'slot': slot},
      );
      if (json == null || json.isEmpty) return null; // 204 → 빈 본문
      return adSlotContentFromJson(json);
    } catch (_) {
      return null; // fail-silent
    }
  };
});

/// POST /ads/{id}/events — 측정. 실패는 조용히 무시.
final adEventProvider = Provider<AdEvent>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, type) async {
    try {
      await client.post<void>('/ads/$id/events', body: {'type': type});
    } catch (_) {
      // 측정 유실 허용
    }
  };
});
