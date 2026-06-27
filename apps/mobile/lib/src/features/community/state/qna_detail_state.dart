import 'package:dp_core/dp_core.dart';

/// Q&A 상세 상태. 액션(답변·채택·투표)은 [QnaLoaded] 위에서 진행 상태/오류를 표면화.
sealed class QnaDetailState {
  const QnaDetailState();
}

class QnaLoading extends QnaDetailState {
  const QnaLoading();
}

class QnaLoaded extends QnaDetailState {
  const QnaLoaded(this.detail, {this.submitting = false, this.actionError});

  final CommunityQuestionDetail detail;

  /// 답변 작성·채택·투표 진행 중(버튼 비활성).
  final bool submitting;

  /// 직전 액션 실패 메시지(예: 비작성자 채택 403). 상세는 유지한 채 표면화.
  final String? actionError;

  QnaLoaded copyWith({
    CommunityQuestionDetail? detail,
    bool? submitting,
    String? actionError,
  }) => QnaLoaded(
    detail ?? this.detail,
    submitting: submitting ?? this.submitting,
    actionError: actionError,
  );
}

class QnaFailed extends QnaDetailState {
  const QnaFailed(this.message);
  final String message;
}
