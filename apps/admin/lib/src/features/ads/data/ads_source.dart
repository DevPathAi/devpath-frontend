import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import 'ad_row.dart';
import 'ad_slot_config_row.dart';
import 'ad_stats_row.dart';

typedef AdsListFetch =
    Future<List<AdRow>> Function({String? slot, String? status});
typedef AdCreate = Future<AdRow> Function(AdRow draft);
typedef AdUpdate = Future<AdRow> Function(int id, AdRow draft);
typedef AdDelete = Future<void> Function(int id);
typedef AdImageUpload =
    Future<AdRow> Function(
      int id,
      List<int> bytes,
      String filename,
      String? contentType,
    );
typedef AdSettingsGet = Future<bool> Function();
typedef AdSettingsSet = Future<bool> Function(bool enabled);
typedef AdStatsFetch =
    Future<List<AdStatsRow>> Function(int id, DateTime from, DateTime to);

String _d(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

final adsListProvider = Provider<AdsListFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({String? slot, String? status}) async {
    final query = <String, dynamic>{};
    if (slot != null) query['slot'] = slot;
    if (status != null) query['status'] = status;
    final json = await client.get<List<dynamic>>(
      '/admin/ads',
      query: query.isEmpty ? null : query,
    );
    return json
        .map((o) => AdRow.fromJson((o as Map).cast<String, dynamic>()))
        .toList();
  };
});

final adCreateProvider = Provider<AdCreate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (draft) async {
    final json = await client.post<Map<String, dynamic>>(
      '/admin/ads',
      body: draft.toRequestJson(),
    );
    return AdRow.fromJson(json);
  };
});

final adUpdateProvider = Provider<AdUpdate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, draft) async {
    final json = await client.put<Map<String, dynamic>>(
      '/admin/ads/$id',
      body: draft.toRequestJson(),
    );
    return AdRow.fromJson(json);
  };
});

final adDeleteProvider = Provider<AdDelete>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id) => client.delete<void>('/admin/ads/$id');
});

typedef AdBulkDelete = Future<void> Function(List<int> ids);

final adBulkDeleteProvider = Provider<AdBulkDelete>((ref) {
  final client = ref.watch(apiClientProvider);
  return (ids) =>
      client.post<void>('/admin/ads/bulk-delete', body: {'ids': ids});
});

final adImageUploadProvider = Provider<AdImageUpload>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, bytes, filename, contentType) async {
    final json = await client.postMultipart<Map<String, dynamic>>(
      '/admin/ads/$id/image',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    return AdRow.fromJson(json);
  };
});

final adSettingsGetProvider = Provider<AdSettingsGet>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final json = await client.get<Map<String, dynamic>>('/admin/ads/settings');
    return json['enabled'] as bool;
  };
});

final adSettingsSetProvider = Provider<AdSettingsSet>((ref) {
  final client = ref.watch(apiClientProvider);
  return (enabled) async {
    final json = await client.put<Map<String, dynamic>>(
      '/admin/ads/settings',
      body: {'enabled': enabled},
    );
    return json['enabled'] as bool;
  };
});

typedef AdSlotConfigList = Future<List<AdSlotConfigRow>> Function();
typedef AdSlotConfigSave =
    Future<AdSlotConfigRow> Function(AdSlotConfigRow row);

final adSlotConfigListProvider = Provider<AdSlotConfigList>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final json = await client.get<List<dynamic>>('/admin/ads/slot-config');
    return json
        .map(
          (o) => AdSlotConfigRow.fromJson((o as Map).cast<String, dynamic>()),
        )
        .toList();
  };
});

final adSlotConfigSaveProvider = Provider<AdSlotConfigSave>((ref) {
  final client = ref.watch(apiClientProvider);
  return (row) async {
    final json = await client.put<Map<String, dynamic>>(
      '/admin/ads/slot-config/${row.slot}',
      body: row.toRequestJson(),
    );
    return AdSlotConfigRow.fromJson(json);
  };
});

final adStatsProvider = Provider<AdStatsFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, from, to) async {
    final json = await client.get<List<dynamic>>(
      '/admin/ads/$id/stats',
      query: {'from': _d(from), 'to': _d(to)},
    );
    return json
        .map((o) => AdStatsRow.fromJson((o as Map).cast<String, dynamic>()))
        .toList();
  };
});
