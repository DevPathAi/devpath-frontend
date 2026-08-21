import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/qna_detail_controller.dart';
import '../state/qna_detail_state.dart';
import 'question_create_page.dart';

/// 질문 편집 진입점 — 상세를 먼저 불러 초기값을 확정한 뒤 작성 화면을 편집 모드로 띄운다.
///
/// 작성 화면이 `initState` 에서 에디터 문서를 만들기 때문에 초기 본문이 그 시점에 있어야
/// 한다. 그래서 로딩을 이 얇은 껍데기가 맡는다.
///
/// `qnaDetailControllerProvider` 는 family 가 아니라 단일 프로바이더이고 `load(id)` 가
/// 대상을 받는다 — 상세 화면과 같은 인스턴스를 공유하지만 둘 다 같은 질문을 보므로 무방하다.
class QuestionEditPage extends ConsumerStatefulWidget {
  const QuestionEditPage({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<QuestionEditPage> createState() => _QuestionEditPageState();
}

class _QuestionEditPageState extends ConsumerState<QuestionEditPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(qnaDetailControllerProvider.notifier).load(widget.postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (ref.watch(qnaDetailControllerProvider)) {
      QnaLoaded(:final detail) => QuestionCreatePage(
        editPostId: detail.id,
        initialTitle: detail.title,
        initialBodyMd: detail.bodyMd,
      ),
      QnaFailed(:final message) => Scaffold(
        appBar: AppBar(title: const Text('질문 수정')),
        body: Center(child: Text(message)),
      ),
      QnaLoading() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}
