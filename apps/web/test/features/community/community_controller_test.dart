import 'package:devpath_web/src/features/community/application/community_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/state/community_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPost _p(String id) =>
    CommunityPost(id: id, title: '글 $id', author: '지수');

void main() {
  test('첫 로드 후 loadMore가 다음 페이지를 누적한다', () async {
    final c = ProviderContainer(
      overrides: [
        communityFetchProvider.overrideWithValue(({String? cursor}) async {
          if (cursor == null) {
            return Page(data: [_p('1'), _p('2')], nextCursor: 'c2', limit: 20);
          }
          return Page(data: [_p('3')], limit: 20); // nextCursor 없음 → 끝
        }),
      ],
    );
    addTearDown(c.dispose);

    await c.read(communityControllerProvider.notifier).load();
    var s = c.read(communityControllerProvider);
    expect(s.phase, CommunityPhase.loaded);
    expect(s.posts.map((e) => e.id), ['1', '2']);
    expect(s.nextCursor, 'c2');

    await c.read(communityControllerProvider.notifier).loadMore();
    s = c.read(communityControllerProvider);
    expect(s.posts.map((e) => e.id), ['1', '2', '3']);
    expect(s.nextCursor, isNull); // 더 없음
  });

  // 🔶 ENG-REVIEW(P2): copyWith의 nextCursor는 명시 대입(L496) — 비대칭 고정.
  // 인자를 안 주면 기존값 유지가 아니라 null이 됨을 회귀 방지로 고정한다.
  test('copyWith: nextCursor를 생략하면 null로 떨어진다(명시 대입 비대칭)', () {
    const s = CommunityState(
      posts: [],
      nextCursor: 'c2',
      phase: CommunityPhase.loaded,
    );
    final next = s.copyWith(loadingMore: true); // nextCursor 미전달
    expect(next.nextCursor, isNull); // ?? this.nextCursor가 아님 — 명시 대입
    final kept = s.copyWith(nextCursor: 'c2'); // 명시해야 유지
    expect(kept.nextCursor, 'c2');
  });
}
