import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/community_source.dart';

/// 시안 `detail` 의 `.side` 「관련 질문」.
///
/// 작성 화면이 이미 쓰는 `similarQuestionsProvider`(`GET
/// /community/questions/similar?q=`)를 질문 제목으로 부른다 — 새 엔드포인트가
/// 아니다. 대가는 질문 상세를 열 때 요청이 하나 늘어나는 것이고, 보조 정보이므로
/// **실패하면 조용히 사라진다**(본문 읽기를 막지 않는다).
class QnaRelatedPanel extends ConsumerStatefulWidget {
  const QnaRelatedPanel({
    super.key,
    required this.questionId,
    required this.title,
  });

  final int questionId;
  final String title;

  @override
  ConsumerState<QnaRelatedPanel> createState() => _QnaRelatedPanelState();
}

class _QnaRelatedPanelState extends ConsumerState<QnaRelatedPanel> {
  List<SimilarQuestion> _items = const [];

  @override
  void initState() {
    super.initState();
    // build 중에 provider 를 읽어 상태를 바꾸지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant QnaRelatedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionId != widget.questionId) {
      // 다른 질문으로 넘어가면 앞 질문의 관련 목록이 남아 있으면 안 된다.
      setState(() => _items = const []);
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final results = await ref.read(similarQuestionsProvider)(widget.title);
      if (!mounted) return;
      setState(() {
        _items = results
            .where((item) => item.questionId != widget.questionId)
            .toList(growable: false);
      });
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return DpPanel(
      title: const DpPanelTitle('관련 질문'),
      child: DpListLines(
        children: [
          for (final item in _items)
            DpLink.inline(
              text: item.title,
              onTap: () => context.go('/community/${item.questionId}'),
            ),
        ],
      ),
    );
  }
}
