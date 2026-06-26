import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 커뮤니티 Q&A 데이터 레이어 — gateway `/community/**`(빌드 D) 실API wire.
///
/// 모든 함수는 `apiClient`만 경유한다. **목 모드는 `MockHttpAdapter`(픽스처)가 처리**하므로
/// 여기서 목 분기를 두지 않는다(REST는 어댑터로 충분 — 멘토 SSE와 대비). 테스트는 각
/// 함수 프로바이더를 inline override해 HTTP 없이 검증한다(기존 패턴 승계).

/// 투표 대상 — `POST /community/{posts|answers}/{id}/vote`.
enum CommunityVoteTarget {
  post('posts'),
  answer('answers');

  const CommunityVoteTarget(this.segment);
  final String segment;
}

/// 목록 `GET /community/posts?board=&tag=&sort=` → `List<PostSummaryView>`(**bare 배열**, 페이지네이션 없음).
typedef CommunityListFetch =
    Future<List<CommunityPostSummary>> Function({
      String? board,
      String? tag,
      String? sort,
    });

/// 상세 `GET /community/questions/{id}` → `QuestionDetailView`.
typedef QnaDetailFetch = Future<CommunityQuestionDetail> Function(int id);

/// 작성 `POST /community/questions {title, bodyMd, tags[]}` → `QuestionDetailView`(즉시 게시, AI 시드는 비동기).
typedef QuestionCreate =
    Future<CommunityQuestionDetail> Function({
      required String title,
      required String bodyMd,
      required List<String> tags,
    });

/// 인간 답변 `POST /community/questions/{id}/answers {bodyMd}` → `AnswerView`.
typedef AnswerCreate =
    Future<CommunityAnswer> Function(int questionId, String bodyMd);

/// 채택 `POST /community/answers/{id}/accept`(질문자 OWNER, 204/200 void).
typedef AnswerAccept = Future<void> Function(int answerId);

/// 투표 `POST /community/{posts|answers}/{id}/vote {value}`(UPSERT, void).
typedef CommunityVote =
    Future<void> Function({
      required CommunityVoteTarget target,
      required int id,
      required int value,
    });

/// 유사질문 `GET /community/questions/similar?q=` → `List<SimilarQuestionView>`.
typedef SimilarQuestionsFetch =
    Future<List<SimilarQuestion>> Function(String q);

/// 태그 자동완성 `GET /community/tags?q=` → `List<TagView>`.
typedef TagAutocomplete = Future<List<CommunityTag>> Function(String q);

List<T> _list<T>(Object? data, T Function(Map<String, dynamic>) fromJson) =>
    (data as List? ?? const [])
        .map((e) => fromJson((e as Map).cast<String, dynamic>()))
        .toList();

final communityListProvider = Provider<CommunityListFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({String? board, String? tag, String? sort}) async {
    final query = <String, dynamic>{
      'board': ?board,
      'tag': ?tag,
      'sort': ?sort,
    };
    final data = await client.get<List<dynamic>>(
      '/community/posts',
      query: query.isEmpty ? null : query,
    );
    return _list(data, CommunityPostSummary.fromJson);
  };
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

final questionCreateProvider = Provider<QuestionCreate>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required String title,
    required String bodyMd,
    required List<String> tags,
  }) async {
    final json = await client.post<Map<String, dynamic>>(
      '/community/questions',
      body: {'title': title, 'bodyMd': bodyMd, 'tags': tags},
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

final similarQuestionsProvider = Provider<SimilarQuestionsFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (q) async {
    final data = await client.get<List<dynamic>>(
      '/community/questions/similar',
      query: {'q': q},
    );
    return _list(data, SimilarQuestion.fromJson);
  };
});

final tagAutocompleteProvider = Provider<TagAutocomplete>((ref) {
  final client = ref.watch(apiClientProvider);
  return (q) async {
    final data = await client.get<List<dynamic>>(
      '/community/tags',
      query: {'q': q},
    );
    return _list(data, CommunityTag.fromJson);
  };
});
