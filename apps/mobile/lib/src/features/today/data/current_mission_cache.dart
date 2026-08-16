import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';

final class CachedCurrentMission {
  const CachedCurrentMission({required this.mission, required this.cachedAt});

  final CurrentMission mission;
  final DateTime cachedAt;
}

abstract interface class CurrentMissionCache {
  static const maxOfflineAge = Duration(hours: 24);

  Future<CachedCurrentMission?> read(String ownerKey, {required DateTime now});

  Future<void> write(
    String ownerKey,
    CurrentMission mission, {
    required DateTime cachedAt,
  });

  Future<void> clearIfMatches(
    String ownerKey,
    CurrentMission mission, {
    required DateTime cachedAt,
  });

  Future<void> clearOwner(String ownerKey);
}

class InMemoryCurrentMissionCache implements CurrentMissionCache {
  final _entries = <String, CachedCurrentMission>{};

  @override
  Future<CachedCurrentMission?> read(
    String ownerKey, {
    required DateTime now,
  }) async {
    final entry = _entries[ownerKey];
    if (entry == null || !_isFresh(entry.cachedAt, now)) {
      _entries.remove(ownerKey);
      return null;
    }
    return entry;
  }

  @override
  Future<void> write(
    String ownerKey,
    CurrentMission mission, {
    required DateTime cachedAt,
  }) async {
    _entries[ownerKey] = CachedCurrentMission(
      mission: mission,
      cachedAt: cachedAt,
    );
  }

  @override
  Future<void> clearIfMatches(
    String ownerKey,
    CurrentMission mission, {
    required DateTime cachedAt,
  }) async {
    final entry = _entries[ownerKey];
    if (entry?.cachedAt == cachedAt && entry?.mission == mission) {
      _entries.remove(ownerKey);
    }
  }

  @override
  Future<void> clearOwner(String ownerKey) async => _entries.remove(ownerKey);
}

class DriftCurrentMissionCache implements CurrentMissionCache {
  DriftCurrentMissionCache(this._db);

  final AppDatabase _db;

  @override
  Future<CachedCurrentMission?> read(
    String ownerKey, {
    required DateTime now,
  }) async {
    final row = await (_db.select(
      _db.currentMissionCacheRows,
    )..where((table) => table.ownerKey.equals(ownerKey))).getSingleOrNull();
    if (row == null) return null;
    if (!_isFresh(row.cachedAt, now)) {
      await clearOwner(ownerKey);
      return null;
    }
    try {
      return CachedCurrentMission(
        mission: CurrentMissionCacheCodec.decode(row.payload),
        cachedAt: row.cachedAt,
      );
    } on Object {
      await clearOwner(ownerKey);
      return null;
    }
  }

  @override
  Future<void> write(
    String ownerKey,
    CurrentMission mission, {
    required DateTime cachedAt,
  }) async {
    await _db
        .into(_db.currentMissionCacheRows)
        .insertOnConflictUpdate(
          CurrentMissionCacheRowsCompanion.insert(
            ownerKey: ownerKey,
            payload: CurrentMissionCacheCodec.encode(mission),
            cachedAt: cachedAt,
          ),
        );
  }

  @override
  Future<void> clearIfMatches(
    String ownerKey,
    CurrentMission mission, {
    required DateTime cachedAt,
  }) async {
    await (_db.delete(_db.currentMissionCacheRows)..where(
          (table) =>
              table.ownerKey.equals(ownerKey) &
              table.payload.equals(CurrentMissionCacheCodec.encode(mission)) &
              table.cachedAt.equals(cachedAt),
        ))
        .go();
  }

  @override
  Future<void> clearOwner(String ownerKey) async {
    await (_db.delete(
      _db.currentMissionCacheRows,
    )..where((table) => table.ownerKey.equals(ownerKey))).go();
    // Schema v1 had one ownerless dashboard row. It cannot be attributed
    // safely, so the first account cleanup removes it instead of migrating it.
    await _db.delete(_db.dashboardCacheRows).go();
  }
}

bool _isFresh(DateTime cachedAt, DateTime now) {
  final age = now.difference(cachedAt);
  return !age.isNegative && age < CurrentMissionCache.maxOfflineAge;
}

abstract final class CurrentMissionCacheCodec {
  static String encode(CurrentMission mission) => jsonEncode(_toJson(mission));

  static CurrentMission decode(String payload) {
    final decoded = jsonDecode(payload);
    final mission = CurrentMission.fromJson(decoded);
    if (mission.outcome == CurrentMissionOutcome.malformedPath &&
        decoded is Map &&
        decoded['outcome'] != 'MALFORMED_PATH') {
      throw const FormatException('invalid cached CurrentMission');
    }
    return mission;
  }

  static Map<String, Object?> _toJson(CurrentMission mission) =>
      switch (mission.outcome) {
        CurrentMissionOutcome.available => {
          'outcome': 'AVAILABLE',
          'pathId': mission.pathId,
          'weekNum': mission.weekNum,
          'tasks': mission.tasks.map(_taskToJson).toList(),
          'nextTask': _taskToJson(mission.nextTask!),
          'pathCompleted': false,
        },
        CurrentMissionOutcome.pathCompleted => {
          'outcome': 'PATH_COMPLETED',
          'pathId': mission.pathId,
          'weekNum': mission.weekNum,
          'tasks': mission.tasks.map(_taskToJson).toList(),
          'nextTask': null,
          'pathCompleted': true,
        },
        CurrentMissionOutcome.noActivePath => {
          'outcome': 'NO_ACTIVE_PATH',
          'pathId': null,
          'weekNum': null,
          'tasks': <Object?>[],
          'nextTask': null,
          'pathCompleted': false,
        },
        CurrentMissionOutcome.malformedPath => {'outcome': 'MALFORMED_PATH'},
      };

  static Map<String, Object?> _taskToJson(WeeklyTask task) => {
    'taskId': task.taskId,
    'orderNum': task.orderNum,
    'taskType': task.taskType,
    'title': task.title,
    'required': task.required,
    'contentId': task.contentId,
    'contentSlug': task.contentSlug,
    'completed': task.completed,
    'completedAt': task.completedAt?.toUtc().toIso8601String(),
  };
}

final currentMissionCacheProvider = Provider<CurrentMissionCache>(
  (ref) => DriftCurrentMissionCache(ref.watch(appDatabaseProvider)),
);
