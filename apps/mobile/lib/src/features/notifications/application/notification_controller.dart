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
  var _ownerEpoch = 0;
  final _markAllReadFlights = <String, Future<void>>{};

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

  Future<bool> _persist(
    PushMessage message, {
    _NotificationOwnerBoundary? boundary,
  }) async {
    final captured = boundary ?? await _captureBoundary(message);
    if (captured == null || message.id.isEmpty) return false;
    final store = ref.read(notificationStoreProvider);
    final receivedAt = DateTime.now().toUtc();
    final added = await store.add(
      captured.ownerKey,
      message,
      receivedAt: receivedAt,
    );
    if (!_isCurrent(captured)) {
      if (added) {
        await store.discardIfMatches(
          captured.ownerKey,
          message,
          receivedAt: receivedAt,
        );
      }
      return false;
    }
    if (added) {
      state = NotificationState(
        messages: [message, ...state.messages],
        unreadCount: state.unreadCount + 1,
        navigationTarget: state.navigationTarget,
      );
    }
    return true;
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
    final boundary = await _captureBoundary(message);
    if (boundary == null || !await _persist(message, boundary: boundary)) {
      return;
    }
    if (message.target == null || !_isCurrent(boundary)) return;
    state = NotificationState(
      messages: state.messages,
      unreadCount: state.unreadCount,
      navigationTarget: message.target,
    );
  }

  Future<_NotificationOwnerBoundary?> _captureBoundary(
    PushMessage message,
  ) async {
    final owner = _ownerKey;
    final memoryEpoch = _ownerEpoch;
    if (owner == null || !_matchesIntendedOwner(message, owner)) return null;
    final boundary = _NotificationOwnerBoundary(
      ownerKey: owner,
      memoryEpoch: memoryEpoch,
    );
    return _isCurrent(boundary) ? boundary : null;
  }

  bool _isCurrent(_NotificationOwnerBoundary boundary) =>
      ref.mounted &&
      boundary.ownerKey == _ownerKey &&
      boundary.memoryEpoch == _ownerEpoch &&
      ref.read(currentOwnerKeyProvider) == boundary.ownerKey;

  bool _matchesIntendedOwner(PushMessage message, String ownerKey) {
    return message.isForOwner(ownerKey);
  }

  void open(PushMessage message) {
    final owner = _ownerKey;
    if (owner == null || !message.isForOwner(owner)) return;
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

  Future<void> markAllRead() {
    if (state.unreadCount == 0) return Future<void>.value();
    final owner = _ownerKey;
    if (owner == null) return Future<void>.value();
    final boundary = _NotificationOwnerBoundary(
      ownerKey: owner,
      memoryEpoch: _ownerEpoch,
    );
    final capturedUnreadCount = state.unreadCount;
    final flightKey = '${boundary.ownerKey}\u0000${boundary.memoryEpoch}';
    final active = _markAllReadFlights[flightKey];
    if (active != null) return active;
    late final Future<void> operation;
    operation = _markAllRead(boundary, capturedUnreadCount).whenComplete(() {
      if (identical(_markAllReadFlights[flightKey], operation)) {
        _markAllReadFlights.remove(flightKey);
      }
    });
    _markAllReadFlights[flightKey] = operation;
    return operation;
  }

  Future<void> _markAllRead(
    _NotificationOwnerBoundary boundary,
    int capturedUnreadCount,
  ) async {
    try {
      await ref
          .read(notificationStoreProvider)
          .markAllRead(
            boundary.ownerKey,
            isCurrent: () => _isCurrent(boundary),
          );
    } on Object {
      // Reading notifications must remain usable if durable marking fails.
      return;
    }
    if (!_isCurrent(boundary)) return;
    final latest = state;
    final unreadCount = latest.unreadCount > capturedUnreadCount
        ? latest.unreadCount - capturedUnreadCount
        : 0;
    state = NotificationState(
      messages: latest.messages,
      unreadCount: unreadCount,
      navigationTarget: latest.navigationTarget,
      isRestoring: latest.isRestoring,
    );
  }
}

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );

final class _NotificationOwnerBoundary {
  const _NotificationOwnerBoundary({
    required this.ownerKey,
    required this.memoryEpoch,
  });

  final String ownerKey;
  final int memoryEpoch;
}
