import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/content/application/mission_content_controller.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _keyA = MissionWorkspaceKey(taskId: 31, contentId: 3);
const _keyB = MissionWorkspaceKey(taskId: 32, contentId: 4);
const _keyC = MissionWorkspaceKey(taskId: 33, contentId: 5);

void main() {
  test('task/content key별 문서 상태를 독립적으로 보존한다', () async {
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(200, _contentJson(id: 3, title: '문서 A'))],
      'GET /contents/4': [_response(200, _contentJson(id: 4, title: '문서 B'))],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);

    await Future.wait([
      container.read(missionContentControllerProvider(_keyA).notifier).load(),
      container.read(missionContentControllerProvider(_keyB).notifier).load(),
    ]);

    expect(
      container.read(missionContentControllerProvider(_keyA)).content?.title,
      '문서 A',
    );
    expect(
      container.read(missionContentControllerProvider(_keyB)).content?.title,
      '문서 B',
    );
  });

  test('같은 key의 늦은 이전 load 응답은 최신 문서를 덮지 않는다', () async {
    final first = Completer<ResponseBody>();
    final adapter = _QueueAdapter({
      'GET /contents/3': [
        first.future,
        _response(200, _contentJson(id: 3, title: '최신 문서')),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );

    final oldLoad = controller.load();
    final newLoad = controller.load(force: true);
    await newLoad;
    first.complete(_json(200, _contentJson(id: 3, title: '오래된 문서')));
    await oldLoad;

    expect(
      container.read(missionContentControllerProvider(_keyA)).content?.title,
      '최신 문서',
    );
  });

  test('응답 contentId가 URL key와 다르면 문서를 노출하지 않는다', () async {
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(200, _contentJson(id: 99, title: '다른 문서'))],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);

    await container
        .read(missionContentControllerProvider(_keyA).notifier)
        .load();

    final state = container.read(missionContentControllerProvider(_keyA));
    expect(state.content, isNull);
    expect(state.failureMessage, '미션과 콘텐츠 연결을 확인하지 못했어요.');
  });

  test('progress 실패는 문서를 보존하고 성공 retry에서 오류를 지운다', () async {
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(200, _contentJson(id: 3, title: '문서 A'))],
      'POST /contents/3/progress': [
        _response(500, {
          'error': {'code': 'INTERNAL_ERROR', 'message': '저장 지연'},
        }),
        _response(200, _progressJson(completed: false)),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();

    expect(
      await controller.reportProgress(scrollPct: 0.5, dwellSec: 10),
      isNull,
    );
    var state = container.read(missionContentControllerProvider(_keyA));
    expect(state.content?.title, '문서 A');
    expect(state.progressFailureMessage, '저장 지연');

    await controller.reportProgress(scrollPct: 0.5, dwellSec: 10);
    state = container.read(missionContentControllerProvider(_keyA));
    expect(state.content?.title, '문서 A');
    expect(state.progressFailureMessage, isNull);
  });

  test('false→true 완료 전이만 authoritative Today를 한 번 갱신한다', () async {
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(200, _contentJson(id: 3, title: '문서 A'))],
      'POST /contents/3/progress': [
        _response(200, _progressJson(completed: true)),
        _response(200, _progressJson(completed: true)),
      ],
      'GET /learning-paths/me/this-week': [
        _response(200, _availableMissionJson()),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();

    await controller.reportProgress(scrollPct: 0.9, dwellSec: 46);
    await Future<void>.delayed(Duration.zero);
    await controller.reportProgress(scrollPct: 0.9, dwellSec: 46);
    await Future<void>.delayed(Duration.zero);

    expect(adapter.count('GET /learning-paths/me/this-week'), 1);
  });

  test('낮은 progress 요청 중 도달한 완료 payload를 병합해 뒤이어 전송한다', () async {
    final firstResponse = Completer<ResponseBody>();
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(200, _contentJson(id: 3, title: '문서 A'))],
      'POST /contents/3/progress': [
        firstResponse.future,
        _response(200, _progressJson(completed: true)),
      ],
      'GET /learning-paths/me/this-week': [
        _response(200, _availableMissionJson()),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();

    final low = controller.reportProgress(scrollPct: 0.3, dwellSec: 10);
    final completed = controller.reportProgress(scrollPct: 0.9, dwellSec: 46);
    firstResponse.complete(_json(200, _progressJson(completed: false)));
    await Future.wait([low, completed]);
    await _waitForCount(adapter, 'GET /learning-paths/me/this-week', 1);

    expect(adapter.count('POST /contents/3/progress'), 2);
    expect(adapter.bodies('POST /contents/3/progress'), [
      {'scrollPct': 0.3, 'dwellSec': 10},
      {'scrollPct': 0.9, 'dwellSec': 46},
    ]);
    expect(adapter.count('GET /learning-paths/me/this-week'), 1);
  });

  test('progress 완료 응답 전 LRU 대상이 되어도 Today 갱신 후 폐기한다', () async {
    final completion = Completer<ResponseBody>();
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(200, _contentJson(id: 3, title: '문서 A'))],
      'POST /contents/3/progress': [completion.future],
      'GET /learning-paths/me/this-week': [
        _response(200, _availableMissionJson()),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final subscription = container.listen(
      missionContentControllerProvider(_keyA),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final retention = container.read(missionContentRetentionProvider.notifier);
    retention.touch(_keyA);
    retention.touch(_keyB);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();

    final write = controller.reportProgress(scrollPct: 0.9, dwellSec: 46);
    retention.touch(_keyC);
    completion.complete(_json(200, _progressJson(completed: true)));
    expect(await write, isNotNull);
    await _waitForCount(adapter, 'GET /learning-paths/me/this-week', 1);

    expect(adapter.count('GET /learning-paths/me/this-week'), 1);
    expect(container.read(missionContentRetentionProvider), [_keyB, _keyC]);
  });

  test('LRU 대상의 progress 실패 payload는 retry 성공 후에만 폐기한다', () async {
    final firstResponse = Completer<ResponseBody>();
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(200, _contentJson(id: 3, title: '문서 A'))],
      'POST /contents/3/progress': [
        firstResponse.future,
        _response(200, _progressJson(completed: false)),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final subscription = container.listen(
      missionContentControllerProvider(_keyA),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final retention = container.read(missionContentRetentionProvider.notifier);
    retention.touch(_keyA);
    retention.touch(_keyB);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();

    final scrollHeavy = controller.reportProgress(scrollPct: 0.9, dwellSec: 10);
    final disposeFlush = controller.reportProgress(
      scrollPct: 0.2,
      dwellSec: 46,
    );
    retention.touch(_keyC);
    firstResponse.complete(
      _json(500, {
        'error': {'code': 'INTERNAL_ERROR', 'message': '저장 지연'},
      }),
    );
    await Future.wait([scrollHeavy, disposeFlush]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(missionContentRetentionProvider), [_keyB, _keyC]);
    expect(
      container.read(missionContentControllerProvider(_keyA).notifier),
      same(controller),
    );
    expect(controller.hasPendingProgress, isTrue);

    expect(await controller.retryProgress(), isNotNull);
    expect(adapter.bodies('POST /contents/3/progress'), [
      {'scrollPct': 0.9, 'dwellSec': 10},
      {'scrollPct': 0.9, 'dwellSec': 46},
    ]);
    await container.pump();

    expect(
      container.read(missionContentControllerProvider(_keyA)).content,
      isNull,
    );
  });

  test('이전 owner의 늦은 완료 응답은 취소되고 새 owner Today를 건드리지 않는다', () async {
    final completion = Completer<ResponseBody>();
    final adapter = _QueueAdapter({
      'GET /contents/3': [
        _response(200, _contentJson(id: 3, title: 'A의 문서')),
        _response(200, _contentJson(id: 3, title: 'B의 문서')),
      ],
      'POST /contents/3/progress': [completion.future],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();
    final write = controller.reportProgress(scrollPct: 0.9, dwellSec: 46);

    container.read(_ownerProvider.notifier).setOwner('2');
    expect(container.read(currentMissionOwnerKeyProvider), '2');
    await Future<void>.delayed(Duration.zero);
    completion.complete(_json(200, _progressJson(completed: true)));

    expect(await write, isNull);
    expect(adapter.count('GET /learning-paths/me/this-week'), 0);
    await controller.load();
    expect(
      container.read(missionContentControllerProvider(_keyA)).content?.title,
      'B의 문서',
    );
  });

  test('force load와 겹친 완료 응답도 같은 owner 문서에 단조 병합한다', () async {
    final completion = Completer<ResponseBody>();
    final adapter = _QueueAdapter({
      'GET /contents/3': [
        _response(200, _contentJson(id: 3, title: '문서 A')),
        _response(200, _contentJson(id: 3, title: '새로 읽은 문서')),
      ],
      'POST /contents/3/progress': [completion.future],
      'GET /learning-paths/me/this-week': [
        _response(200, _availableMissionJson()),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();
    final write = controller.reportProgress(scrollPct: 0.9, dwellSec: 46);

    await controller.load(force: true);
    completion.complete(_json(200, _progressJson(completed: true)));
    await write;
    await Future<void>.delayed(Duration.zero);

    final content = container
        .read(missionContentControllerProvider(_keyA))
        .content;
    expect(content?.title, '새로 읽은 문서');
    expect(content?.progress.completed, isTrue);
  });

  test('write 시작 뒤 force load가 완료를 먼저 보여도 Today를 한 번 갱신한다', () async {
    final completion = Completer<ResponseBody>();
    final adapter = _QueueAdapter({
      'GET /contents/3': [
        _response(200, _contentJson(id: 3, title: '미완료 문서')),
        _response(200, _contentJson(id: 3, title: '완료 문서', completed: true)),
      ],
      'POST /contents/3/progress': [completion.future],
      'GET /learning-paths/me/this-week': [
        _response(200, _availableMissionJson()),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();

    final write = controller.reportProgress(scrollPct: 0.9, dwellSec: 46);
    await controller.load(force: true);
    completion.complete(_json(200, _progressJson(completed: true)));
    await write;
    await _waitForCount(adapter, 'GET /learning-paths/me/this-week', 1);

    expect(adapter.count('GET /learning-paths/me/this-week'), 1);
  });

  test('active·pending progress는 scroll과 dwell을 축별 최댓값으로 합친다', () async {
    final firstResponse = Completer<ResponseBody>();
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(200, _contentJson(id: 3, title: '문서 A'))],
      'POST /contents/3/progress': [
        firstResponse.future,
        _response(200, _progressJson(completed: false)),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();

    final scrollHeavy = controller.reportProgress(scrollPct: 0.9, dwellSec: 10);
    final dwellHeavy = controller.reportProgress(scrollPct: 0.2, dwellSec: 46);
    firstResponse.complete(_json(200, _progressJson(completed: false)));
    await Future.wait([scrollHeavy, dwellHeavy]);

    expect(adapter.bodies('POST /contents/3/progress'), [
      {'scrollPct': 0.9, 'dwellSec': 10},
      {'scrollPct': 0.9, 'dwellSec': 46},
    ]);
  });

  test('active 실패 뒤에도 pending 최댓값을 보존해 재진입 retry로 보낸다', () async {
    final firstResponse = Completer<ResponseBody>();
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(200, _contentJson(id: 3, title: '문서 A'))],
      'POST /contents/3/progress': [
        firstResponse.future,
        _response(200, _progressJson(completed: false)),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();

    final scrollHeavy = controller.reportProgress(scrollPct: 0.9, dwellSec: 10);
    final disposeFlush = controller.reportProgress(
      scrollPct: 0.2,
      dwellSec: 46,
    );
    firstResponse.complete(
      _json(500, {
        'error': {'code': 'INTERNAL_ERROR', 'message': '저장 지연'},
      }),
    );
    await Future.wait([scrollHeavy, disposeFlush]);

    expect(adapter.count('POST /contents/3/progress'), 1);
    expect(
      container
          .read(missionContentControllerProvider(_keyA))
          .progressFailureMessage,
      '저장 지연',
    );

    expect(await controller.retryProgress(), isNotNull);
    expect(adapter.bodies('POST /contents/3/progress'), [
      {'scrollPct': 0.9, 'dwellSec': 10},
      {'scrollPct': 0.9, 'dwellSec': 46},
    ]);
    expect(
      container
          .read(missionContentControllerProvider(_keyA))
          .progressFailureMessage,
      isNull,
    );
  });

  test('계정 전환은 검증 전 GET 없이 이전 문서를 지운다', () async {
    final adapter = _QueueAdapter({
      'GET /contents/3': [
        _response(200, _contentJson(id: 3, title: 'A의 문서')),
        _response(200, _contentJson(id: 3, title: 'B의 문서')),
      ],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();
    expect(controller.isBoundTo('1'), isTrue);

    container.read(_ownerProvider.notifier).setOwner('2');
    // Provider dependency propagation can occur after this synchronous line;
    // the page must use isBoundTo(currentOwner) to hide the old first frame.
    expect(controller.isBoundTo('2'), isFalse);
    expect(container.read(currentMissionOwnerKeyProvider), '2');
    await Future<void>.delayed(Duration.zero);
    expect(controller.isBoundTo('2'), isTrue);
    expect(adapter.count('GET /contents/3'), 1);
    expect(
      container.read(missionContentControllerProvider(_keyA)).content?.title,
      isNot('A의 문서'),
    );
    await controller.load();

    expect(
      container.read(missionContentControllerProvider(_keyA)).content?.title,
      'B의 문서',
    );
  });

  test('retention은 최근 두 workspace만 유지하고 owner 변경 시 비운다', () {
    final container = _container(_QueueAdapter({}));
    addTearDown(container.dispose);
    final retention = container.read(missionContentRetentionProvider.notifier);

    retention.touch(_keyA);
    retention.touch(_keyB);
    retention.touch(_keyA);
    retention.touch(_keyC);
    expect(container.read(missionContentRetentionProvider), [_keyA, _keyC]);

    container.read(_ownerProvider.notifier).setOwner('2');
    expect(container.read(missionContentRetentionProvider), isEmpty);
  });

  test('owner 변경은 이전 retention family 인스턴스를 실제로 폐기한다', () async {
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(404, const {})],
      'GET /contents/4': [_response(404, const {})],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final subscription = container.listen(
      missionContentControllerProvider(_keyA),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final retention = container.read(missionContentRetentionProvider.notifier);

    final controllerA = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    final controllerB = container.read(
      missionContentControllerProvider(_keyB).notifier,
    );
    retention.touch(_keyA);
    retention.touch(_keyB);
    expect(container.exists(missionContentControllerProvider(_keyA)), isTrue);
    expect(container.exists(missionContentControllerProvider(_keyB)), isTrue);

    container.read(_ownerProvider.notifier).setOwner('2');
    await container.pump();
    await container.pump();

    expect(container.read(missionContentRetentionProvider), isEmpty);
    expect(controllerA.isBoundTo('2'), isFalse);
    expect(controllerB.isBoundTo('2'), isFalse);
    final callsAfterDisposal =
        adapter.count('GET /contents/3') + adapter.count('GET /contents/4');

    container.read(_ownerProvider.notifier).setOwner('3');
    await container.pump();
    await container.pump();
    expect(
      adapter.count('GET /contents/3') + adapter.count('GET /contents/4'),
      callsAfterDisposal,
    );
  });

  test('owner 변경은 LRU pending 목록에만 남은 실패 family도 폐기한다', () async {
    final failure = Completer<ResponseBody>();
    final adapter = _QueueAdapter({
      'GET /contents/3': [_response(200, _contentJson(id: 3, title: '문서 A'))],
      'POST /contents/3/progress': [failure.future],
    });
    final container = _container(adapter);
    addTearDown(container.dispose);
    final subscription = container.listen(
      missionContentControllerProvider(_keyA),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final retention = container.read(missionContentRetentionProvider.notifier);
    retention.touch(_keyA);
    retention.touch(_keyB);
    final controller = container.read(
      missionContentControllerProvider(_keyA).notifier,
    );
    await controller.load();

    final write = controller.reportProgress(scrollPct: 0.9, dwellSec: 46);
    retention.touch(_keyC);
    failure.complete(
      _json(500, {
        'error': {'code': 'INTERNAL_ERROR', 'message': '저장 지연'},
      }),
    );
    await write;
    expect(controller.hasPendingProgress, isTrue);

    container.read(_ownerProvider.notifier).setOwner('2');
    await container.pump();
    await container.pump();

    expect(controller.isBoundTo('2'), isFalse);
    expect(
      container.read(missionContentControllerProvider(_keyA)).content,
      isNull,
    );

    container.read(_ownerProvider.notifier).setOwner('3');
    await container.pump();
    expect(controller.isBoundTo('3'), isFalse);
  });
}

final _ownerProvider = NotifierProvider<_OwnerController, String?>(
  _OwnerController.new,
);

class _OwnerController extends Notifier<String?> {
  @override
  String? build() => '1';

  void setOwner(String? owner) => state = owner;
}

ProviderContainer _container(_QueueAdapter adapter) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = adapter;
  return ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      currentMissionOwnerKeyProvider.overrideWith(
        (ref) => ref.watch(_ownerProvider),
      ),
    ],
  );
}

Map<String, dynamic> _contentJson({
  required int id,
  required String title,
  bool completed = false,
}) => {
  'id': id,
  'slug': 'content-$id',
  'title': title,
  'track': 'BACKEND',
  'markdown': '# $title',
  'conceptTags': <String>[],
  'progress': {
    'scrollPct': 0.2,
    'dwellSec': 5,
    'completed': completed,
    'completedAt': completed ? '2026-08-15T09:00:00Z' : null,
  },
};

Map<String, dynamic> _progressJson({required bool completed}) => {
  'scrollPct': 0.9,
  'dwellSec': 46,
  'completed': completed,
  'completedAt': completed ? '2026-08-15T10:00:00Z' : null,
};

Map<String, dynamic> _availableMissionJson() => {
  'outcome': 'AVAILABLE',
  'pathId': 21,
  'weekNum': 1,
  'tasks': [
    {
      'taskId': 32,
      'orderNum': 2,
      'taskType': 'PRACTICE',
      'title': '다음 미션',
      'required': true,
      'contentId': 4,
      'contentSlug': 'content-4',
      'completed': false,
      'completedAt': null,
    },
  ],
  'nextTask': {
    'taskId': 32,
    'orderNum': 2,
    'taskType': 'PRACTICE',
    'title': '다음 미션',
    'required': true,
    'contentId': 4,
    'contentSlug': 'content-4',
    'completed': false,
    'completedAt': null,
  },
  'pathCompleted': false,
};

Future<ResponseBody> _response(int status, Object body) async =>
    _json(status, body);

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final Map<String, List<Future<ResponseBody>>> responses;
  final Map<String, int> _counts = {};
  final Map<String, List<Object?>> _bodies = {};

  int count(String key) => _counts[key] ?? 0;
  List<Object?> bodies(String key) => _bodies[key] ?? const [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    _counts[key] = count(key) + 1;
    _bodies.putIfAbsent(key, () => []).add(options.data);
    final queue = responses[key];
    if (queue == null || queue.isEmpty) {
      return _json(404, {
        'error': {'code': 'RESOURCE_NOT_FOUND', 'message': 'no fixture: $key'},
      });
    }
    return queue.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _waitForCount(
  _QueueAdapter adapter,
  String key,
  int expected,
) async {
  for (
    var attempt = 0;
    attempt < 100 && adapter.count(key) < expected;
    attempt++
  ) {
    await Future<void>.delayed(Duration.zero);
  }
}
