import 'package:devpath_web/src/features/community/application/post_detail_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/state/post_detail_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 작성 → 수정 → 삭제 → 상세 404 → 재삭제 404 를 한 줄기로 통과시킨다.
///
/// ★단위 테스트만 보고 통합 흐름을 놓친 전례가 있어(진단 트랙 선택 때 골든패스 5곳)
/// 스펙 §8 이 이 테스트를 못박았다.★
///
/// 픽스처 상수로는 「삭제한 뒤에는 404」 같은 **상태 전이**를 표현할 수 없어 작은 가짜
/// 저장소를 두고 provider 를 그 위에 얹는다.
void main() {
  test('골든패스: 작성 → 수정 → 삭제 → 상세 404 → 재삭제 404', () async {
    CommunityPostDetail? stored;
    var deleted = false;

    ApiException gone() => const ApiException(
      code: ApiErrorCode.resourceNotFound,
      message: 'gone',
    );

    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(({
          required boardType,
          required title,
          required bodyMd,
          required tags,
        }) async {
          stored = CommunityPostDetail(
            id: 9,
            boardType: boardType,
            title: title,
            bodyMd: bodyMd,
            authorId: 1,
          );
          return stored!;
        }),
        postUpdateProvider.overrideWithValue(({
          required id,
          required title,
          required bodyMd,
        }) async {
          if (deleted) throw gone();
          stored = stored!.copyWith(title: title, bodyMd: bodyMd);
          return stored!;
        }),
        postDeleteProvider.overrideWithValue((id) async {
          if (deleted) throw gone();
          deleted = true;
        }),
        postDetailFetchProvider.overrideWithValue((id) async {
          if (deleted) throw gone();
          return stored!;
        }),
      ],
    );
    addTearDown(c.dispose);

    // 1) 작성
    final created = await c.read(postCreateProvider)(
      boardType: 'FREE',
      title: '원제목',
      bodyMd: '원본문',
      tags: const [],
    );
    expect(created.title, '원제목');

    // 2) 수정 — 상세에 반영된다
    await c.read(postUpdateProvider)(id: 9, title: '새제목', bodyMd: '새본문');
    final n = c.read(postDetailControllerProvider(9).notifier);
    await n.load();
    expect(c.read(postDetailControllerProvider(9)).detail?.title, '새제목');

    // 3) 삭제
    await c.read(postDeleteProvider)(9);

    // 4) 상세는 404 — 컨트롤러가 failed 로 떨어진다
    await n.load();
    expect(
      c.read(postDetailControllerProvider(9)).phase,
      PostDetailPhase.failed,
    );

    // 5) 재삭제도 404 — 프론트가 「이미 삭제된 콘텐츠예요」로 렌더하는 그 코드다
    await expectLater(
      c.read(postDeleteProvider)(9),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.resourceNotFound,
        ),
      ),
    );

    // 6) 삭제된 것을 고치려 해도 404 — 편집 화면이 그 코드로 안내한다
    await expectLater(
      c.read(postUpdateProvider)(id: 9, title: 'x', bodyMd: 'y'),
      throwsA(isA<ApiException>()),
    );
  });
}
