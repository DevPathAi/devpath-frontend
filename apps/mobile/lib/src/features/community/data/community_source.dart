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
