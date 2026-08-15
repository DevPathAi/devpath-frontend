import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 질문을 보내 SSE 이벤트를 흘리는 함수(슬라이스 #7 M-2 계약).
///
/// 와이어 body는 `{message, contentId?}`(빌드 D ai-svc). [contentId]는 옵셔널 —
/// 현재 콘텐츠 식별자가 있으면 전달, 없으면 null(독립 멘토 페이지는 null).
///
/// [fromStep](끊김 후 재개 시 이미 받은 토큰 수)은 **wire에서 제거**되었으나,
/// 시그니처 자리는 보존한다(I-3) — 백엔드가 `Last-Event-ID`/토큰 재개를 합의하면
/// 여기로 흘려보낸다(추측 금지, 자리만 둠; 현재 재개는 resend).
typedef MentorSseConnect =
    Stream<SseEvent> Function(
      String question, {
      String? contentId,
      int fromStep,
    });

/// Canonical Mission Mentor wire. The only supplemental-context value crossing
/// into ai-svc is the immutable LCS snapshot identifier.
typedef MentorContextualSseConnect =
    Stream<SseEvent> Function(
      String question, {
      String? contentId,
      int? contextSnapshotId,
      int fromStep,
    });

enum MentorTerminalStatus { done, failed }

final class MentorTerminal {
  const MentorTerminal({required this.status, this.code, this.message});

  final MentorTerminalStatus status;
  final String? code;
  final String? message;
}

/// Parses the explicit Mentor completion frame. Only `DONE` is successful;
/// malformed or additive future statuses fail closed without throwing.
MentorTerminal? parseMentorTerminal(SseEvent event) {
  if (event.event != 'terminal') return null;
  try {
    final decoded = jsonDecode(event.data);
    if (decoded is! Map) return _malformedTerminal;
    final data = decoded.cast<String, Object?>();
    final status = data['status'];
    if (status == 'DONE') {
      return const MentorTerminal(status: MentorTerminalStatus.done);
    }
    if (status == 'FAILED') {
      return MentorTerminal(
        status: MentorTerminalStatus.failed,
        code: data['code'] is String ? data['code']! as String : null,
        message: data['message'] is String ? data['message']! as String : null,
      );
    }
  } on Object {
    return _malformedTerminal;
  }
  return _malformedTerminal;
}

const _malformedTerminal = MentorTerminal(
  status: MentorTerminalStatus.failed,
  code: 'MALFORMED_TERMINAL',
);

const List<String> _kMockAnswer = [
  '비동기는 ',
  '`Future`와 ',
  '`async`/`await`로 ',
  '다룹니다. ',
  '스트림은 `Stream`을 구독하세요.',
];

/// 위젯/단위 테스트용 고정 참고자료(M-2 `event:references` 형태).
const List<Map<String, dynamic>> _kMockReferences = [
  {
    'contentId': 101,
    'slug': 'async-await-basics',
    'title': '비동기 기초: async/await',
  },
  {'contentId': 102, 'slug': 'dart-streams', 'title': 'Dart Stream 다루기'},
];

final mentorSseConnectProvider = Provider<MentorSseConnect>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return (question, {String? contentId, int fromStep = 0}) async* {
      for (final t in _kMockAnswer.sublist(
        fromStep.clamp(0, _kMockAnswer.length),
      )) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        yield SseEvent(event: 'token', data: t);
      }
      // 토큰 후 참고자료 1회(실서버 event:references 미러).
      yield SseEvent(event: 'references', data: jsonEncode(_kMockReferences));
      yield const SseEvent(event: 'terminal', data: '{"status":"DONE"}');
    };
  }
  // ENG-REVIEW D1: `client.dio`를 직접 만지지 않는다 — `SseClient(client.dio)` 직접
  // 인스턴스화 금지. P2 `apiClient.sse(path, {body})` 헬퍼만 경유한다.
  final apiClient = ref.watch(apiClientProvider);
  return (question, {String? contentId, int fromStep = 0}) => apiClient.sse(
    '/ai-mentor/sessions',
    body: {'message': question, 'contentId': contentId},
  );
});

final mentorContextualSseConnectProvider = Provider<MentorContextualSseConnect>(
  (ref) {
    final config = ref.watch(appConfigProvider);
    if (config.useMock) {
      return (
        question, {
        String? contentId,
        int? contextSnapshotId,
        int fromStep = 0,
      }) async* {
        for (final t in _kMockAnswer.sublist(
          fromStep.clamp(0, _kMockAnswer.length),
        )) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          yield SseEvent(event: 'token', data: t);
        }
        yield SseEvent(event: 'references', data: jsonEncode(_kMockReferences));
        yield const SseEvent(event: 'terminal', data: '{"status":"DONE"}');
      };
    }
    final apiClient = ref.watch(apiClientProvider);
    return (
      question, {
      String? contentId,
      int? contextSnapshotId,
      int fromStep = 0,
    }) {
      if (contextSnapshotId != null &&
          (contextSnapshotId <= 0 || contextSnapshotId > 9007199254740991)) {
        return Stream<SseEvent>.error(
          const FormatException('Malformed Mentor snapshot ID'),
        );
      }
      return apiClient.sse(
        '/ai-mentor/sessions',
        body: {
          'message': question,
          'contentId': contentId,
          'contextSnapshotId': contextSnapshotId,
        },
      );
    };
  },
);
