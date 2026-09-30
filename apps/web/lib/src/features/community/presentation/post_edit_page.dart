import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/post_detail_controller.dart';
import '../state/post_detail_state.dart';
import '../../support/presentation/supportable_error.dart';
import 'post_create_page.dart';

/// 글 편집 진입점 — 상세를 먼저 불러 초기값을 확정한 뒤 작성 화면을 편집 모드로 띄운다.
///
/// 작성 화면이 `initState` 에서 에디터 문서를 만들기 때문에 초기 본문이 그 시점에 있어야
/// 한다. 그래서 로딩을 이 얇은 껍데기가 맡는다.
class PostEditPage extends ConsumerStatefulWidget {
  const PostEditPage({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<PostEditPage> createState() => _PostEditPageState();
}

class _PostEditPageState extends ConsumerState<PostEditPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          ref.read(postDetailControllerProvider(widget.postId).notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(postDetailControllerProvider(widget.postId));
    final detail = s.detail;
    return switch (s.phase) {
      PostDetailPhase.loaded when detail != null => PostCreatePage(
        board: detail.boardType,
        editPostId: detail.id,
        initialTitle: detail.title,
        initialBodyMd: detail.bodyMd,
      ),
      // 웹 셸에는 AppBar 가 없다 — 화면 제목은 `DpPageHeader` 가 맡고, 오류는
      // 레포 표준 `SupportableError`(문의 연결·재시도)를 쓴다. 이 두 파일이
      // 앱 전체에서 유일하게 `AppBar` 를 쓰고 있었다.
      PostDetailPhase.failed => Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DpPageHeader(title: '글 수정'),
            Expanded(
              child: SupportableError(
                message: s.error ?? '불러오지 못했어요',
                onRetry: () => ref
                    .read(postDetailControllerProvider(widget.postId).notifier)
                    .load(),
              ),
            ),
          ],
        ),
      ),
      _ => const Scaffold(body: DpLoading(label: '글을 불러오는 중')),
    };
  }
}
