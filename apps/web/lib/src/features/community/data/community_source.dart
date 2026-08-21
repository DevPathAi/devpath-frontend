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

/// 검색 `GET /community/search?q=&board=&tag=&solved=&sort=&page=&size=` → `SearchResponse`.
/// 목록과 달리 **envelope**(`items`·`total`·`page`·`size`)이며 페이지네이션이 있다.
typedef CommunitySearchFetch =
    Future<CommunitySearchResult> Function({
      required String q,
      String? board,
      String? tag,
      bool? solved,
      String? sort,
      int page,
      int size,
    });

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

/// 신고 접수 `POST /community/reports`.
/// 409=이미 신고한 대상, 400=본인 콘텐츠·잘못된 값, 404=대상 없음.
typedef CommunityReportSubmit =
    Future<CommunityReportResult> Function({
      required String targetType,
      required int targetId,
      required CommunityReportCategory category,
      String? reason,
    });

final communityReportProvider = Provider<CommunityReportSubmit>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required String targetType,
    required int targetId,
    required CommunityReportCategory category,
    String? reason,
  }) async {
    final json = await client.post<Map<String, dynamic>>(
      '/community/reports',
      body: {
        'targetType': targetType,
        'targetId': targetId,
        'category': category.wire,
        'reason': ?reason,
      },
    );
    return CommunityReportResult.fromJson(json);
  };
});

final communitySearchProvider = Provider<CommunitySearchFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required String q,
    String? board,
    String? tag,
    bool? solved,
    String? sort,
    int page = 0,
    int size = 20,
  }) async {
    final json = await client.get<Map<String, dynamic>>(
      '/community/search',
      query: <String, dynamic>{
        'q': q,
        'board': ?board,
        'tag': ?tag,
        'solved': ?solved,
        'sort': ?sort,
        'page': page,
        'size': size,
      },
    );
    return CommunitySearchResult.fromJson(json);
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

/// 일반 게시글 작성 `POST /community/posts {boardType,title,bodyMd,tags}` → `PostDetailView`.
typedef PostCreate =
    Future<CommunityPostDetail> Function({
      required String boardType,
      required String title,
      required String bodyMd,
      required List<String> tags,
    });

/// 일반 게시글 상세 `GET /community/posts/{id}` → `PostDetailView`(FREE/FEEDBACK, 댓글 포함).
typedef PostDetailFetch = Future<CommunityPostDetail> Function(int id);

/// 댓글 작성 `POST /community/posts/{id}/comments {bodyMd}` → `CommentView`.
typedef CommentCreate =
    Future<CommunityComment> Function(int postId, String bodyMd);

final postCreateProvider = Provider<PostCreate>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required String boardType,
    required String title,
    required String bodyMd,
    required List<String> tags,
  }) async {
    final json = await client.post<Map<String, dynamic>>(
      '/community/posts',
      body: {
        'boardType': boardType,
        'title': title,
        'bodyMd': bodyMd,
        'tags': tags,
      },
    );
    return CommunityPostDetail.fromJson(json);
  };
});

final postDetailFetchProvider = Provider<PostDetailFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id) async {
    final json = await client.get<Map<String, dynamic>>('/community/posts/$id');
    return CommunityPostDetail.fromJson(json);
  };
});

final commentCreateProvider = Provider<CommentCreate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (postId, bodyMd) async {
    final json = await client.post<Map<String, dynamic>>(
      '/community/posts/$postId/comments',
      body: {'bodyMd': bodyMd},
    );
    return CommunityComment.fromJson(json);
  };
});

/// 글·질문 수정 `PUT /community/posts/{id} {title, bodyMd}` → `PostDetailView`.
///
/// ★태그가 없다★ — 평판이 투표 시점 태그로 귀속되어 소급 변경이 어긋나므로 서버가 받지 않는다.
typedef PostUpdate =
    Future<CommunityPostDetail> Function({
      required int id,
      required String title,
      required String bodyMd,
    });

/// 글·질문 삭제 `DELETE /community/posts/{id}` → 204. 이미 삭제된 것을 다시 지우면 404.
typedef PostDelete = Future<void> Function(int id);

/// 답변 수정 `PUT /community/answers/{id} {bodyMd}` → `AnswerView`.
typedef AnswerUpdate = Future<CommunityAnswer> Function(int id, String bodyMd);

/// 답변 삭제 `DELETE /community/answers/{id}` → 204. 채택된 답변이면 409.
typedef AnswerDelete = Future<void> Function(int id);

/// 댓글 수정 `PUT /community/comments/{id} {bodyMd}` → `CommentView`.
typedef CommentUpdate =
    Future<CommunityComment> Function(int id, String bodyMd);

/// 댓글 삭제 `DELETE /community/comments/{id}` → 204.
typedef CommentDelete = Future<void> Function(int id);

final postUpdateProvider = Provider<PostUpdate>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required int id,
    required String title,
    required String bodyMd,
  }) async {
    final json = await client.put<Map<String, dynamic>>(
      '/community/posts/$id',
      body: {'title': title, 'bodyMd': bodyMd},
    );
    return CommunityPostDetail.fromJson(json);
  };
});

final postDeleteProvider = Provider<PostDelete>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id) async {
    await client.delete<dynamic>('/community/posts/$id');
  };
});

final answerUpdateProvider = Provider<AnswerUpdate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, bodyMd) async {
    final json = await client.put<Map<String, dynamic>>(
      '/community/answers/$id',
      body: {'bodyMd': bodyMd},
    );
    return CommunityAnswer.fromJson(json);
  };
});

final answerDeleteProvider = Provider<AnswerDelete>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id) async {
    await client.delete<dynamic>('/community/answers/$id');
  };
});

final commentUpdateProvider = Provider<CommentUpdate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, bodyMd) async {
    final json = await client.put<Map<String, dynamic>>(
      '/community/comments/$id',
      body: {'bodyMd': bodyMd},
    );
    return CommunityComment.fromJson(json);
  };
});

final commentDeleteProvider = Provider<CommentDelete>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id) async {
    await client.delete<dynamic>('/community/comments/$id');
  };
});
