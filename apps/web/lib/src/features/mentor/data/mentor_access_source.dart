import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

typedef MentorAccessFetch = Future<Map<String, dynamic>> Function();
typedef MentorInviteRedeem = Future<Map<String, dynamic>> Function(String code);

final mentorAccessFetchProvider = Provider<MentorAccessFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return () => client.get<Map<String, dynamic>>('/mentor-access/me');
});

final mentorInviteRedeemProvider = Provider<MentorInviteRedeem>((ref) {
  final client = ref.watch(apiClientProvider);
  return (code) => client.post<Map<String, dynamic>>(
    '/mentor-access/redeem',
    body: {'code': code},
  );
});
