import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/push_service.dart';
import '../state/notification_state.dart';

/// 알림센터 컨트롤러.
/// - [PushService.incoming] 구독 → 수신 메시지를 최신순 누적 + 미읽음 증가.
/// - [markAllRead]: 화면 진입 시 미읽음을 0으로(목록은 보존).
///
/// 실 FCM 전환 시에도 이 컨트롤러는 그대로 — `pushServiceProvider`만 교체된다.
class NotificationController extends Notifier<NotificationState> {
  StreamSubscription<PushMessage>? _sub;

  @override
  NotificationState build() {
    _sub = ref.read(pushServiceProvider).incoming.listen(_onMessage);
    ref.onDispose(() => _sub?.cancel());
    return const NotificationState();
  }

  void _onMessage(PushMessage m) {
    state = NotificationState(
      messages: [m, ...state.messages],
      unreadCount: state.unreadCount + 1,
    );
  }

  void markAllRead() {
    if (state.unreadCount == 0) return;
    state = NotificationState(messages: state.messages);
  }
}

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );
