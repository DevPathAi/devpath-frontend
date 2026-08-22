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
/// ★기본값을 두지 않는다★ — 파괴적 요청의 경로를 정하는 자리다. `_ => 'posts'` 로 두면
/// 알 수 없는 대상 종류(오타·새 유형·대소문자 차이)가 **글 삭제**로 흘러, targetId 가
/// 우연히 겹치는 무관한 글이 내려간다. 모르면 보내지 않는 쪽이 옳다.
String? _adminSegment(String targetType) => switch (targetType) {
  'POST' => 'posts',
  'ANSWER' => 'answers',
  'COMMENT' => 'comments',
  _ => null,
};

/// 이 종류를 내릴 수 있는가. 화면이 버튼을 감출 때 쓴다 — 눌러 봐야 실패하는 버튼을
/// 보여 주는 대신 아예 내주지 않는다.
bool canTakedown(String targetType) => _adminSegment(targetType) != null;

final contentTakedownProvider = Provider<ContentTakedown>((ref) {
  final client = ref.watch(apiClientProvider);
  return (targetType, targetId) async {
    final segment = _adminSegment(targetType);
    if (segment == null) {
      throw ArgumentError.value(targetType, 'targetType', '알 수 없는 대상 종류');
    }
    await client.delete<dynamic>('/community/admin/$segment/$targetId');
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
