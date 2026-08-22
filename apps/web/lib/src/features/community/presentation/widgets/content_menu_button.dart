import 'package:dp_core/dp_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/community_source.dart';
import 'report_dialog.dart';

/// 콘텐츠 종류 — 신고 `targetType` 과 삭제 provider 를 함께 가른다.
enum ContentKind {
  post('POST'),
  answer('ANSWER'),
  comment('COMMENT');

  const ContentKind(this.wire);

  /// 신고 API 의 `targetType` 값.
  final String wire;
}

/// 수정·삭제 공통 에러 문구. 서버 메시지를 그대로 흘리지 않는다 — 이용자는 다음에 뭘 할지
/// 알아야 한다. 스펙 §7 이 정한 문구를 그대로 쓰며, 404 는 신고 경로와 **같은 문자열**이다.
String contentActionMessage(ApiException e) => switch (e.code) {
  ApiErrorCode.forbidden => '내가 쓴 글만 수정할 수 있어요',
  ApiErrorCode.resourceNotFound => '이미 삭제된 콘텐츠예요',
  ApiErrorCode.conflict => '채택된 답변은 채택을 먼저 해제해 주세요',
  ApiErrorCode.validationFailed => '내용을 입력해 주세요',
  _ => '처리하지 못했어요. 잠시 후 다시 시도해 주세요',
};

/// 콘텐츠 옆 `⋮` 메뉴.
///
/// ★한 콘텐츠에 메뉴는 하나다★ — 작성자 여부로 **항목**이 갈린다. 내 것이면 `수정하기`·
/// `삭제하기`, 남의 것이면 `신고하기`. 예전 `ReportMenuButton` 은 내 콘텐츠에서 메뉴를
/// 통째로 감췄으나, 그 자리에 수정·삭제가 들어와야 하므로 그 계약을 바꿨다.
///
/// [authorId] 가 null 이면 **남의 것으로 본다** — AI 초안처럼 작성자가 없는 콘텐츠가 있고,
/// 모르는 것을 내 것으로 취급하면 남의 글에 삭제 버튼이 보인다. 서버 검증이 최종 방어선이다.
class ContentMenuButton extends ConsumerWidget {
  const ContentMenuButton({
    super.key,
    required this.kind,
    required this.targetId,
    required this.authorId,
    required this.currentUserId,
    this.onEdit,
    this.onDeleted,
  });

  final ContentKind kind;
  final int targetId;

  /// 대상 작성자. 모르면 null.
  final int? authorId;

  /// 현재 로그인 사용자 id. `User.id` 가 String 이라 문자열로 맞춰 비교한다.
  final String? currentUserId;

  /// 내 콘텐츠에서 `수정하기` 를 눌렀을 때. null 이면 그 항목을 내지 않는다
  /// (아직 편집 UI 가 없는 자리에서 죽은 메뉴를 보이지 않기 위해서다).
  final VoidCallback? onEdit;

  /// 삭제 성공 뒤. 상세 재조회·목록 복귀 같은 후속은 호출자가 정한다.
  final VoidCallback? onDeleted;

  bool get _isMine =>
      authorId != null &&
      currentUserId != null &&
      authorId.toString() == currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuAnchor(
      // 답변·댓글 헤더 행에 얹히므로 기본 48x48 히트영역은 과하다 — 행 높이를 밀어
      // 올려 주변 레이아웃을 흔든다. 32x32 로 줄이되 터치 최소 크기는 유지한다.
      builder: (context, controller, _) => IconButton(
        key: const ValueKey('content-menu'),
        icon: const Icon(Icons.more_vert, size: 18),
        tooltip: '더보기',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: _isMine
          ? [
              if (onEdit != null)
                MenuItemButton(onPressed: onEdit, child: const Text('수정하기')),
              MenuItemButton(
                onPressed: () => _confirmDelete(context, ref),
                child: const Text('삭제하기'),
              ),
            ]
          : [
              MenuItemButton(
                onPressed: () => _openReportDialog(context, ref),
                child: const Text('신고하기'),
              ),
            ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: const Text('삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            key: const ValueKey('content-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const ValueKey('content-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (kind) {
        case ContentKind.post:
          await ref.read(postDeleteProvider)(targetId);
        case ContentKind.answer:
          await ref.read(answerDeleteProvider)(targetId);
        case ContentKind.comment:
          await ref.read(commentDeleteProvider)(targetId);
      }
      messenger.showSnackBar(const SnackBar(content: Text('삭제했어요')));
      onDeleted?.call();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(contentActionMessage(e))));
    }
  }

  Future<void> _openReportDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<ReportDialogResult>(
      context: context,
      builder: (_) => const ReportDialog(),
    );
    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(communityReportProvider)(
        targetType: kind.wire,
        targetId: targetId,
        category: result.category,
        reason: result.reason,
      );
      messenger.showSnackBar(const SnackBar(content: Text('신고가 접수됐어요')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_reportMessage(e))));
    }
  }

  /// 신고 전용 문구 — 수정·삭제와 상황이 달라 따로 둔다(409 의 뜻이 서로 다르다).
  String _reportMessage(ApiException e) => switch (e.code) {
    ApiErrorCode.conflict => '이미 신고한 콘텐츠예요',
    ApiErrorCode.validationFailed =>
      e.message.contains('본인') ? '본인이 쓴 글은 신고할 수 없어요' : e.message,
    ApiErrorCode.resourceNotFound => '이미 삭제된 콘텐츠예요',
    _ => '신고하지 못했어요. 잠시 후 다시 시도해 주세요',
  };
}
