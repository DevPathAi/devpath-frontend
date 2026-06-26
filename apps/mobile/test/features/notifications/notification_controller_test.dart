import 'dart:async';

import 'package:devpath_mobile/src/features/notifications/application/notification_controller.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
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

({ProviderContainer container, StreamController<PushMessage> push}) _setup() {
  final ctrl = StreamController<PushMessage>();
  addTearDown(ctrl.close);
  final c = ProviderContainer(
    overrides: [pushServiceProvider.overrideWithValue(_FakePush(ctrl))],
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

    test('수신 메시지는 최신순으로 누적되고 미읽음이 증가한다', () async {
      final (:container, :push) = _setup();
      // 화면(ref.watch)처럼 활성 구독해 build()의 incoming 리스너를 유지.
      final sub = container.listen(notificationControllerProvider, (_, _) {});
      addTearDown(sub.close);

      push.add(const PushMessage(id: '1', title: '첫 알림', body: '본문1'));
      push.add(const PushMessage(id: '2', title: '둘째 알림', body: '본문2'));
      await pumpEventQueue();

      final s = container.read(notificationControllerProvider);
      expect(s.messages.map((m) => m.id).toList(), ['2', '1']);
      expect(s.unreadCount, 2);
    });

    test('markAllRead는 미읽음을 0으로 만들고 목록은 유지한다', () async {
      final (:container, :push) = _setup();
      final sub = container.listen(notificationControllerProvider, (_, _) {});
      addTearDown(sub.close);

      push.add(const PushMessage(id: '1', title: 'A', body: 'a'));
      await pumpEventQueue();
      expect(container.read(notificationControllerProvider).unreadCount, 1);

      container.read(notificationControllerProvider.notifier).markAllRead();

      final s = container.read(notificationControllerProvider);
      expect(s.unreadCount, 0);
      expect(s.messages, hasLength(1));
    });
  });
}
