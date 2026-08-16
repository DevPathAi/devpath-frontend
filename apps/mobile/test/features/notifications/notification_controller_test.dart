import 'dart:async';

import 'package:devpath_mobile/src/features/notifications/application/notification_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/features/notifications/data/notification_store.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 제어 가능한 incoming 스트림을 노출하는 가짜 푸시 서비스.
class _FakePush implements PushService {
  _FakePush(this._controller);

  final StreamController<PushMessage> _controller;

  @override
  Future<String?> getToken() async => 'fake-token';

  @override
  Stream<PushMessage> get incoming => _controller.stream;
}

class _FakeInteractivePush implements PushService, PushInteractionService {
  _FakeInteractivePush({this.initial});

  final PushMessage? initial;
  final incomingController = StreamController<PushMessage>();
  final openedController = StreamController<PushMessage>();

  @override
  Future<String?> getToken() async => 'fake-token';

  @override
  Stream<PushMessage> get incoming => incomingController.stream;

  @override
  Future<PushMessage?> initialMessage() async => initial;

  @override
  Stream<PushMessage> get opened => openedController.stream;

  Future<void> close() async {
    await incomingController.close();
    await openedController.close();
  }
}

class _OwnerController extends Notifier<String?> {
  @override
  String? build() => 'owner-a';

  void setOwner(String? owner) => state = owner;
}

class _NotificationAuthController extends AuthController {
  @override
  AuthState build() => const AuthLoading();

  void authenticate(String ownerKey) => state = AuthAuthenticated(
    User(
      id: ownerKey,
      email: '$ownerKey@example.com',
      nickname: ownerKey,
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );

  void unauthenticate() => state = const AuthUnauthenticated();
}

class _DelayedNotificationData extends InMemoryOwnerDataStore {
  final writeStarted = Completer<void>();
  final releaseWrite = Completer<void>();
  final staleDiscarded = Completer<void>();

  @override
  Future<void> write(
    String ownerKey,
    String bucket,
    String recordKey,
    String payload, {
    DateTime? updatedAt,
  }) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await releaseWrite.future;
    await super.write(
      ownerKey,
      bucket,
      recordKey,
      payload,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> deleteIfMatches(
    String ownerKey,
    String bucket,
    String recordKey, {
    required String payload,
    required DateTime updatedAt,
  }) async {
    await super.deleteIfMatches(
      ownerKey,
      bucket,
      recordKey,
      payload: payload,
      updatedAt: updatedAt,
    );
    if (!staleDiscarded.isCompleted) staleDiscarded.complete();
  }
}

class _BlockedMarkListData extends InMemoryOwnerDataStore {
  var blockNextMarkList = false;
  final listStarted = Completer<void>();
  final releaseList = Completer<void>();

  @override
  Future<List<OwnerDataRecord>> list(String ownerKey, [String? bucket]) async {
    final rows = await super.list(ownerKey, bucket);
    if (blockNextMarkList &&
        ownerKey == 'owner-a' &&
        bucket == NotificationStore.bucket) {
      blockNextMarkList = false;
      if (!listStarted.isCompleted) listStarted.complete();
      await releaseList.future;
    }
    return rows;
  }
}

class _FailingMarkWriteData extends InMemoryOwnerDataStore {
  var failNextMarkWrite = false;
  final writeStarted = Completer<void>();
  final releaseWrite = Completer<void>();

  @override
  Future<void> write(
    String ownerKey,
    String bucket,
    String recordKey,
    String payload, {
    DateTime? updatedAt,
  }) async {
    if (failNextMarkWrite &&
        ownerKey == 'owner-a' &&
        bucket == NotificationStore.bucket) {
      failNextMarkWrite = false;
      if (!writeStarted.isCompleted) writeStarted.complete();
      await releaseWrite.future;
      throw StateError('late mark-all failure');
    }
    await super.write(
      ownerKey,
      bucket,
      recordKey,
      payload,
      updatedAt: updatedAt,
    );
  }
}

class _ConcurrentMarkData extends InMemoryOwnerDataStore {
  var blockMarkedWrites = false;
  var markedWriteCount = 0;
  final firstMarkedWriteStarted = Completer<void>();
  final releaseMarkedWrites = Completer<void>();

