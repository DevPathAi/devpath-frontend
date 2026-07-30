import 'package:devpath_web/src/features/community/application/community_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/state/community_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPostSummary _p(int id) =>
    CommunityPostSummary(id: id, title: '글 $id', replyCount: 1);

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

  test('load: sort 필터를 데이터 레이어로 전달한다', () async {
    String? seenSort;
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({
          String? board,
          String? tag,
          String? sort,
        }) async {
          seenSort = sort;
          return const [];
        }),
      ],
    );
    addTearDown(c.dispose);

    await c.read(communityControllerProvider.notifier).load(sort: 'unanswered');
    expect(seenSort, 'unanswered');
  });

  test('selectBoard: 필터를 board 파라미터로 전달하고 재조회', () async {
    String? seenBoard;
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({
          String? board,
          String? tag,
          String? sort,
        }) async {
          seenBoard = board;
          return const [];
        }),
      ],
    );
    addTearDown(c.dispose);

    await c
        .read(communityControllerProvider.notifier)
        .selectBoard(CommunityBoard.free);
    expect(seenBoard, 'FREE');
    expect(c.read(communityControllerProvider).board, CommunityBoard.free);
  });

  test('selectBoard.all: board=null(전체)로 조회', () async {
    String? seenBoard = 'sentinel';
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({
          String? board,
          String? tag,
          String? sort,
        }) async {
          seenBoard = board;
          return const [];
        }),
      ],
    );
    addTearDown(c.dispose);

    await c
        .read(communityControllerProvider.notifier)
        .selectBoard(CommunityBoard.all);
    expect(seenBoard, isNull);
  });
}
