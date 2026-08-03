import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import 'support_dialog.dart';

/// [DpError] + 제보 진입점.
///
/// web 의 오류 화면은 전부 이 위젯을 쓴다 — 화면마다 onReport 를 손으로 넘기면
/// 문구·traceId 전달이 갈라진다. admin 은 쓰지 않는다(관리자는 처리자다).
class SupportableError extends StatelessWidget {
  const SupportableError({
    super.key,
    required this.message,
    this.onRetry,
    this.title = '문제가 발생했어요',
    this.traceId,
    this.errorCode,
  });

  final String message;
  final VoidCallback? onRetry;
  final String title;

  /// 서버는 현재 trace_id 를 항상 null 로 보낸다(분산 트레이싱 미도입) — 배관만 있다.
  final String? traceId;
  final String? errorCode;

  @override
  Widget build(BuildContext context) => DpError(
    title: title,
    message: message,
    onRetry: onRetry,
    onReport: () =>
        showSupportDialog(context, traceId: traceId, errorCode: errorCode),
  );
}
