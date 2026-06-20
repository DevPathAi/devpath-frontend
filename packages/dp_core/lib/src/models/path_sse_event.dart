import 'package:freezed_annotation/freezed_annotation.dart';

part 'path_sse_event.freezed.dart';
part 'path_sse_event.g.dart';

/// 학습경로 생성 SSE 진행 이벤트.
@freezed
abstract class PathSseEvent with _$PathSseEvent {
  const factory PathSseEvent({
    required String stage,
    required double progress,
    required String message,
    int? pathId,
  }) = _PathSseEvent;

  factory PathSseEvent.fromJson(Map<String, dynamic> json) =>
      _$PathSseEventFromJson(json);
}
