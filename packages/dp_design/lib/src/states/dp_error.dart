import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import 'dp_state_scaffold.dart';

/// 오류 상태. [onReport] 를 주면 [다시 시도] 아래에 [문의하기] 가 붙는다.
///
/// 이 한 파라미터로 DpError 를 쓰는 모든 화면이 제보 진입점을 얻는다
/// (기획 06_화면_기능_정의서:798 의 `[다시 시도] [문의하기]` 조합).
class DpError extends StatelessWidget {
  const DpError({
    super.key,
    required this.message,
    this.onRetry,
    this.onReport,
    this.title = '문제가 발생했어요',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  /// null 이면 보조 버튼이 렌더되지 않는다 — 기존 호출부는 무변경이다.
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) => DpStateScaffold(
    icon: DpIcons.error,
    iconColor: context.dpColors.danger,
    title: title,
    message: message,
    actionLabel: onRetry == null ? null : '다시 시도',
    onAction: onRetry,
    secondaryActionLabel: onReport == null ? null : '문의하기',
    onSecondaryAction: onReport,
  );
}
