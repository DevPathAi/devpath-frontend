import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// LCS(학습 맥락 자동 첨부) 데이터 레이어 — gateway `/lcs/**`(슬라이스 #9).
///
/// 질문 작성 폼의 맥락 카드(draft→commit)와 질문 상세의 답변자 맥락 패널(by-question)에서 쓴다.
/// community-svc는 무변경 — 답변자 패널은 `questionId`로 역조회한다.
/// 목 모드는 `MockHttpAdapter`(픽스처)가 처리하므로 여기서 목 분기를 두지 않는다(community 패턴 승계).

/// 미리보기 조립 `POST /lcs/snapshots/draft {purpose, contentId?, requestedFields[]}` → [LcsDraft].
/// requestedFields 가 비면 서버가 전체 요청으로 간주한다.
typedef LcsDraftCreate =
    Future<LcsDraft> Function({List<String> requestedFields, int? contentId});

/// 영속(불변) `POST /lcs/snapshots/{draftId}/commit {attachedToType, attachedToId, visibility}`
/// → snapshotId. 질문 게시 후 받은 questionId 를 attachedToId 로 넘긴다(순환 회피).
typedef LcsCommit =
    Future<int> Function({
      required String draftId,
      required int attachedToId,
      required String visibility,
    });

/// 답변자 역조회 `GET /lcs/snapshots/by-question/{questionId}` → [LcsSnapshotView].
/// 스냅샷이 없으면(404) **null** 을 돌려 패널을 숨긴다(비블로킹).
typedef LcsByQuestionFetch = Future<LcsSnapshotView?> Function(int questionId);

final lcsDraftProvider = Provider<LcsDraftCreate>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({List<String> requestedFields = const [], int? contentId}) async {
    final json = await client.post<Map<String, dynamic>>(
      '/lcs/snapshots/draft',
      body: {
        'purpose': 'question_attachment',
        'contentId': ?contentId,
        'requestedFields': requestedFields,
      },
    );
    return LcsDraft.fromJson(json);
  };
});

final lcsCommitProvider = Provider<LcsCommit>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required String draftId,
    required int attachedToId,
    required String visibility,
  }) async {
    final json = await client.post<Map<String, dynamic>>(
      '/lcs/snapshots/$draftId/commit',
      body: {
        'attachedToType': 'question',
        'attachedToId': attachedToId,
        'visibility': visibility,
      },
    );
    return (json['snapshotId'] as num).toInt();
  };
});

final lcsByQuestionProvider = Provider<LcsByQuestionFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (questionId) async {
    try {
      final json = await client.get<Map<String, dynamic>>(
        '/lcs/snapshots/by-question/$questionId',
      );
      return LcsSnapshotView.fromJson(json);
    } on ApiException catch (e) {
      // 스냅샷 없음(404) → 패널 미표시. 그 외 오류는 표면화(FutureProvider가 AsyncError로 흡수).
      if (e.status == 404) return null;
      rethrow;
    }
  };
});

/// 질문 상세 답변자 패널용. [lcsByQuestionProvider]를 래핑해 위젯에서 watch 한다.
/// 테스트는 [lcsByQuestionProvider]를 override 한다.
final questionSnapshotProvider = FutureProvider.family<LcsSnapshotView?, int>((
  ref,
  questionId,
) {
  return ref.watch(lcsByQuestionProvider)(questionId);
});
