import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/owner_data_store.dart';

final class CachedLearningContent {
  const CachedLearningContent({required this.content, required this.cachedAt});

  final LearningContent content;
  final DateTime cachedAt;
}

class ContentOfflineStore {
  ContentOfflineStore(this._data);

  static const bucket = 'content-cache-v1';
  static const maxOfflineAge = Duration(hours: 24);
  final OwnerDataStore _data;
  final _mutationTails = <String, Future<void>>{};

  Future<CachedLearningContent?> read(
    String ownerKey,
    String routeKey, {
    required DateTime now,
  }) async {
    final row = await _data.read(ownerKey, bucket, routeKey);
    if (row == null) return null;
    final age = now.difference(row.updatedAt);
    if (age.isNegative || age >= maxOfflineAge) {
      await _data.deleteIfMatches(
        ownerKey,
        bucket,
        routeKey,
        payload: row.payload,
        updatedAt: row.updatedAt,
      );
      return null;
    }
    try {
      final content = LearningContent.fromJson(
        jsonDecode(row.payload) as Map<String, dynamic>,
      );
      if (content.slug != routeKey && content.id.toString() != routeKey) {
        throw const FormatException('content identity mismatch');
      }
      return CachedLearningContent(content: content, cachedAt: row.updatedAt);
    } on Object {
      await _data.deleteIfMatches(
        ownerKey,
        bucket,
        routeKey,
        payload: row.payload,
        updatedAt: row.updatedAt,
      );
      return null;
    }
  }

  Future<void> write(
    String ownerKey,
    String routeKey,
    LearningContent content, {
    required DateTime cachedAt,
  }) => _serialize(
    ownerKey,
    routeKey,
    () => _write(ownerKey, routeKey, content, cachedAt: cachedAt),
  );

  Future<void> applyServerProgress(
    String ownerKey,
    String routeKey,
    ContentProgressUpdateResponse response,
  ) => _serialize(ownerKey, routeKey, () async {
    final row = await _data.read(ownerKey, bucket, routeKey);
    if (row == null) return;
    try {
      final content = LearningContent.fromJson(
        jsonDecode(row.payload) as Map<String, dynamic>,
      );
      final previous = content.progress;
      final updated = content.copyWith(
        progress: ContentProgress(
          scrollPct: math.max(previous.scrollPct, response.scrollPct),
          dwellSec: math.max(previous.dwellSec, response.dwellSec),
          completed: previous.completed || response.completed,
          completedAt: response.completedAt ?? previous.completedAt,
        ),
      );
      await _write(ownerKey, routeKey, updated, cachedAt: row.updatedAt);
    } on Object {
      await _data.delete(ownerKey, bucket, routeKey);
    }
  });

  Future<void> _write(
    String ownerKey,
    String routeKey,
    LearningContent content, {
    required DateTime cachedAt,
  }) => _data.write(
    ownerKey,
    bucket,
    routeKey,
    jsonEncode(content.toJson()),
    updatedAt: cachedAt,
  );

  Future<T> _serialize<T>(
    String ownerKey,
    String routeKey,
    Future<T> Function() mutation,
  ) {
    final key = '$ownerKey\u0000$routeKey';
    final previous = _mutationTails[key] ?? Future<void>.value();
    final result = previous.then((_) => mutation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _mutationTails[key] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_mutationTails[key], tail)) {
          _mutationTails.remove(key);
        }
      }),
    );
    return result;
  }
}

final class QueuedContentProgress {
  const QueuedContentProgress({
    required this.ownerKey,
    required this.routeKey,
    required this.scrollPct,
    required this.dwellSec,
    required this.requestCompletion,
  });

  final String ownerKey;
  final String routeKey;
  final double scrollPct;
  final int dwellSec;
  final bool requestCompletion;

  Map<String, Object?> toJson() => {
    'ownerKey': ownerKey,
    'routeKey': routeKey,
    'scrollPct': scrollPct,
    'dwellSec': dwellSec,
    'requestCompletion': requestCompletion,
  };

  factory QueuedContentProgress.fromJson(Map<String, dynamic> json) =>
      QueuedContentProgress(
        ownerKey: json['ownerKey'] as String,
        routeKey: json['routeKey'] as String,
        scrollPct: (json['scrollPct'] as num).toDouble(),
        dwellSec: (json['dwellSec'] as num).toInt(),
        requestCompletion: json['requestCompletion'] as bool? ?? false,
      );
}

