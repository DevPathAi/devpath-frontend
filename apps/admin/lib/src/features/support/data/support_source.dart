import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import 'support_request.dart';

typedef SupportListFetch =
    Future<List<SupportRequestRow>> Function({
      String? status,
      String? type,
      required int limit,
    });
typedef SupportDetailFetch = Future<SupportRequestDetail> Function(int id);
typedef SupportStatusUpdate =
    Future<void> Function(int id, String status, {String? adminNote});

final supportListFetchProvider = Provider<SupportListFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({status, type, required limit}) async {
    final json = await client.get<Map<String, dynamic>>(
      '/admin/support-requests',
      query: {'status': ?status, 'type': ?type, 'limit': limit},
    );
    return (json['data'] as List? ?? const [])
        .map(
          (value) => SupportRequestRow.fromJson(
            (value as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  };
});

final supportDetailFetchProvider = Provider<SupportDetailFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id) async {
    final json = await client.get<Map<String, dynamic>>(
      '/admin/support-requests/$id',
    );
    return SupportRequestDetail.fromJson(json);
  };
});

final supportStatusUpdateProvider = Provider<SupportStatusUpdate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, status, {adminNote}) => client.post<void>(
    '/admin/support-requests/$id/status',
    body: {'status': status, 'adminNote': ?adminNote},
  );
});
