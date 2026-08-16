import 'dart:async';

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
  _LifecyclePush({Future<bool>? permission})
    : _permission = permission ?? Future<bool>.value(true);

  final Future<bool> _permission;
  var deleteCalls = 0;
  var permissionCalls = 0;
  final refreshes = StreamController<String>.broadcast();

  @override
  Future<String?> getToken() async => 'fcm-tok';

  @override
  Stream<PushMessage> get incoming => const Stream.empty();

  @override
  Future<void> deleteToken() async => deleteCalls += 1;

  @override
  Future<bool> requestPermission() async {
    permissionCalls += 1;
    return _permission;
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

        await registrar.unregister('owner-a');
        push.refreshes.add('post-logout-token');
        await pumpEventQueue();

        expect(push.deleteCalls, 1);
        expect(await data.list('owner-a'), isEmpty);
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
