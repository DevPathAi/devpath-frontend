import 'package:devpath_web/src/features/community/application/community_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/state/community_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPostSummary _p(int id) =>
    CommunityPostSummary(id: id, title: '글 $id', answerCount: 1);

void main() {
  test('load: bare 배열을 목록으로 채운다(페이지네이션 없음)', () async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [_p(1), _p(2)],
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(communityControllerProvider.notifier).load();
    final s = c.read(communityControllerProvider);
    expect(s.phase, CommunityPhase.loaded);
    expect(s.posts.map((e) => e.id), [1, 2]);
  });

  test('load 실패: failed + error 메시지', () async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async =>
              throw const ApiException(
                code: ApiErrorCode.network,
                message: '네트워크 오류',
              ),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(communityControllerProvider.notifier).load();
    final s = c.read(communityControllerProvider);
    expect(s.phase, CommunityPhase.failed);
    expect(s.error, '네트워크 오류');
  });

  test('load: board/tag/sort 필터를 데이터 레이어로 전달한다', () async {
    String? seenBoard, seenSort;
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({
          String? board,
          String? tag,
          String? sort,
        }) async {
          seenBoard = board;
          seenSort = sort;
          return const [];
        }),
      ],
    );
    addTearDown(c.dispose);

    await c
        .read(communityControllerProvider.notifier)
        .load(board: 'QNA', sort: 'unanswered');
    expect(seenBoard, 'QNA');
    expect(seenSort, 'unanswered');
  });
}
