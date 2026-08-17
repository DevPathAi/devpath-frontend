import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/notifications/application/device_registrar.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePush implements PushService {
  _FakePush(this._token);
  final String? _token;
  @override
  Future<String?> getToken() async => _token;
  @override
  Stream<PushMessage> get incoming => const Stream.empty();
}

class _LifecyclePush implements PushService, PushTokenLifecycleService {
  _LifecyclePush({
    Future<bool>? permission,
    this.tokenFailures = 0,
    this.deleteFailures = 0,
    this.token = 'fcm-tok',
  }) : _permission = permission ?? Future<bool>.value(true);

  final Future<bool> _permission;
  int tokenFailures;
  int deleteFailures;
  final String token;
  var deleteCalls = 0;
  var permissionCalls = 0;
  final events = <String>[];
  final autoInitValues = <bool>[];
  final refreshes = StreamController<String>.broadcast();

  @override
  Future<String?> getToken() async {
    events.add('getToken');
    if (tokenFailures > 0) {
      tokenFailures -= 1;
      throw StateError('APNs token is not ready');
    }
    return token;
  }

  @override
  Stream<PushMessage> get incoming => const Stream.empty();

  @override
  Future<void> deleteToken() async {
    deleteCalls += 1;
    events.add('deleteToken');
    if (deleteFailures > 0) {
      deleteFailures -= 1;
      throw StateError('platform token deletion failed');
    }
  }

  @override
  Future<bool> requestPermission() async {
    permissionCalls += 1;
    events.add('requestPermission');
    return _permission;
  }

  @override
  Future<void> disableAutoInit() async {
    autoInitValues.add(false);
    events.add('autoInit:false');
  }

  @override
  Stream<String> get tokenRefresh => refreshes.stream;

  Future<void> close() => refreshes.close();
}

ApiClient _client(Map<String, MockFixture> fx) {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'http://test.local'));
  c.dio.httpClientAdapter = MockHttpAdapter(fx);
  return c;
}

