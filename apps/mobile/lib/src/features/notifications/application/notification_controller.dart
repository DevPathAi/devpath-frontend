import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/push_service.dart';
import '../../auth/application/auth_controller.dart';
import '../data/notification_store.dart';
import '../state/notification_state.dart';

/// 알림센터 컨트롤러.
/// - [PushService.incoming] 구독 → 수신 메시지를 최신순 누적 + 미읽음 증가.
/// - [markAllRead]: 화면 진입 시 미읽음을 0으로(목록은 보존).
///
/// 실 FCM 전환 시에도 이 컨트롤러는 그대로 — `pushServiceProvider`만 교체된다.
class NotificationController extends Notifier<NotificationState> {
  StreamSubscription<PushMessage>? _sub;
  StreamSubscription<PushMessage>? _openedSub;
  String? _ownerKey;
  PushMessage? _deferredOpened;
  var _ownerEpoch = 0;

  @override
  NotificationState build() {
    _ownerKey = ref.read(currentOwnerKeyProvider);
    final push = ref.read(pushServiceProvider);
    _sub = push.incoming.listen(_onMessage);
    final interactions = push is PushInteractionService
        ? push as PushInteractionService
        : null;
    if (interactions != null) {
      _openedSub = interactions.opened.listen(_onOpened);
      Future.microtask(() async {
        final initial = await interactions.initialMessage();
        if (initial != null) await _onOpened(initial);
      });
    }
    ref.listen(currentOwnerKeyProvider, (_, owner) {
      if (owner == _ownerKey) return;
      _ownerKey = owner;
      _ownerEpoch += 1;
      state = NotificationState(isRestoring: owner != null);
      if (owner != null) {
        unawaited(_restore(owner, _ownerEpoch));
        final deferred = _deferredOpened;
        _deferredOpened = null;
        if (deferred != null) unawaited(_onOpened(deferred));
      }
    });
    ref.onDispose(() {
      _ownerEpoch += 1;
      _sub?.cancel();
      _openedSub?.cancel();
    });
    if (_ownerKey != null) {
      Future.microtask(() => _restore(_ownerKey!, _ownerEpoch));
      return const NotificationState(isRestoring: true);
    }
    return const NotificationState();
  }

  void _onMessage(PushMessage message) => unawaited(_persist(message));

  Future<void> _persist(PushMessage message) async {
    final owner = _ownerKey;
    final epoch = _ownerEpoch;
    if (owner == null || message.id.isEmpty) return;
    final added = await ref
        .read(notificationStoreProvider)
        .add(owner, message, receivedAt: DateTime.now().toUtc());
    if (!ref.mounted || owner != _ownerKey || epoch != _ownerEpoch || !added) {
      return;
    }
    state = NotificationState(
      messages: [message, ...state.messages],
      unreadCount: state.unreadCount + 1,
      navigationTarget: state.navigationTarget,
    );
  }

  Future<void> _restore(String owner, int epoch) async {
    final saved = await ref.read(notificationStoreProvider).list(owner);
    if (!ref.mounted || owner != _ownerKey || epoch != _ownerEpoch) return;
    state = NotificationState(
      messages: saved.map((item) => item.message).toList(),
      unreadCount: saved.where((item) => !item.isRead).length,
      navigationTarget: state.navigationTarget,
    );
  }

  Future<void> _onOpened(PushMessage message) async {
    if (_ownerKey == null) {
      _deferredOpened = message;
      return;
    }
    await _persist(message);
    if (!ref.mounted || message.target == null || _ownerKey == null) return;
    state = NotificationState(
      messages: state.messages,
      unreadCount: state.unreadCount,
      navigationTarget: message.target,
    );
  }

  void open(PushMessage message) {
    final target = message.target;
    if (target == null) return;
    state = NotificationState(
      messages: state.messages,
      unreadCount: state.unreadCount,
      navigationTarget: target,
    );
  }

  void consumeNavigation() {
    if (state.navigationTarget == null) return;
    state = NotificationState(
      messages: state.messages,
      unreadCount: state.unreadCount,
    );
  }

  void markAllRead() {
    if (state.unreadCount == 0) return;
    state = NotificationState(messages: state.messages);
    final owner = _ownerKey;
    if (owner != null) {
      unawaited(ref.read(notificationStoreProvider).markAllRead(owner));
    }
  }
}

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );
