import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/push_service.dart';
import '../application/notification_controller.dart';

/// 알림센터 — 포그라운드 수신 푸시 목록. 진입 시 미읽음을 읽음 처리(배지 해제).
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(notificationControllerProvider.notifier).markAllRead(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(
      notificationControllerProvider.select((s) => s.messages),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: messages.isEmpty
          ? const DpEmpty(
              icon: DpIcons.notifications,
              title: '알림이 없어요',
              message: '새 소식이 도착하면 여기에 표시됩니다.',
            )
          : ListView.separated(
              itemCount: messages.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _NotificationTile(message: messages[i]),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.message});

  final PushMessage message;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(DpIcons.notifications),
      title: Text(message.title),
      subtitle: Text(message.body),
    );
  }
}
