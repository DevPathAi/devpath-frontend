import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/post_detail_controller.dart';
import '../state/post_detail_state.dart';
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
      PostDetailPhase.failed => Scaffold(
        appBar: AppBar(title: const Text('글 수정')),
        body: Center(child: Text(s.error ?? '불러오지 못했어요')),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
