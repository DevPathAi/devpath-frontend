import 'package:dp_core/dp_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/community_source.dart';
import 'report_dialog.dart';

/// 콘텐츠 옆 `⋮` 메뉴 — 지금은 신고 하나뿐이다.
///
/// [authorId] 가 현재 사용자와 같으면 메뉴를 감춘다. **[authorId] 가 null 이면 감추지
/// 않는다** — QNA 질문 상세 응답(`QuestionDetailView`)에는 작성자 id 가 없다는 기존 계약
/// 때문이다. 그 경우 서버가 400 으로 막고 여기서 전용 문구로 안내한다. UI 미노출은
/// 편의일 뿐이고 **서버 검증이 최종 방어선**이다.
class ReportMenuButton extends ConsumerWidget {
  const ReportMenuButton({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.authorId,
    required this.currentUserId,
  });

  /// `POST` | `ANSWER` | `COMMENT`.
  final String targetType;
  final int targetId;

  /// 대상 작성자. 모르면 null.
  final int? authorId;

  /// 현재 로그인 사용자 id. `User.id` 가 String 이라 문자열로 맞춰 비교한다.
  final String? currentUserId;

  bool get _isMine =>
      authorId != null &&
      currentUserId != null &&
      authorId.toString() == currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isMine) return const SizedBox.shrink();
    return MenuAnchor(
      // 답변·댓글 헤더 행에 얹히므로 기본 48x48 히트영역은 과하다 — 행 높이를 밀어
      // 올려 주변 레이아웃을 흔든다. 32x32 로 줄이되 터치 최소 크기는 유지한다.
      builder: (context, controller, _) => IconButton(
        key: const ValueKey('report-menu'),
        icon: const Icon(Icons.more_vert, size: 18),
        tooltip: '더보기',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => _openDialog(context, ref),
          child: const Text('신고하기'),
        ),
      ],
    );
  }

  Future<void> _openDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<ReportDialogResult>(
      context: context,
      builder: (_) => const ReportDialog(),
    );
    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(communityReportProvider)(
        targetType: targetType,
        targetId: targetId,
        category: result.category,
        reason: result.reason,
      );
      messenger.showSnackBar(const SnackBar(content: Text('신고가 접수됐어요')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_messageFor(e))));
    }
  }

  /// 서버 메시지를 그대로 흘리지 않고 상황별 문구를 준다 — 사용자가 다음에 뭘 할지 알아야 한다.
  String _messageFor(ApiException e) => switch (e.code) {
    ApiErrorCode.conflict => '이미 신고한 콘텐츠예요',
    ApiErrorCode.validationFailed =>
      e.message.contains('본인') ? '본인이 쓴 글은 신고할 수 없어요' : e.message,
    ApiErrorCode.resourceNotFound => '이미 삭제된 콘텐츠예요',
    _ => '신고하지 못했어요. 잠시 후 다시 시도해 주세요',
  };
}
