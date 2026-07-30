import 'package:devpath_web/src/features/community/application/post_detail_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/state/post_detail_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPostDetail _detail({List<CommunityComment> comments = const []}) =>
    CommunityPostDetail(
      id: 9,
      boardType: 'FREE',
      title: 't',
      bodyMd: 'b',
      comments: comments,
    );

void main() {
  test('load: 상세를 loaded로 채운다', () async {
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue((id) async => _detail()),
      ],
    );
    addTearDown(c.dispose);

    await c.read(postDetailControllerProvider(9).notifier).load();
    final s = c.read(postDetailControllerProvider(9));
    expect(s.phase, PostDetailPhase.loaded);
    expect(s.detail?.id, 9);
  });

  test('addComment: 작성 후 상세를 재조회해 댓글 반영', () async {
    var calls = 0;
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue((id) async {
          calls++;
          return _detail(
            comments: calls >= 2
                ? [const CommunityComment(id: 1, bodyMd: '새댓글', createdAt: 'x')]
                : const [],
          );
        }),
        commentCreateProvider.overrideWithValue(
          (postId, bodyMd) async =>
              const CommunityComment(id: 1, bodyMd: '새댓글', createdAt: 'x'),
        ),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(postDetailControllerProvider(9).notifier);
    await n.load();
    await n.addComment('새댓글');
    expect(
      c.read(postDetailControllerProvider(9)).detail?.comments.single.bodyMd,
      '새댓글',
    );
  });

  test('upvote: 투표 후 상세를 재조회', () async {
    var fetchCalls = 0;
    CommunityVoteTarget? seenTarget;
    int? seenId;
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue((id) async {
          fetchCalls++;
          return _detail();
        }),
        communityVoteProvider.overrideWithValue(({
          required CommunityVoteTarget target,
          required int id,
          required int value,
        }) async {
          seenTarget = target;
          seenId = id;
        }),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(postDetailControllerProvider(9).notifier);
    await n.load();
    await n.upvote();

    expect(seenTarget, CommunityVoteTarget.post);
    expect(seenId, 9);
    expect(fetchCalls, 2); // load + 재조회
  });
}
