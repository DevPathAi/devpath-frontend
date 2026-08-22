import '../../../services/push_service.dart';

/// 알림센터 상태. [messages]는 최신순(맨 앞이 가장 최근),
/// [unreadCount]는 미읽음 배지 개수.
class NotificationState {
  const NotificationState({
    this.messages = const [],
    this.unreadCount = 0,
    this.navigationTarget,
    this.isRestoring = false,
  });

  final List<PushMessage> messages;
  final int unreadCount;
  final PushTarget? navigationTarget;
  final bool isRestoring;
}
