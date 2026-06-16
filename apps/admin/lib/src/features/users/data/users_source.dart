import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import 'admin_user_row.dart';

typedef AdminUsersFetch = Future<Page<AdminUserRow>> Function({String? cursor, String? status});

final adminUsersFetchProvider = Provider<AdminUsersFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({String? cursor, String? status}) async {
    final query = <String, dynamic>{
      if (cursor != null) 'cursor': cursor,
      if (status != null) 'status': status,
    };
    final json = await client.get<Map<String, dynamic>>('/admin/users',
        query: query.isEmpty ? null : query);
    return Page.fromJson(
        json, (o) => AdminUserRow.fromJson((o as Map).cast<String, dynamic>()));
  };
});