/// One durable, deduplicated row per owner+content route. Local values only
/// move forward; `completed` is never inferred locally and is applied only
/// from the server response by the controller/synchronizer.
class ContentProgressQueue {
  ContentProgressQueue(this._data);

  static const bucket = 'content-progress-queue-v1';
  final OwnerDataStore _data;
  final _mutationTails = <String, Future<void>>{};

  Future<QueuedContentProgress> enqueue(QueuedContentProgress incoming) =>
      _serialize(incoming.ownerKey, incoming.routeKey, () async {
        final previous = await read(incoming.ownerKey, incoming.routeKey);
        final merged = QueuedContentProgress(
          ownerKey: incoming.ownerKey,
          routeKey: incoming.routeKey,
          scrollPct: math.max(previous?.scrollPct ?? 0, incoming.scrollPct),
          dwellSec: math.max(previous?.dwellSec ?? 0, incoming.dwellSec),
          requestCompletion:
              (previous?.requestCompletion ?? false) ||
              incoming.requestCompletion,
        );
        await _data.write(
          incoming.ownerKey,
          bucket,
          incoming.routeKey,
          jsonEncode(merged.toJson()),
        );
        return merged;
      });

  Future<QueuedContentProgress?> read(String ownerKey, String routeKey) async {
    final row = await _data.read(ownerKey, bucket, routeKey);
    if (row == null) return null;
    try {
      final pending = QueuedContentProgress.fromJson(
        jsonDecode(row.payload) as Map<String, dynamic>,
      );
      if (pending.ownerKey != ownerKey || pending.routeKey != routeKey) {
        throw const FormatException('progress queue identity mismatch');
      }
      return pending;
    } on Object {
      await _data.deleteIfMatches(
        ownerKey,
        bucket,
        routeKey,
        payload: row.payload,
        updatedAt: row.updatedAt,
      );
      return null;
    }
  }

  Future<List<QueuedContentProgress>> list(String ownerKey) async {
    final rows = await _data.list(ownerKey, bucket);
    final result = <QueuedContentProgress>[];
    for (final row in rows) {
      try {
        final pending = QueuedContentProgress.fromJson(
          jsonDecode(row.payload) as Map<String, dynamic>,
        );
        if (pending.ownerKey == ownerKey && pending.routeKey == row.recordKey) {
          result.add(pending);
        }
      } on Object {
        await _data.deleteIfMatches(
          ownerKey,
          bucket,
          row.recordKey,
          payload: row.payload,
          updatedAt: row.updatedAt,
        );
      }
    }
    return result;
  }

  Future<void> remove(String ownerKey, String routeKey) =>
      _data.delete(ownerKey, bucket, routeKey);

  Future<bool> acknowledge(QueuedContentProgress sent) {
    return _removeIfMatches(sent);
  }

  /// Discards a permanent failure only if the queued row is still exactly the
  /// request that failed. A newer monotonic enqueue remains durable.
  Future<bool> discardIfMatches(QueuedContentProgress sent) {
    return _removeIfMatches(sent);
  }

  Future<bool> _removeIfMatches(QueuedContentProgress sent) {
    return _serialize(sent.ownerKey, sent.routeKey, () async {
      final latest = await read(sent.ownerKey, sent.routeKey);
      if (latest == null) return true;
      final unchanged =
          latest.scrollPct == sent.scrollPct &&
          latest.dwellSec == sent.dwellSec &&
          latest.requestCompletion == sent.requestCompletion;
      if (unchanged) {
        await _data.delete(sent.ownerKey, bucket, sent.routeKey);
      }
      return unchanged;
    });
  }

  Future<T> _serialize<T>(
    String ownerKey,
    String routeKey,
    Future<T> Function() mutation,
  ) {
    final key = '$ownerKey\u0000$routeKey';
    final previous = _mutationTails[key] ?? Future<void>.value();
    final result = previous.then((_) => mutation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _mutationTails[key] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_mutationTails[key], tail)) {
          _mutationTails.remove(key);
        }
      }),
    );
    return result;
  }
}

final contentOfflineStoreProvider = Provider<ContentOfflineStore>(
  (ref) => ContentOfflineStore(ref.watch(ownerDataStoreProvider)),
);

final contentProgressQueueProvider = Provider<ContentProgressQueue>(
  (ref) => ContentProgressQueue(ref.watch(ownerDataStoreProvider)),
);
