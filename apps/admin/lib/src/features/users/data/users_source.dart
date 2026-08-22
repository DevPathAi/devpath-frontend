import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import 'admin_user_row.dart';

typedef AdminUsersFetch =
    Future<Page<AdminUserRow>> Function({String? cursor, String? status});
typedef AdminUserSanction = Future<void> Function(String userId, String action);
typedef AdminUsersApprove = Future<void> Function(String userId);
typedef AdminUserPreApprove = Future<void> Function(String email);

final adminUsersFetchProvider = Provider<AdminUsersFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({String? cursor, String? status}) async {
    final query = <String, dynamic>{};
    if (cursor != null) query['cursor'] = cursor;
    if (status != null) query['status'] = status;
    final json = await client.get<Map<String, dynamic>>(
      '/admin/users',
      query: query.isEmpty ? null : query,
    );
    return Page.fromJson(
      json,
      (o) => AdminUserRow.fromJson((o as Map).cast<String, dynamic>()),
    );
  };
});

final adminUserSanctionProvider = Provider<AdminUserSanction>((ref) {
  final client = ref.watch(apiClientProvider);
  return (userId, action) => client.post<void>(
    '/admin/users/$userId/sanction',
    body: {'action': action},
  );
});

final adminUsersApproveProvider = Provider<AdminUsersApprove>((ref) {
  final client = ref.watch(apiClientProvider);
  return (userId) => client.post<void>('/admin/users/$userId/approve');
});

final adminUserPreApproveProvider = Provider<AdminUserPreApprove>((ref) {
  final client = ref.watch(apiClientProvider);
  return (email) =>
      client.post<void>('/admin/allowlist', body: {'email': email});
});

typedef AdminUsersBulkApprove = Future<void> Function(List<int> ids);

final adminUsersBulkApproveProvider = Provider<AdminUsersBulkApprove>((ref) {
  final client = ref.watch(apiClientProvider);
  return (ids) =>
      client.post<void>('/admin/users/bulk-approve', body: {'ids': ids});
});