void main() {
  group('DeviceRegistrar', () {
    test('토큰 있으면 POST /notifications/devices 등록(경로/메서드 일치)', () async {
      // 픽스처가 'POST /notifications/devices'에만 매칭 → 다른 경로면 예외.
      final c = _client({
        'POST /notifications/devices': (200, <String, dynamic>{}),
      });
      final r = DeviceRegistrar(c, _FakePush('fcm-tok'), 'ANDROID');
      await r.activate('owner-a'); // 무예외 = 올바른 경로로 호출됨
      await r.dispose();
    });

    test('토큰 없으면 네트워크 호출 안 함', () async {
      // 픽스처 없음: 호출되면 ApiException. 호출 안 하면 무예외.
      final c = _client(const {});
      final r = DeviceRegistrar(c, _FakePush(null), 'ANDROID');
      await r.activate('owner-a');
      await r.dispose();
    });

    test(
      'logout unregister calls server and invalidates local FCM token once',
      () async {
        final c = _client({
          'POST /notifications/devices': (200, <String, dynamic>{}),
          'DELETE /notifications/devices': (200, <String, dynamic>{}),
        });
        final push = _LifecyclePush();
        addTearDown(push.close);
        final data = InMemoryOwnerDataStore();
        final registrar = DeviceRegistrar(c, push, 'ANDROID', data);
        addTearDown(registrar.dispose);
        await registrar.activate('owner-a');
        push.events.clear();

        await registrar.unregister('owner-a');
        push.refreshes.add('post-logout-token');
        await pumpEventQueue();

        expect(push.deleteCalls, 1);
        expect(push.events, ['autoInit:false', 'deleteToken']);
        expect(push.autoInitValues, isNot(contains(true)));
        expect(await data.list('owner-a'), isEmpty);
      },
    );

    test(
      'approved activation creates a token explicitly without enabling auto-init',
      () async {
        final push = _LifecyclePush();
        addTearDown(push.close);
        final registrar = DeviceRegistrar(
          _client({'POST /notifications/devices': (200, <String, dynamic>{})}),
          push,
          'ANDROID',
        );
        addTearDown(registrar.dispose);

        await registrar.activate('owner-a');

        expect(push.events, ['requestPermission', 'getToken']);
        expect(push.autoInitValues, isNot(contains(true)));
      },
    );

    test(
      'approved activation retries token acquisition on next activation',
      () async {
        final push = _LifecyclePush(tokenFailures: 1);
        addTearDown(push.close);
        final data = InMemoryOwnerDataStore();
        final registrar = DeviceRegistrar(
          _client({'POST /notifications/devices': (200, <String, dynamic>{})}),
          push,
          'IOS',
          data,
        );
        addTearDown(registrar.dispose);

        await expectLater(registrar.activate('owner-a'), throwsStateError);
        expect(await data.list('owner-a'), isEmpty);
        await registrar.activate('owner-a');

        expect(push.events.where((event) => event == 'getToken'), hasLength(2));
        expect((await data.list('owner-a')).single.payload, 'fcm-tok');
        expect(push.autoInitValues, isNot(contains(true)));
      },
    );

    test('unregister request suppresses recursive auth termination', () async {
      final c = _client({
        'POST /notifications/devices': (200, <String, dynamic>{}),
        'DELETE /notifications/devices': (200, <String, dynamic>{}),
      });
      Map<String, dynamic>? deleteExtra;
      c.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'DELETE') {
              deleteExtra = Map<String, dynamic>.from(options.extra);
            }
            handler.next(options);
          },
        ),
      );
      final data = InMemoryOwnerDataStore();
      final registrar = DeviceRegistrar(
        c,
        _FakePush('fcm-tok'),
        'ANDROID',
        data,
      );
      addTearDown(registrar.dispose);
      await registrar.activate('owner-a');

      await registrar.unregister('owner-a');

      expect(
        deleteExtra?['dp_core.auth.suppress_terminal_notification'],
        isTrue,
      );
    });

    test(
      'active token rotation DELETE does not suppress auth termination',
      () async {
        final c = _client({
          'POST /notifications/devices': (200, <String, dynamic>{}),
          'DELETE /notifications/devices': (200, <String, dynamic>{}),
        });
        Map<String, dynamic>? deleteExtra;
        c.dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'DELETE') {
                deleteExtra = Map<String, dynamic>.from(options.extra);
              }
              handler.next(options);
            },
          ),
        );
        final data = InMemoryOwnerDataStore();
        await data.write(
          'owner-a',
          'push-registration-v1',
          'ANDROID',
          'old-token',
        );
        final push = _LifecyclePush();
        addTearDown(push.close);
        final registrar = DeviceRegistrar(c, push, 'ANDROID', data);
        addTearDown(registrar.dispose);

        await registrar.activate('owner-a');

        expect(
          deleteExtra?['dp_core.auth.suppress_terminal_notification'],
          isNot(true),
        );
      },
    );

    test('revoke failure is reported only after local token cleanup', () async {
      final push = _LifecyclePush();
      addTearDown(push.close);
      final data = InMemoryOwnerDataStore();
      final registrar = DeviceRegistrar(
        _client({
          'POST /notifications/devices': (200, <String, dynamic>{}),
          'DELETE /notifications/devices': (500, <String, dynamic>{}),
        }),
        push,
        'ANDROID',
        data,
      );
      addTearDown(registrar.dispose);
      await registrar.activate('owner-a');

      await expectLater(
        registrar.unregister('owner-a'),
        throwsA(isA<ApiException>()),
      );

      expect(push.deleteCalls, 1);
      expect(await data.list('owner-a'), isEmpty);
    });

    test(
      'consented activation requests permission and token refresh updates owner',
      () async {
        final c = _client({
          'POST /notifications/devices': (200, <String, dynamic>{}),
          'DELETE /notifications/devices': (200, <String, dynamic>{}),
        });
        final push = _LifecyclePush();
        addTearDown(push.close);
        final data = InMemoryOwnerDataStore();
        final registrar = DeviceRegistrar(c, push, 'ANDROID', data);
        addTearDown(registrar.dispose);

        await registrar.activate('owner-a');
        expect(push.permissionCalls, 1);
        expect((await data.list('owner-a')).single.payload, 'fcm-tok');

        push.refreshes.add('rotated-token');
        await pumpEventQueue();

        expect((await data.list('owner-a')).single.payload, 'rotated-token');
        expect(await data.list('owner-b'), isEmpty);

        await registrar.activate('owner-b');
        push.refreshes.add('owner-b-token');
        await pumpEventQueue();

        expect((await data.list('owner-a')).single.payload, 'rotated-token');
        expect((await data.list('owner-b')).single.payload, 'owner-b-token');
      },
    );

    test(
      'logout during prior-token delete prevents stale registration POST',
      () async {
        final adapter = _DelayedPriorDeleteAdapter();
        final client = ApiClient.create(
          const ApiConfig(baseUrl: 'https://api.test'),
        );
        client.dio.httpClientAdapter = adapter;
        final push = _LifecyclePush();
        addTearDown(push.close);
        final data = InMemoryOwnerDataStore();
        await data.write(
          'owner-a',
          'push-registration-v1',
          'ANDROID',
          'old-token',
        );
        final registrar = DeviceRegistrar(client, push, 'ANDROID', data);
        addTearDown(registrar.dispose);

        final activating = registrar.activate('owner-a');
        await adapter.firstDeleteStarted.future;
        final loggingOut = registrar.unregister('owner-a');
        final logoutFailure = expectLater(
          loggingOut,
          throwsA(isA<ApiException>()),
        );
        adapter.releaseFirstDelete.complete();
        await activating;
        await logoutFailure;

        expect(adapter.postCalls, 0);
        expect(await data.list('owner-a'), isEmpty);
      },
    );

    test(
      'failed prior-token rotation delete preserves the retryable old handle',
      () async {
        final adapter = _RotationDeleteFailureAdapter();
        final client = ApiClient.create(
          const ApiConfig(baseUrl: 'https://api.test'),
        );
        client.dio.httpClientAdapter = adapter;
        final push = _LifecyclePush();
        addTearDown(push.close);
        final data = InMemoryOwnerDataStore();
        await data.write(
          'owner-a',
          'push-registration-v1',
          'ANDROID',
          'old-token',
        );
        final registrar = DeviceRegistrar(client, push, 'ANDROID', data);
        addTearDown(registrar.dispose);

        await expectLater(
          registrar.activate('owner-a'),
          throwsA(isA<ApiException>()),
        );

        expect(adapter.postCalls, 0);
        expect((await data.list('owner-a')).single.payload, 'old-token');

        await registrar.unregister('owner-a');

        expect(adapter.deleteCalls, 2);
        expect(await data.list('owner-a'), isEmpty);
      },
    );

    test(
      'backend and platform cleanup failure survives owner clear and restart',
      () async {
        final adapter = _RevocationRetryAdapter(failedDeletes: 1);
        final client = ApiClient.create(
          const ApiConfig(baseUrl: 'https://api.test'),
        );
        client.dio.httpClientAdapter = adapter;
        final data = InMemoryOwnerDataStore();
        final durable = InMemoryKeyValueStore();
        await data.write(
          'owner-a',
          'push-registration-v1',
          'ANDROID',
          'owner-a-token',
        );
        final failingPush = _LifecyclePush(
          token: 'owner-a-token',
          deleteFailures: 1,
        );
        addTearDown(failingPush.close);
        final first = DeviceRegistrar(
          client,
          failingPush,
          'ANDROID',
          data,
          durable,
        );

        await expectLater(
          first.unregister('owner-a', credentialOwnerConfirmed: true),
          throwsA(anyOf(isA<ApiException>(), isA<StateError>())),
        );
        await first.dispose();
        // Mirrors AccountDataCleaner after AuthController contains revocation
        // failure. The pending handle must not live under owner A.
        await data.clearOwner('owner-a');

        final recoveredPush = _LifecyclePush(token: 'owner-a-new-token');
        addTearDown(recoveredPush.close);
        final restarted = DeviceRegistrar(
          client,
          recoveredPush,
          'ANDROID',
          data,
          durable,
        );
        addTearDown(restarted.dispose);

        await restarted.activate('owner-a');

        expect(adapter.deletedTokens, ['owner-a-token']);
        expect(adapter.postedTokens, ['owner-a-new-token']);
        expect(adapter.events, [
          'DELETE owner-a-token',
          'POST owner-a-new-token',
        ]);
        expect(
          (await data.list('owner-a')).single.payload,
          'owner-a-new-token',
        );

        await restarted.dispose();
        final finalPass = DeviceRegistrar(
          client,
          _LifecyclePush(token: 'owner-a-new-token'),
          'ANDROID',
          data,
          durable,
        );
        await finalPass.activate('owner-a');
        await finalPass.dispose();
        expect(adapter.deletedTokens, ['owner-a-token']);
      },
    );

    test(
      'B credential 204 cannot clear A revocation without platform invalidation',
      () async {
        final adapter = _CrossOwnerNoOpDeleteAdapter();
        final client = ApiClient.create(
          const ApiConfig(baseUrl: 'https://api.test'),
        );
        client.dio.httpClientAdapter = adapter;
        final data = InMemoryOwnerDataStore();
        final durable = InMemoryKeyValueStore();
        await data.write(
          'owner-a',
          'push-registration-v1',
          'ANDROID',
          'owner-a-token',
        );
        final firstPush = _LifecyclePush(deleteFailures: 1);
        addTearDown(firstPush.close);
        final first = DeviceRegistrar(
          client,
          firstPush,
          'ANDROID',
          data,
          durable,
        );
        adapter.credentialOwner = 'owner-a';
        await expectLater(
          first.unregister('owner-a', credentialOwnerConfirmed: true),
          throwsA(anything),
        );
        await first.dispose();
        await data.clearOwner('owner-a');

        adapter.credentialOwner = 'owner-b';
        final bPush = _LifecyclePush(token: 'owner-b-token', deleteFailures: 1);
        addTearDown(bPush.close);
        final b = DeviceRegistrar(client, bPush, 'ANDROID', data, durable);

        await expectLater(b.activate('owner-b'), throwsA(isA<StateError>()));

        expect(adapter.deleteOwners, ['owner-a']);
        expect(adapter.postedTokens, isEmpty);
        await b.dispose();

        final retryPush = _LifecyclePush(token: 'owner-b-token');
        addTearDown(retryPush.close);
        final retry = DeviceRegistrar(
          client,
          retryPush,
          'ANDROID',
          data,
          durable,
        );
        addTearDown(retry.dispose);
        await retry.activate('owner-b');

        // Cross-owner retry invalidates the installation token; it never
        // mistakes B's idempotent 204 for an A-owned backend revocation.
        expect(adapter.deleteOwners, ['owner-a']);
        expect(adapter.postedTokens, ['owner-b-token']);
      },
    );

    test(
      'stale successful POST cleanup failure is retried exactly after restart',
      () async {
        final adapter = _DelayedStalePostAdapter(failedDeletes: 1);
        final client = ApiClient.create(
          const ApiConfig(baseUrl: 'https://api.test'),
        );
        client.dio.httpClientAdapter = adapter;
        final data = InMemoryOwnerDataStore();
        final durable = InMemoryKeyValueStore();
        final stalePush = _LifecyclePush(
          token: 'stale-post-token',
          deleteFailures: 3,
        );
        addTearDown(stalePush.close);
        final first = DeviceRegistrar(
          client,
          stalePush,
          'ANDROID',
          data,
          durable,
        );

        final activating = first.activate('owner-a');
        await adapter.postStarted.future;
        final unregistering = first.unregister('owner-a');
        adapter.releasePost.complete();
        await activating;
        await expectLater(unregistering, throwsA(anything));
        await first.dispose();
        await data.clearOwner('owner-a');

        final restartedPush = _LifecyclePush(token: 'owner-a-fresh-token');
        addTearDown(restartedPush.close);
        final restarted = DeviceRegistrar(
          client,
          restartedPush,
          'ANDROID',
          data,
          durable,
        );
        addTearDown(restarted.dispose);
        await restarted.activate('owner-a');

        expect(adapter.deletedTokens.last, 'stale-post-token');
        expect(adapter.postedTokens.last, 'owner-a-fresh-token');
      },
    );

    test(
      'POST success followed by local write failure retains an exact handle',
      () async {
        final adapter = _RevocationRetryAdapter(failedDeletes: 0);
        final client = ApiClient.create(
          const ApiConfig(baseUrl: 'https://api.test'),
        );
        client.dio.httpClientAdapter = adapter;
        final data = _FailOnceRegistrationWriteStore();
        final durable = InMemoryKeyValueStore();
        final firstPush = _LifecyclePush(token: 'orphan-risk-token');
        addTearDown(firstPush.close);
        final first = DeviceRegistrar(
          client,
          firstPush,
          'ANDROID',
          data,
          durable,
        );

        await expectLater(first.activate('owner-a'), throwsStateError);
        await first.dispose();
        expect(await data.list('owner-a'), isEmpty);

        final retryPush = _LifecyclePush(token: 'orphan-risk-token');
        addTearDown(retryPush.close);
        final restarted = DeviceRegistrar(
          client,
          retryPush,
          'ANDROID',
          data,
          durable,
        );
        addTearDown(restarted.dispose);
        await restarted.activate('owner-a');

        expect(adapter.events, [
          'POST orphan-risk-token',
          'DELETE orphan-risk-token',
          'POST orphan-risk-token',
        ]);
        expect(
          (await data.list('owner-a')).single.payload,
          'orphan-risk-token',
        );
      },
    );

    test(
      'registration row plus uncleared handle is revoked before restart reuse',
      () async {
        final adapter = _RevocationRetryAdapter(failedDeletes: 0);
        final client = ApiClient.create(
          const ApiConfig(baseUrl: 'https://api.test'),
        );
        client.dio.httpClientAdapter = adapter;
        final data = InMemoryOwnerDataStore();
        final durable = _FailFirstPendingRevocationClearStore();
        final firstPush = _LifecyclePush(token: 'uncertain-token');
        addTearDown(firstPush.close);
        final first = DeviceRegistrar(
          client,
          firstPush,
          'ANDROID',
          data,
          durable,
        );

        await expectLater(first.activate('owner-a'), throwsStateError);
        await first.dispose();
        expect((await data.list('owner-a')).single.payload, 'uncertain-token');

        final retryPush = _LifecyclePush(token: 'uncertain-token');
        addTearDown(retryPush.close);
        final restarted = DeviceRegistrar(
          client,
          retryPush,
          'ANDROID',
          data,
          durable,
        );
        addTearDown(restarted.dispose);
        await restarted.activate('owner-a');

        expect(adapter.events, [
          'POST uncertain-token',
          'DELETE uncertain-token',
          'POST uncertain-token',
        ]);
        expect((await data.list('owner-a')).single.payload, 'uncertain-token');
      },
    );

    test(
      'permission pending or denied cannot subscribe or apply token refresh',
      () async {
        final permission = Completer<bool>();
        final push = _LifecyclePush(permission: permission.future);
        addTearDown(push.close);
        final data = InMemoryOwnerDataStore();
        final registrar = DeviceRegistrar(
          _client({'POST /notifications/devices': (200, <String, dynamic>{})}),
          push,
          'ANDROID',
          data,
        );
        addTearDown(registrar.dispose);

        final activating = registrar.activate('owner-a');
        push.refreshes.add('premature-token');
        await pumpEventQueue();
        expect(await data.list('owner-a'), isEmpty);

        permission.complete(false);
        await activating;
        push.refreshes.add('denied-token');
        await pumpEventQueue();

        expect(await data.list('owner-a'), isEmpty);
      },
    );

    test(
      'logout cleanup is not blocked by a pending permission prompt',
      () async {
        final permission = Completer<bool>();
        final push = _LifecyclePush(permission: permission.future);
        addTearDown(push.close);
        final data = InMemoryOwnerDataStore();
        final registrar = DeviceRegistrar(
          _client(const {}),
          push,
          'ANDROID',
          data,
        );
        addTearDown(registrar.dispose);

        final activating = registrar.activate('owner-a');
        await pumpEventQueue();
        final unregistering = registrar.unregister('owner-a');
        final clearedPromptly = await Future.any([
          unregistering.then((_) => true),
          Future<void>.delayed(const Duration(seconds: 1)).then((_) => false),
        ]);
        permission.complete(false);
        await activating;
        await unregistering;

        expect(clearedPromptly, isTrue);
        expect(push.deleteCalls, 1);
        expect(await data.list('owner-a'), isEmpty);
      },
    );

    test(
      'denial revokes any earlier owner registration and platform token',
      () async {
        final data = InMemoryOwnerDataStore();
        final client = _client({
          'POST /notifications/devices': (200, <String, dynamic>{}),
          'DELETE /notifications/devices': (200, <String, dynamic>{}),
        });
        final seedPush = _LifecyclePush();
        final seedRegistrar = DeviceRegistrar(
          client,
          seedPush,
          'ANDROID',
          data,
        );
        await seedRegistrar.activate('owner-a');
        await seedRegistrar.dispose();
        await seedPush.close();

        final push = _LifecyclePush(permission: Future<bool>.value(false));
        addTearDown(push.close);
        final registrar = DeviceRegistrar(client, push, 'ANDROID', data);
        addTearDown(registrar.dispose);

        await registrar.activate('owner-a');

        expect(push.deleteCalls, 1);
        expect(await data.list('owner-a'), isEmpty);
      },
    );
  });
}

