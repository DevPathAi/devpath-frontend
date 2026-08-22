import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/features/review/application/review_controller.dart';
import 'package:devpath_web/src/features/review/state/review_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const a = MissionWorkspaceKey(taskId: 1, contentId: 11);
const b = MissionWorkspaceKey(taskId: 2, contentId: 22);

final class _DeferredReviewAdapter implements HttpClientAdapter {
  final pending = <int, List<Completer<ResponseBody>>>{};
  final calls = <int, int>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) {
    final sessionId = int.parse(
      '${options.queryParameters['sandboxSessionId']}',
    );
    calls.update(sessionId, (value) => value + 1, ifAbsent: () => 1);
    final completer = Completer<ResponseBody>();
    pending.putIfAbsent(sessionId, () => []).add(completer);
    return completer.future;
  }

  void respond(int sessionId, Map<String, Object?> json, {int status = 200}) {
    final completer = pending[sessionId]!.removeAt(0);
    completer.complete(
      ResponseBody.fromString(
        jsonEncode(json),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }

  void fail(int sessionId, Object error) {
    pending[sessionId]!.removeAt(0).completeError(error);
  }

  @override
  void close({bool force = false}) {}
}

final class _OwnerController extends Notifier<String> {
  @override
  String build() => 'owner-a';

  void switchTo(String owner) => state = owner;
}

final _ownerProvider = NotifierProvider<_OwnerController, String>(
  _OwnerController.new,
);

Map<String, Object?> _done(int confidence) => {
  'status': 'DONE',
  'confidence': confidence,
  'strengths': ['review-$confidence'],
  'improvements': <Map<String, Object?>>[],
  'security': <Map<String, Object?>>[],
};

Map<String, Object?> _failed() => {
  'status': 'FAILED',
  'confidence': 0,
  'strengths': <String>[],
  'improvements': <Map<String, Object?>>[],
  'security': <Map<String, Object?>>[],
};

Future<void> _waitForRequest(
  _DeferredReviewAdapter adapter,
  int sessionId,
) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (adapter.pending[sessionId]?.isNotEmpty ?? false) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('review request for session $sessionId did not start');
}

({ProviderContainer container, _DeferredReviewAdapter adapter}) _container() {
  final adapter = _DeferredReviewAdapter();
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'))
    ..dio.httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      currentMissionOwnerKeyProvider.overrideWith(
        (ref) => ref.watch(_ownerProvider),
      ),
    ],
  );
  return (container: container, adapter: adapter);
}

void main() {
  test('workspace별 리뷰를 격리하고 late A가 B를 덮지 않는다', () async {
    final (:container, :adapter) = _container();
    addTearDown(container.dispose);

    final futureA = container
        .read(reviewControllerFamilyProvider(a).notifier)
        .pollForSession(101, interval: Duration.zero);
    final futureB = container
        .read(reviewControllerFamilyProvider(b).notifier)
        .pollForSession(202, interval: Duration.zero);
    await Future.wait([
      _waitForRequest(adapter, 101),
      _waitForRequest(adapter, 202),
    ]);
    adapter.respond(202, _done(82));
    await futureB;
    adapter.respond(101, _done(71));
    await futureA;

    final stateA = container.read(reviewControllerFamilyProvider(a));
    final stateB = container.read(reviewControllerFamilyProvider(b));
    expect((stateA as ReviewLoaded).review.confidence, 71);
    expect(stateA.sandboxSessionId, 101);
    expect((stateB as ReviewLoaded).review.confidence, 82);
    expect(stateB.sandboxSessionId, 202);
  });

  test('다른 session poll과 owner 전환은 이전 late 응답을 무시한다', () async {
    final (:container, :adapter) = _container();
    addTearDown(container.dispose);
    final controller = container.read(
      reviewControllerFamilyProvider(a).notifier,
    );

    final oldPoll = controller.pollForSession(101, interval: Duration.zero);
    await _waitForRequest(adapter, 101);
    final newPoll = controller.pollForSession(102, interval: Duration.zero);
    await _waitForRequest(adapter, 102);
    adapter.respond(102, _done(92));
    await newPoll;
    adapter.respond(101, _done(12));
    await oldPoll;
    final loaded =
        container.read(reviewControllerFamilyProvider(a)) as ReviewLoaded;
    expect(loaded.review.confidence, 92);
    expect(loaded.sandboxSessionId, 102);

    final ownerPoll = controller.pollForSession(103, interval: Duration.zero);
    await _waitForRequest(adapter, 103);
    container.read(_ownerProvider.notifier).switchTo('owner-b');
    adapter.respond(103, _done(1));
    await ownerPoll;
    final afterOwnerSwitch = container.read(reviewControllerFamilyProvider(a));
    expect(afterOwnerSwitch, isA<ReviewIdle>());
  });

  test('중복 tap은 coalesce하고 재시도 중 마지막 valid review를 보존한다', () async {
    final (:container, :adapter) = _container();
    addTearDown(container.dispose);
    final controller = container.read(
      reviewControllerFamilyProvider(a).notifier,
    );

    final first = controller.pollForSession(101, interval: Duration.zero);
    final duplicate = controller.pollForSession(101, interval: Duration.zero);
    await _waitForRequest(adapter, 101);
    expect(adapter.calls[101], 1);
    adapter.respond(101, _done(88));
    await Future.wait([first, duplicate]);

    final retry = controller.pollForSession(101, interval: Duration.zero);
    await _waitForRequest(adapter, 101);
    final loading = container.read(reviewControllerFamilyProvider(a));
    expect(loading, isA<ReviewLoading>());
    expect(loading.retainedReview?.confidence, 88);
    adapter.respond(101, _failed());
    await retry;
    final failed = container.read(reviewControllerFamilyProvider(a));
    expect(failed, isA<ReviewFailed>());
    expect(failed.retainedReview?.confidence, 88);
  });

  test('non-API 예외도 loading에 고착되지 않는다', () async {
    final (:container, :adapter) = _container();
    addTearDown(container.dispose);
    final future = container
        .read(reviewControllerFamilyProvider(a).notifier)
        .pollForSession(101, interval: Duration.zero);
    await _waitForRequest(adapter, 101);
    adapter.fail(101, StateError('broken transport'));
    await future;

    expect(
      container.read(reviewControllerFamilyProvider(a)),
      isA<ReviewFailed>(),
    );
  });
}