  @override
  Future<void> write(
    String ownerKey,
    String bucket,
    String recordKey,
    String payload, {
    DateTime? updatedAt,
  }) async {
    if (blockMarkedWrites &&
        ownerKey == 'owner-a' &&
        bucket == NotificationStore.bucket &&
        payload.contains('"isRead":true')) {
      markedWriteCount += 1;
      if (!firstMarkedWriteStarted.isCompleted) {
        firstMarkedWriteStarted.complete();
      }
      await releaseMarkedWrites.future;
    }
    await super.write(
      ownerKey,
      bucket,
      recordKey,
      payload,
      updatedAt: updatedAt,
    );
  }
}

final _ownerProvider = NotifierProvider<_OwnerController, String?>(
  _OwnerController.new,
);

({ProviderContainer container, StreamController<PushMessage> push}) _setup() {
  final ctrl = StreamController<PushMessage>();
  addTearDown(ctrl.close);
  final c = ProviderContainer(
    overrides: [
      pushServiceProvider.overrideWithValue(_FakePush(ctrl)),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      currentOwnerKeyProvider.overrideWithValue('owner-a'),
      notificationStoreProvider.overrideWithValue(
        NotificationStore(InMemoryOwnerDataStore()),
      ),
    ],
  );
  addTearDown(c.dispose);
  return (container: c, push: ctrl);
}

void main() {
  group('NotificationController', () {
    test('초기 상태는 빈 목록 + 미읽음 0', () {
      final s = _setup().container.read(notificationControllerProvider);
      expect(s.messages, isEmpty);
      expect(s.unreadCount, 0);
    });

    test('같은 message ID는 durable/in-memory 목록과 badge에서 중복 제거한다', () async {
      final (:container, :push) = _setup();
      final sub = container.listen(notificationControllerProvider, (_, _) {});
      addTearDown(sub.close);
      const duplicate = PushMessage.local(id: 'same', title: 'A', body: 'a');

      push.add(duplicate);
      push.add(duplicate);
      await pumpEventQueue();

      final state = container.read(notificationControllerProvider);
      expect(state.messages, hasLength(1));
      expect(state.unreadCount, 1);
    });

    test('수신 메시지는 최신순으로 누적되고 미읽음이 증가한다', () async {
      final (:container, :push) = _setup();
      // 화면(ref.watch)처럼 활성 구독해 build()의 incoming 리스너를 유지.
      final sub = container.listen(notificationControllerProvider, (_, _) {});
      addTearDown(sub.close);

      push.add(const PushMessage.local(id: '1', title: '첫 알림', body: '본문1'));
      push.add(const PushMessage.local(id: '2', title: '둘째 알림', body: '본문2'));
      await pumpEventQueue();

      final s = container.read(notificationControllerProvider);
      expect(s.messages.map((m) => m.id).toList(), ['2', '1']);
      expect(s.unreadCount, 2);
    });

    test('다른 owner로 지정된 메시지는 현재 계정에 저장하지 않는다', () async {
      final (:container, :push) = _setup();
      final sub = container.listen(notificationControllerProvider, (_, _) {});
      addTearDown(sub.close);

      push.add(
        const PushMessage.ownerScoped(
          id: 'owner-b-only',
          title: 'B 전용',
          body: 'A에게 보이면 안 됨',
          intendedOwnerKey: 'owner-b',
        ),
      );
      await pumpEventQueue();

      expect(container.read(notificationControllerProvider).messages, isEmpty);
    });

    test('비어 있는 production owner scope는 저장하거나 열지 않는다', () async {
      final (:container, :push) = _setup();
      final sub = container.listen(notificationControllerProvider, (_, _) {});
      addTearDown(sub.close);
      const unscoped = PushMessage.ownerScoped(
        id: 'unscoped',
        title: '잘못된 원격 알림',
        body: '폐기',
        intendedOwnerKey: '   ',
        target: PushTarget.today(pathId: 301),
      );

      push.add(unscoped);
      await pumpEventQueue();
      container.read(notificationControllerProvider.notifier).open(unscoped);

      final state = container.read(notificationControllerProvider);
      expect(state.messages, isEmpty);
      expect(state.navigationTarget, isNull);
    });

    test('markAllRead는 미읽음을 0으로 만들고 목록은 유지한다', () async {
      final (:container, :push) = _setup();
      final sub = container.listen(notificationControllerProvider, (_, _) {});
      addTearDown(sub.close);

      push.add(const PushMessage.local(id: '1', title: 'A', body: 'a'));
      await pumpEventQueue();
      expect(container.read(notificationControllerProvider).unreadCount, 1);

      await container
          .read(notificationControllerProvider.notifier)
          .markAllRead();

      final s = container.read(notificationControllerProvider);
      expect(s.unreadCount, 0);
      expect(s.messages, hasLength(1));
    });

    test(
      'A mark-all snapshot cannot resurrect A rows after purge and B switch',
      () async {
        final data = _BlockedMarkListData();
        final store = NotificationStore(data);
        await _seedUnread(store, 'owner-a', 'a-1');
        await _seedUnread(store, 'owner-b', 'b-1');
        await _seedUnread(store, 'owner-b', 'b-2');
        final push = StreamController<PushMessage>();
        addTearDown(push.close);
        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(_FakePush(push)),
            currentOwnerKeyProvider.overrideWith(
              (ref) => ref.watch(_ownerProvider),
            ),
            notificationStoreProvider.overrideWithValue(store),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          notificationControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await pumpEventQueue();
        expect(container.read(notificationControllerProvider).unreadCount, 1);

        data.blockNextMarkList = true;
        container.read(notificationControllerProvider.notifier).markAllRead();
        await data.listStarted.future;
        await data.clearOwner('owner-a');
        container.read(_ownerProvider.notifier).setOwner('owner-b');
        await pumpEventQueue();
        expect(container.read(notificationControllerProvider).unreadCount, 2);

        data.releaseList.complete();
        await pumpEventQueue(times: 5);

        expect(await store.list('owner-a'), isEmpty);
        expect(container.read(notificationControllerProvider).unreadCount, 2);
      },
    );

    test(
      'late A mark-all failure is contained and cannot change restored B UI',
      () async {
        final data = _FailingMarkWriteData();
        final store = NotificationStore(data);
        await _seedUnread(store, 'owner-a', 'a-1');
        await _seedUnread(store, 'owner-b', 'b-1');
        await _seedUnread(store, 'owner-b', 'b-2');
        final push = StreamController<PushMessage>();
        addTearDown(push.close);
        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(_FakePush(push)),
            currentOwnerKeyProvider.overrideWith(
              (ref) => ref.watch(_ownerProvider),
            ),
            notificationStoreProvider.overrideWithValue(store),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          notificationControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await pumpEventQueue();
        expect(container.read(notificationControllerProvider).unreadCount, 1);

        final uncaught = <Object>[];
        data.failNextMarkWrite = true;
        runZonedGuarded(
          () => container
              .read(notificationControllerProvider.notifier)
              .markAllRead(),
          (error, _) => uncaught.add(error),
        );
        await data.writeStarted.future;
        container.read(_ownerProvider.notifier).setOwner('owner-b');
        await pumpEventQueue();
        expect(container.read(notificationControllerProvider).unreadCount, 2);

        data.releaseWrite.complete();
        await pumpEventQueue(times: 5);

        expect(uncaught, isEmpty);
        expect(container.read(notificationControllerProvider).unreadCount, 2);
      },
    );

    test(
      'concurrent mark-all calls share one flight and preserve new unread',
      () async {
        final data = _ConcurrentMarkData();
        final store = NotificationStore(data);
        await _seedUnread(store, 'owner-a', 'a-1');
        final push = StreamController<PushMessage>();
        addTearDown(push.close);
        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(_FakePush(push)),
            currentOwnerKeyProvider.overrideWithValue('owner-a'),
            notificationStoreProvider.overrideWithValue(store),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          notificationControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await pumpEventQueue();
        expect(container.read(notificationControllerProvider).unreadCount, 1);

        data.blockMarkedWrites = true;
        final notifier = container.read(
          notificationControllerProvider.notifier,
        );
        final first = notifier.markAllRead();
        await data.firstMarkedWriteStarted.future;

        push.add(const PushMessage.local(id: 'a-2', title: 'new', body: 'new'));
        await pumpEventQueue();
        expect(container.read(notificationControllerProvider).unreadCount, 2);
        final second = notifier.markAllRead();
        await pumpEventQueue();

        data.releaseMarkedWrites.complete();
        await Future.wait([first, second]);

        expect(data.markedWriteCount, 1);
        expect(container.read(notificationControllerProvider).unreadCount, 1);
        expect(
          (await store.list('owner-a')).where((item) => !item.isRead),
          hasLength(1),
        );
      },
    );

    test(
      'cold/warm notification taps expose only typed native targets',
      () async {
        final push = _FakeInteractivePush(
          initial: const PushMessage.ownerScoped(
            id: 'cold',
            title: 'Today',
            body: '이어하기',
            intendedOwnerKey: 'owner-a',
            target: PushTarget.today(pathId: 301),
          ),
        );
        addTearDown(push.close);
        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(push),
            keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
            currentOwnerKeyProvider.overrideWithValue('owner-a'),
            notificationStoreProvider.overrideWithValue(
              NotificationStore(InMemoryOwnerDataStore()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          notificationControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await pumpEventQueue();
        expect(
          container
              .read(notificationControllerProvider)
              .navigationTarget
              ?.location,
          '/path/301/today',
        );
        container
            .read(notificationControllerProvider.notifier)
            .consumeNavigation();

        push.openedController.add(
          const PushMessage.ownerScoped(
            id: 'warm',
            title: 'Content',
            body: '이어하기',
            intendedOwnerKey: 'owner-a',
            target: PushTarget.content(taskId: 302, contentId: 77),
          ),
        );
        await pumpEventQueue();
        expect(
          container
              .read(notificationControllerProvider)
              .navigationTarget
              ?.location,
          '/mission/302/content/77',
        );
      },
    );

    test(
      'cold initial message waits for its verified owner during AuthLoading',
      () async {
        final push = _FakeInteractivePush(
          initial: const PushMessage.ownerScoped(
            id: 'cold-auth-loading',
            title: 'Today',
            body: '인증 복원 뒤 이어하기',
            intendedOwnerKey: 'owner-a',
            target: PushTarget.today(pathId: 301),
          ),
        );
        addTearDown(push.close);
        final data = InMemoryOwnerDataStore();
        final store = NotificationStore(data);
        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(push),
            keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
            authControllerProvider.overrideWith(
              _NotificationAuthController.new,
            ),
            notificationStoreProvider.overrideWithValue(store),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          notificationControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await pumpEventQueue();
        expect(
          container.read(notificationControllerProvider).messages,
          isEmpty,
        );

        final auth =
            container.read(authControllerProvider.notifier)
                as _NotificationAuthController;
        auth.authenticate('owner-a');
        await pumpEventQueue(times: 4);

        final state = container.read(notificationControllerProvider);
        expect(state.messages.map((message) => message.id), [
          'cold-auth-loading',
        ]);
        expect(state.unreadCount, 1);
        expect(state.navigationTarget?.location, '/path/301/today');
        expect(await store.list('owner-a'), hasLength(1));
      },
    );

    test(
      'warm opened message waits through retry Loading for matching owner',
      () async {
        final push = _FakeInteractivePush();
        addTearDown(push.close);
        final data = InMemoryOwnerDataStore();
        final store = NotificationStore(data);
        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(push),
            keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
            authControllerProvider.overrideWith(
              _NotificationAuthController.new,
            ),
            notificationStoreProvider.overrideWithValue(store),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          notificationControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        push.openedController.add(
          const PushMessage.ownerScoped(
            id: 'warm-auth-loading',
            title: 'Content',
            body: '인증 재시도 뒤 이어하기',
            intendedOwnerKey: 'owner-a',
            target: PushTarget.content(taskId: 302, contentId: 77),
          ),
        );
        await pumpEventQueue();
        expect(
          container.read(notificationControllerProvider).messages,
          isEmpty,
        );

        final auth =
            container.read(authControllerProvider.notifier)
                as _NotificationAuthController;
        auth.authenticate('owner-a');
        await pumpEventQueue(times: 4);

        final state = container.read(notificationControllerProvider);
        expect(state.messages.map((message) => message.id), [
          'warm-auth-loading',
        ]);
        expect(state.navigationTarget?.location, '/mission/302/content/77');
        expect(await store.list('owner-a'), hasLength(1));
      },
    );

    test('Loading push is discarded on unauthenticated terminal', () async {
      final push = _FakeInteractivePush();
      addTearDown(push.close);
      final data = InMemoryOwnerDataStore();
      final store = NotificationStore(data);
      final container = ProviderContainer(
        overrides: [
          pushServiceProvider.overrideWithValue(push),
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          authControllerProvider.overrideWith(_NotificationAuthController.new),
          notificationStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        notificationControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      push.openedController.add(
        const PushMessage.ownerScoped(
          id: 'loading-to-logout',
          title: 'Today',
          body: 'discard',
          intendedOwnerKey: 'owner-a',
          target: PushTarget.today(pathId: 301),
        ),
      );
      await pumpEventQueue();
      final auth =
          container.read(authControllerProvider.notifier)
              as _NotificationAuthController;
      auth.unauthenticate();
      await pumpEventQueue();
      auth.authenticate('owner-a');
      await pumpEventQueue(times: 3);

      expect(container.read(notificationControllerProvider).messages, isEmpty);
      expect(await store.list('owner-a'), isEmpty);
    });

    test(
      'Loading owner-A push is discarded when verified owner is B',
      () async {
        final push = _FakeInteractivePush();
        addTearDown(push.close);
        final data = InMemoryOwnerDataStore();
        final store = NotificationStore(data);
        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(push),
            keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
            authControllerProvider.overrideWith(
              _NotificationAuthController.new,
            ),
            notificationStoreProvider.overrideWithValue(store),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          notificationControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        push.openedController.add(
          const PushMessage.ownerScoped(
            id: 'loading-a-to-b',
            title: 'Today',
            body: 'discard',
            intendedOwnerKey: 'owner-a',
            target: PushTarget.today(pathId: 301),
          ),
        );
        await pumpEventQueue();
        final auth =
            container.read(authControllerProvider.notifier)
                as _NotificationAuthController;
        auth.authenticate('owner-b');
        await pumpEventQueue(times: 4);

        expect(
          container.read(notificationControllerProvider).messages,
          isEmpty,
        );
        expect(await store.list('owner-a'), isEmpty);
        expect(await store.list('owner-b'), isEmpty);
      },
    );

    test(
      'owner epoch transition clears in-memory notifications and badge',
      () async {
        final pushController = StreamController<PushMessage>();
        addTearDown(pushController.close);
        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(_FakePush(pushController)),
            keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
            currentOwnerKeyProvider.overrideWith(
              (ref) => ref.watch(_ownerProvider),
            ),
            notificationStoreProvider.overrideWithValue(
              NotificationStore(InMemoryOwnerDataStore()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          notificationControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        pushController.add(
          const PushMessage.local(id: '1', title: 'A', body: 'a'),
        );
        await pumpEventQueue();
        expect(container.read(notificationControllerProvider).unreadCount, 1);

        container.read(_ownerProvider.notifier).setOwner(null);
        await pumpEventQueue();
        final state = container.read(notificationControllerProvider);
        expect(state.messages, isEmpty);
        expect(state.unreadCount, 0);
      },
    );

    test('owner-null 상태에서 누른 A 알림은 다음 B owner에게 승계되지 않는다', () async {
      final push = _FakeInteractivePush();
      addTearDown(push.close);
      final data = InMemoryOwnerDataStore();
      final container = ProviderContainer(
        overrides: [
          pushServiceProvider.overrideWithValue(push),
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          currentOwnerKeyProvider.overrideWith(
            (ref) => ref.watch(_ownerProvider),
          ),
          notificationStoreProvider.overrideWithValue(NotificationStore(data)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        notificationControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      container.read(_ownerProvider.notifier).setOwner(null);
      push.openedController.add(
        const PushMessage.ownerScoped(
          id: 'owner-a-after-logout',
          title: 'A 전용',
          body: 'B에게 보이면 안 됨',
          intendedOwnerKey: 'owner-a',
          target: PushTarget.today(pathId: 301),
        ),
      );
      await pumpEventQueue();
      container.read(_ownerProvider.notifier).setOwner('owner-b');
      await pumpEventQueue();

      final state = container.read(notificationControllerProvider);
      expect(state.messages, isEmpty);
      expect(state.unreadCount, 0);
      expect(state.navigationTarget, isNull);
      expect(await NotificationStore(data).list('owner-b'), isEmpty);
    });

    test('A tap persist가 지연된 사이 B로 바뀌면 A target을 열지 않는다', () async {
      final push = _FakeInteractivePush();
      addTearDown(push.close);
      final data = _DelayedNotificationData();
      final container = ProviderContainer(
        overrides: [
          pushServiceProvider.overrideWithValue(push),
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          currentOwnerKeyProvider.overrideWith(
            (ref) => ref.watch(_ownerProvider),
          ),
          notificationStoreProvider.overrideWithValue(NotificationStore(data)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        notificationControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      push.openedController.add(
        const PushMessage.ownerScoped(
          id: 'late-owner-a',
          title: 'A 전용',
          body: '지연',
          intendedOwnerKey: 'owner-a',
          target: PushTarget.content(taskId: 302, contentId: 77),
        ),
      );
      await data.writeStarted.future;
      container.read(_ownerProvider.notifier).setOwner('owner-b');
      data.releaseWrite.complete();
      await data.staleDiscarded.future;

      final state = container.read(notificationControllerProvider);
      expect(state.messages, isEmpty);
      expect(state.navigationTarget, isNull);
      expect(await NotificationStore(data).list('owner-a'), isEmpty);
      expect(await NotificationStore(data).list('owner-b'), isEmpty);
    });
  });
}

Future<void> _seedUnread(NotificationStore store, String ownerKey, String id) =>
    store.add(
      ownerKey,
      PushMessage.local(id: id, title: id, body: 'body'),
      receivedAt: DateTime.utc(2026, 8, 16, 12, 0, id.hashCode.abs() % 60),
    );
