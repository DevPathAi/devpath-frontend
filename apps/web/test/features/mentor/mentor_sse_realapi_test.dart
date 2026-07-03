import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/mentor/application/mentor_controller.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// mentor SSE 실계약 회귀. 백엔드 ai-svc `MentorService`:
/// `name("references").data(json)` → `name("token").data(t)`×N → `complete()`.
/// 프론트: references→state.references, token→멘토 버블 누적, onDone→idle.
/// **실 분기(useMock=false)를 dio stream mock으로 구동** — 목 소스 우회.
class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this.chunks);
  final List<String> chunks;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream.fromIterable(
        chunks.map((c) => Uint8List.fromList(utf8.encode(c))),
      ),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container(List<String> chunks) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = _SseAdapter(chunks);
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(baseUrl: 'https://t/api/v1', useMock: false),
      ),
      apiClientProvider.overrideWithValue(client),
    ],
  );
}

void main() {
  test('실계약 references+token 스트림 → 버블 누적 + 참고자료 반영', () async {
    final container = _container(const [
      'event: references\n'
          'data: [{"contentId":101,"slug":"async-await-basics","title":"비동기 기초"}]\n\n',
      'event: token\ndata: 비동기는\n\n',
      'event: token\ndata: 간단합니다\n\n',
    ]);
    addTearDown(container.dispose);

    await container.read(mentorControllerProvider.notifier).send('비동기가 뭐야?');

    final s = container.read(mentorControllerProvider);
    // 사용자 질문 + 멘토 답변 버블.
    expect(s.messages.length, 2);
    expect(s.messages.first.fromUser, isTrue);
    expect(s.messages.last.fromUser, isFalse);
    // token 누적(SseClient가 data를 trim → 공백 없는 토큰으로 검증).
    expect(s.messages.last.text, '비동기는간단합니다');
    // references 이벤트 반영.
    expect(s.references.length, 1);
    expect(s.status, MentorStatus.idle);
  });
}
