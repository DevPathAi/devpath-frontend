import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

typedef AdminStatsFetch = Future<Map<String, int>> Function();

/// Narrow seam for dashboard contract tests and live `/admin/stats` wiring.
final adminStatsFetchProvider = Provider<AdminStatsFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final json = await client.get<Map<String, dynamic>>('/admin/stats');
    return json.map((key, value) => MapEntry(key, (value as num).toInt()));
  };
});