class _DelayedPriorDeleteAdapter implements HttpClientAdapter {
  final firstDeleteStarted = Completer<void>();
  final releaseFirstDelete = Completer<void>();
  var deleteCalls = 0;
  var postCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'DELETE') {
      deleteCalls += 1;
      if (deleteCalls == 1) {
        firstDeleteStarted.complete();
        await releaseFirstDelete.future;
      }
      final status = deleteCalls == 2 ? 500 : 200;
      return ResponseBody.fromString(
        jsonEncode(
          status == 200
              ? <String, dynamic>{}
              : {
                  'error': {'code': 'UNKNOWN', 'message': 'forced failure'},
                },
        ),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.method == 'POST') postCalls += 1;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FailOnceRegistrationWriteStore extends InMemoryOwnerDataStore {
  var _fail = true;

  @override
  Future<void> write(
    String ownerKey,
    String bucket,
    String recordKey,
    String payload, {
    DateTime? updatedAt,
  }) {
    if (_fail && bucket == 'push-registration-v1') {
      _fail = false;
      throw StateError('local registration write failed');
    }
    return super.write(
      ownerKey,
      bucket,
      recordKey,
      payload,
      updatedAt: updatedAt,
    );
  }
}

class _FailFirstPendingRevocationClearStore implements KeyValueStore {
  final _delegate = InMemoryKeyValueStore();
  var _fail = true;

  @override
  Future<String?> read(String key) => _delegate.read(key);

  @override
  Future<void> write(String key, String value) => _delegate.write(key, value);

  @override
  Future<void> delete(String key) {
    if (_fail && key == DeviceRegistrar.pendingRevocationsStorageKey) {
      _fail = false;
      throw StateError('pending revocation clear failed');
    }
    return _delegate.delete(key);
  }
}

class _RotationDeleteFailureAdapter implements HttpClientAdapter {
  var deleteCalls = 0;
  var postCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'DELETE') {
      deleteCalls += 1;
      final status = deleteCalls == 1 ? 500 : 200;
      return ResponseBody.fromString(
        jsonEncode(
          status == 200
              ? <String, dynamic>{}
              : {
                  'error': {'code': 'UNKNOWN', 'message': 'forced failure'},
                },
        ),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.method == 'POST') postCalls += 1;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _requestBody(RequestOptions options) =>
    Map<String, dynamic>.from(options.data as Map);

ResponseBody _jsonResponse(int status) => ResponseBody.fromString(
  jsonEncode(
    status >= 200 && status < 300
        ? <String, dynamic>{}
        : {
            'error': {'code': 'UNKNOWN', 'message': 'forced failure'},
          },
  ),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _RevocationRetryAdapter implements HttpClientAdapter {
  _RevocationRetryAdapter({required this.failedDeletes});

  int failedDeletes;
  final deletedTokens = <String>[];
  final postedTokens = <String>[];
  final events = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final token = _requestBody(options)['token'] as String;
    if (options.method == 'DELETE') {
      if (failedDeletes > 0) {
        failedDeletes -= 1;
        return _jsonResponse(500);
      }
      deletedTokens.add(token);
      events.add('DELETE $token');
      return _jsonResponse(200);
    }
    postedTokens.add(token);
    events.add('POST $token');
    return _jsonResponse(200);
  }

  @override
  void close({bool force = false}) {}
}

class _CrossOwnerNoOpDeleteAdapter implements HttpClientAdapter {
  String credentialOwner = 'owner-a';
  var firstOwnerDelete = true;
  final deleteOwners = <String>[];
  final postedTokens = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final token = _requestBody(options)['token'] as String;
    if (options.method == 'DELETE') {
      deleteOwners.add(credentialOwner);
      if (credentialOwner == 'owner-a' && firstOwnerDelete) {
        firstOwnerDelete = false;
        return _jsonResponse(500);
      }
      // The backend contract is idempotent: B receives 204 even though it did
      // not remove A's owner-scoped registration.
      return _jsonResponse(204);
    }
    postedTokens.add(token);
    return _jsonResponse(200);
  }

  @override
  void close({bool force = false}) {}
}

class _DelayedStalePostAdapter implements HttpClientAdapter {
  _DelayedStalePostAdapter({required this.failedDeletes});

  int failedDeletes;
  final postStarted = Completer<void>();
  final releasePost = Completer<void>();
  final deletedTokens = <String>[];
  final postedTokens = <String>[];
  var _postCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final token = _requestBody(options)['token'] as String;
    if (options.method == 'DELETE') {
      if (failedDeletes > 0) {
        failedDeletes -= 1;
        return _jsonResponse(500);
      }
      deletedTokens.add(token);
      return _jsonResponse(200);
    }
    _postCalls += 1;
    if (_postCalls == 1) {
      postStarted.complete();
      await releasePost.future;
    }
    postedTokens.add(token);
    return _jsonResponse(200);
  }

  @override
  void close({bool force = false}) {}
}
