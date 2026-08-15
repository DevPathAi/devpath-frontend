import 'package:dp_core/dp_core.dart';

/// 멘토 스트리밍 상태. ENG-REVIEW D1: P2 `SseStage`
/// (connecting/streaming/partial/reconnecting/complete/failed)를 단일 출처로 두고
/// 멘토가 **구독·매핑**한다 — 여기 enum은 그 평행정의를 최소화한 멘토 뷰 모델이며,
/// `partial`은 P4b `PathPhase.partial`과 동일 의미(끊김 시 부분답변 보존 + 재전송 가능).
enum MentorStatus { idle, streaming, partial, busy, killSwitch, failed }

enum MentorContextPhase {
  selecting,
  loadingPreview,
  previewReady,
  committing,
  failed,
}

final class MentorContextEvidence {
  const MentorContextEvidence({this.currentCode, this.session, this.review});

  final String? currentCode;
  final SandboxSession? session;
  final CodeReview? review;
}

final class MentorContextOption {
  const MentorContextOption({
    required this.id,
    required this.available,
    required this.selected,
    this.unavailableReason,
  });

  final String id;
  final bool available;
  final bool selected;
  final String? unavailableReason;

  MentorContextOption copyWith({bool? selected}) => MentorContextOption(
    id: id,
    available: available,
    selected: selected ?? this.selected,
    unavailableReason: unavailableReason,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.contextFields = const [],
  });
  final bool fromUser;
  final String text;
  final List<String> contextFields;
  ChatMessage append(String s) => ChatMessage(
    fromUser: fromUser,
    text: text + s,
    contextFields: contextFields,
  );
}

/// 참고자료 링크(슬라이스 #7 M-2 `event:references`). ai-svc가 질문 임베딩 →
/// learning 유사검색으로 내려주는 top-K 콘텐츠. mentor feature 내 plain 모델
/// (state 타입과 co-locate; dp_core 모델은 freezed 기반이라 패턴 분리).
class MentorReference {
  const MentorReference({
    required this.contentId,
    required this.slug,
    required this.title,
  });

  final int contentId;
  final String slug;
  final String title;

  factory MentorReference.fromJson(Map<String, dynamic> json) =>
      MentorReference(
        contentId: (json['contentId'] as num).toInt(),
        slug: json['slug'] as String,
        title: json['title'] as String,
      );
}

class MentorState {
  const MentorState({
    this.messages = const [],
    this.status = MentorStatus.idle,
    this.error,
    this.references = const [],
    this.contextOptions = const [],
    this.contextPhase = MentorContextPhase.selecting,
    this.contextPreview,
    this.contextError,
    this.previewQuestion,
    this.committedSnapshotId,
  });
  final List<ChatMessage> messages;
  final MentorStatus status;
  final String? error;

  /// `event:references`(1회) 결과. 도착 전/없으면 빈 리스트.
  final List<MentorReference> references;

  final List<MentorContextOption> contextOptions;
  final MentorContextPhase contextPhase;
  final LcsDraft? contextPreview;
  final String? contextError;
  final String? previewQuestion;
  final int? committedSnapshotId;

  Set<String> get selectedContextFields => contextOptions
      .where((option) => option.selected)
      .map((option) => option.id)
      .toSet();

  MentorState copyWith({
    List<ChatMessage>? messages,
    MentorStatus? status,
    Object? error = _notProvided,
    List<MentorReference>? references,
    List<MentorContextOption>? contextOptions,
    MentorContextPhase? contextPhase,
    Object? contextPreview = _notProvided,
    Object? contextError = _notProvided,
    Object? previewQuestion = _notProvided,
    Object? committedSnapshotId = _notProvided,
  }) => MentorState(
    messages: messages ?? this.messages,
    status: status ?? this.status,
    error: identical(error, _notProvided) ? this.error : error as String?,
    references: references ?? this.references,
    contextOptions: contextOptions ?? this.contextOptions,
    contextPhase: contextPhase ?? this.contextPhase,
    contextPreview: identical(contextPreview, _notProvided)
        ? this.contextPreview
        : contextPreview as LcsDraft?,
    contextError: identical(contextError, _notProvided)
        ? this.contextError
        : contextError as String?,
    previewQuestion: identical(previewQuestion, _notProvided)
        ? this.previewQuestion
        : previewQuestion as String?,
    committedSnapshotId: identical(committedSnapshotId, _notProvided)
        ? this.committedSnapshotId
        : committedSnapshotId as int?,
  );
}

const _notProvided = Object();
