import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import 'report.dart';
import 'revision.dart';

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

/// 콘텐츠 내리기 `DELETE /community/admin/{posts|answers|comments}/{id}`.
///
/// 작성자 삭제(DELETED)와 달리 HIDDEN 은 규정 위반 판단이므로 그 콘텐츠로 얻은 평판을
/// 회수한다. 관리자는 「채택된 답변은 못 지운다」(409) 제한도 받지 않는다.
typedef ContentTakedown =
    Future<void> Function(String targetType, int targetId);

/// 수정 이력 `GET /community/admin/revisions?targetType=&targetId=` → 최신순.
typedef RevisionsFetch =
    Future<List<AdminRevision>> Function(String targetType, int targetId);

/// 신고 대상 종류를 관리자 경로 세그먼트로 옮긴다.
String _adminSegment(String targetType) => switch (targetType) {
  'ANSWER' => 'answers',
  'COMMENT' => 'comments',
  _ => 'posts',
};

final contentTakedownProvider = Provider<ContentTakedown>((ref) {
  final client = ref.watch(apiClientProvider);
  return (targetType, targetId) async {
    await client.delete<dynamic>(
      '/community/admin/${_adminSegment(targetType)}/$targetId',
    );
  };
});

final revisionsFetchProvider = Provider<RevisionsFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (targetType, targetId) async {
    final data = await client.get<List<dynamic>>(
      '/community/admin/revisions',
      query: {'targetType': targetType, 'targetId': targetId},
    );
    return (data as List? ?? const [])
        .map((o) => AdminRevision.fromJson((o as Map).cast<String, dynamic>()))
        .toList();
  };
});
