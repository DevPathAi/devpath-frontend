import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 삭제된 답변·댓글 자리. 카드는 남기고 내용만 비운다 — 스레드 맥락(「위 답변처럼」 같은
/// 참조)이 끊기지 않게 하기 위해서다. 작성자·투표·메뉴는 내지 않는다.
///
/// ★답변과 댓글이 같은 위젯을 쓴다★ — 1부에서 목록과 상세 두 읽기 경로에 같은 매핑이
/// 복제돼 한쪽만 고치면 어긋나는 문제를 겪었으므로 처음부터 한 곳에 둔다.
class ContentTombstone extends StatelessWidget {
  const ContentTombstone({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.md),
        child: Text(
          '삭제된 내용입니다',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).disabledColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
