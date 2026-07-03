import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/data/web_mock_fixtures.dart'
    show mockLearningPath;
import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/path/application/path_controller.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart'
    show kPathStageLabels;
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// path SSE 실계약 회귀. 백엔드 learning-svc `LearningPathController`:
/// `POST /me/generate`(text/event-stream) → `SseEmitter.event().name("progress")
/// .data(PathProgressEvent)` → `emitter.complete()`. `PathProgressEvent(stage,
/// progress, message, pathId)`. stage='done'이면 프론트가 `GET /learning-paths/me`로
/// 결과 조회. **실 분기(useMock=false)를 dio stream mock으로 구동** — 목 소스 우회.
class _PathRealApiAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (options.path.contains('/generate')) {
      // 백엔드가 실제로 흘리는 wire: event: progress\n data: <PathProgressEvent json>\n\n
      const chunks = [
        'event: progress\n'
            'data: {"stage":"collecting","progress":0.1,"message":"진단 분석","pathId":null}\n\n',
        'event: progress\n'
            'data: {"stage":"generating","progress":0.5,"message":"경로 생성","pathId":null}\n\n',
        'event: progress\n'
            'data: {"stage":"matching","progress":0.8,"message":"콘텐츠 매칭","pathId":null}\n\n',
        'event: progress\n'
            'data: {"stage":"done","progress":1.0,"message":"완료","pathId":7}\n\n',
      ];
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
    // GET /learning-paths/me → 완료된 경로(스펙 §3 비동기 결과 조회).
    return ResponseBody.fromString(
      jsonEncode(mockLearningPath()),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container() {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = _PathRealApiAdapter();
  return ProviderContainer(
    overrides: [
      // 실 분기 강제(목 소스 우회) + mock 어댑터 주입.
      appConfigProvider.overrideWithValue(
        const AppConfig(baseUrl: 'https://t/api/v1', useMock: false),
      ),
      apiClientProvider.overrideWithValue(client),
    ],
  );
}

void main() {
  test('실계약 progress 스트림(done)→GET 조회→PathPhase.complete', () async {
    final container = _container();
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.complete);
    expect(s.result, isNotNull);
    // 3개 사용자 단계 라벨이 모두 완료로 표시(kPathStageLabels).
    expect(s.completed, kPathStageLabels);
  });
}
