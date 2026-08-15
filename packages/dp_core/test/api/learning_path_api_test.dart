import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.status = 204, this.body});

  final int status;
  final Object? body;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final responseBody = body == null ? '' : jsonEncode(body);
    return ResponseBody.fromString(
      responseBody,
      status,
      headers: body == null
          ? const <String, List<String>>{}
          : <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient clientWith(HttpClientAdapter adapter) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://api.test'));
  client.dio.httpClientAdapter = adapter;
  return client;
}

Map<String, Object?> currentPathJson() => <String, Object?>{
  'pathId': 7,
  'track': 'BACKEND_SPRING',
  'totalWeeks': 12,
  'rationale': '진단 근거',
  'milestones': <Object?>[],
};

Map<String, Object?> currentMissionJson() {
  final task = <String, Object?>{
    'taskId': 11,
    'orderNum': 1,
    'taskType': 'READ',
    'title': 'HTTP 요청 흐름 읽기',
    'required': true,
    'contentId': null,
    'contentSlug': null,
    'completed': false,
    'completedAt': null,
  };
  return <String, Object?>{
    'outcome': 'AVAILABLE',
    'pathId': 7,
    'weekNum': 2,
    'tasks': [task],
    'nextTask': task,
    'pathCompleted': false,
  };
}

void main() {
  test('currentPath는 정확한 GET endpoint를 typed model로 읽는다', () async {
    final adapter = _RecordingAdapter(status: 200, body: currentPathJson());
    final api = LearningPathApi(clientWith(adapter));

    final path = await api.currentPath();

    expect(path.pathId, 7);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/learning-paths/me');
    expect(adapter.requests.single.data, isNull);
  });

  test('currentMission은 정확한 GET endpoint와 authoritative model을 쓴다', () async {
    final adapter = _RecordingAdapter(status: 200, body: currentMissionJson());
    final api = LearningPathApi(clientWith(adapter));

    final mission = await api.currentMission();

    expect(mission.outcome, CurrentMissionOutcome.available);
    expect(mission.nextTask!.taskId, 11);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/learning-paths/me/this-week');
    expect(adapter.requests.single.data, isNull);
  });

  test('currentMission은 malformed root 응답도 typed fallback으로 반환한다', () async {
    final adapter = _RecordingAdapter(status: 200, body: <Object?>[]);
    final api = LearningPathApi(clientWith(adapter));

    final mission = await api.currentMission();

    expect(mission.outcome, CurrentMissionOutcome.malformedPath);
  });

  test('completeContentlessTask는 양수 ID만 exact POST/no-body로 보낸다', () async {
    final adapter = _RecordingAdapter();
    final api = LearningPathApi(clientWith(adapter));

    await api.completeContentlessTask(11);

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/learning-paths/tasks/11/complete');
    expect(adapter.requests.single.data, isNull);
  });

  test('completeContentlessTask는 0/음수 ID를 요청 전에 거부한다', () async {
    final adapter = _RecordingAdapter();
    final api = LearningPathApi(clientWith(adapter));

    expect(() => api.completeContentlessTask(0), throwsArgumentError);
    expect(() => api.completeContentlessTask(-1), throwsArgumentError);
    expect(adapter.requests, isEmpty);
  });

  test('204 replay는 두 번 모두 성공하고 body를 만들지 않는다', () async {
    final adapter = _RecordingAdapter();
    final api = LearningPathApi(clientWith(adapter));

    await api.completeContentlessTask(11);
    await api.completeContentlessTask(11);

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.every((request) => request.data == null), isTrue);
  });

  test('completion HTTP error는 ApiException으로 보존한다', () async {
    final adapter = _RecordingAdapter(
      status: 404,
      body: {
        'error': {'code': 'RESOURCE_NOT_FOUND', 'message': '과제를 찾을 수 없습니다.'},
      },
    );
    final api = LearningPathApi(clientWith(adapter));

    expect(
      () => api.completeContentlessTask(11),
      throwsA(
        isA<ApiException>()
            .having((error) => error.status, 'status', 404)
            .having((error) => error.message, 'message', '과제를 찾을 수 없습니다.'),
      ),
    );
  });
}
