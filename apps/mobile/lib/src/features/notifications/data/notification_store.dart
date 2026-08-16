import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/owner_data_store.dart';
import '../../../services/push_service.dart';

final class StoredNotification {
  const StoredNotification({
    required this.message,
    required this.receivedAt,
    required this.isRead,
  });

  final PushMessage message;
  final DateTime receivedAt;
  final bool isRead;
}

class NotificationStore {
  NotificationStore(this._data);

  static const bucket = 'notification-v1';
  final OwnerDataStore _data;
  final _addTails = <String, Future<void>>{};

  Future<bool> add(
    String ownerKey,
    PushMessage message, {
    required DateTime receivedAt,
  }) {
    if (message.id.isEmpty) return Future.value(false);
    final key = '$ownerKey\u0000${message.id}';
    final previous = _addTails[key] ?? Future<void>.value();
    final result = previous.then((_) async {
      if (await _data.read(ownerKey, bucket, message.id) != null) return false;
      await _write(
        ownerKey,
        StoredNotification(
          message: message,
          receivedAt: receivedAt,
          isRead: false,
        ),
      );
      return true;
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _addTails[key] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_addTails[key], tail)) _addTails.remove(key);
      }),
    );
    return result;
  }

  Future<List<StoredNotification>> list(String ownerKey) async {
    final rows = await _data.list(ownerKey, bucket);
    final result = <StoredNotification>[];
    for (final row in rows) {
      try {
        result.add(_decode(row.payload));
      } on Object {
        await _data.delete(ownerKey, bucket, row.recordKey);
      }
    }
    result.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return result;
  }

  Future<void> markAllRead(String ownerKey) async {
    for (final notification in await list(ownerKey)) {
      if (!notification.isRead) {
        await _write(
          ownerKey,
          StoredNotification(
            message: notification.message,
            receivedAt: notification.receivedAt,
            isRead: true,
          ),
        );
      }
    }
  }

  Future<void> _write(String ownerKey, StoredNotification notification) {
    final target = notification.message.target;
    return _data.write(
      ownerKey,
      bucket,
      notification.message.id,
      jsonEncode({
        'id': notification.message.id,
        'title': notification.message.title,
        'body': notification.message.body,
        'targetType': target?.kind.name,
        'primaryId': target?.primaryId,
        'secondaryId': target?.secondaryId,
        'receivedAt': notification.receivedAt.toUtc().toIso8601String(),
        'isRead': notification.isRead,
      }),
      updatedAt: notification.receivedAt,
    );
  }

  StoredNotification _decode(String payload) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final target = switch (json['targetType']) {
      'today' => PushTarget.today(pathId: (json['primaryId'] as num).toInt()),
      'content' => PushTarget.content(
        taskId: (json['primaryId'] as num).toInt(),
        contentId: (json['secondaryId'] as num).toInt(),
      ),
      _ => null,
    };
    return StoredNotification(
      message: PushMessage(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        target: target,
      ),
      receivedAt: DateTime.parse(json['receivedAt'] as String).toUtc(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

final notificationStoreProvider = Provider<NotificationStore>(
  (ref) => NotificationStore(ref.watch(ownerDataStoreProvider)),
);
