import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 질문 목록 조회 — `GET /community/posts`(bare 배열 PostSummaryView).
typedef CommunityList = Future<List<CommunityPostSummary>> Function();

/// 퀵 캡처 질문 작성 — `POST /community/questions` → QuestionDetailView.
typedef QuestionCreate =
    Future<CommunityQuestionDetail> Function({
      required String title,
      required String bodyMd,
      required List<String> tags,
    });

final communityListProvider = Provider<CommunityList>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final data = await client.get<List<dynamic>>('/community/posts');
    return data
        .map(
          (e) =>
              CommunityPostSummary.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  };
});

final questionCreateProvider = Provider<QuestionCreate>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({required title, required bodyMd, required tags}) async {
    final json = await client.post<Map<String, dynamic>>(
      '/community/questions',
      body: {'title': title, 'bodyMd': bodyMd, 'tags': tags},
    );
    return CommunityQuestionDetail.fromJson(json);
  };
});

/// 투표 대상 — `POST /community/{posts|answers}/{id}/vote`.
enum CommunityVoteTarget {
  post('posts'),
  answer('answers');

  const CommunityVoteTarget(this.segment);
  final String segment;
}

/// 상세 조회 — `GET /community/questions/{id}` → QuestionDetailView.
typedef QnaDetailFetch = Future<CommunityQuestionDetail> Function(int id);

/// 인간 답변 작성 — `POST /community/questions/{id}/answers {bodyMd}` → AnswerView.
typedef AnswerCreate =
    Future<CommunityAnswer> Function(int questionId, String bodyMd);

/// 답변 채택(질문자 OWNER) — `POST /community/answers/{id}/accept`(void).
typedef AnswerAccept = Future<void> Function(int answerId);

/// 게시글/답변 투표 — `POST /community/{posts|answers}/{id}/vote {value}`(void).
typedef CommunityVote =
    Future<void> Function({
      required CommunityVoteTarget target,
      required int id,
      required int value,
    });

final qnaDetailFetchProvider = Provider<QnaDetailFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id) async {
    final json = await client.get<Map<String, dynamic>>(
      '/community/questions/$id',
    );
    return CommunityQuestionDetail.fromJson(json);
  };
});

final answerCreateProvider = Provider<AnswerCreate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (questionId, bodyMd) async {
    final json = await client.post<Map<String, dynamic>>(
      '/community/questions/$questionId/answers',
      body: {'bodyMd': bodyMd},
    );
    return CommunityAnswer.fromJson(json);
  };
});

final answerAcceptProvider = Provider<AnswerAccept>((ref) {
  final client = ref.watch(apiClientProvider);
  return (answerId) async {
    await client.post<dynamic>('/community/answers/$answerId/accept');
  };
});

final communityVoteProvider = Provider<CommunityVote>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required CommunityVoteTarget target,
    required int id,
    required int value,
  }) async {
    await client.post<dynamic>(
      '/community/${target.segment}/$id/vote',
      body: {'value': value},
    );
  };
});
