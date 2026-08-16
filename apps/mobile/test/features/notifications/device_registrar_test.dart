import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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
  _LifecyclePush({Future<bool>? permission, this.tokenFailures = 0})
    : _permission = permission ?? Future<bool>.value(true);

  final Future<bool> _permission;
  int tokenFailures;
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
    return 'fcm-tok';
  }

  @override
  Stream<PushMessage> get incoming => const Stream.empty();

  @override
  Future<void> deleteToken() async {
    deleteCalls += 1;
    events.add('deleteToken');
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
