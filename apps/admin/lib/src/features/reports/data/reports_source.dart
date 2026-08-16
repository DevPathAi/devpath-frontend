import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import 'report.dart';

typedef ReportsListFetch =
    Future<List<AdminReport>> Function({
      String? status,
      required int page,
      required int size,
    });
typedef ReportDecision = Future<void> Function(int id, String action);

final reportsListFetchProvider = Provider<ReportsListFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({status, required page, required size}) async {
    final json = await client.get<Map<String, dynamic>>(
      '/community/admin/reports',
      query: {'status': ?status, 'page': page, 'size': size},
    );
    return (json['items'] as List? ?? const [])
        .map((o) => AdminReport.fromJson((o as Map).cast<String, dynamic>()))
        .toList();
  };
});

final reportDecisionProvider = Provider<ReportDecision>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, action) async {
    await client.post<Map<String, dynamic>>(
      '/community/admin/reports/$id/resolve',
      body: {'action': action},
    );
  };
});
