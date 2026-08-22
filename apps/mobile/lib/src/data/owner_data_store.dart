import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local/app_database.dart';
import '../features/auth/application/account_epoch_store.dart';

final class OwnerDataRecord {
  const OwnerDataRecord({
    required this.ownerKey,
    required this.bucket,
    required this.recordKey,
    required this.payload,
    required this.updatedAt,
  });

  final String ownerKey;
  final String bucket;
  final String recordKey;
  final String payload;
  final DateTime updatedAt;
}

abstract interface class OwnerDataStore {
  Future<OwnerDataRecord?> read(
    String ownerKey,
    String bucket,
    String recordKey,
  );

  Future<List<OwnerDataRecord>> list(String ownerKey, [String? bucket]);

  Future<void> write(
    String ownerKey,
    String bucket,
    String recordKey,
    String payload, {
    DateTime? updatedAt,
  });

  Future<void> delete(String ownerKey, String bucket, String recordKey);

  /// Deletes only the exact write identified by its value and timestamp.
  /// Used by epoch cleanup so an older completion cannot remove a newer row.
  Future<void> deleteIfMatches(
    String ownerKey,
    String bucket,
    String recordKey, {
    required String payload,
    required DateTime updatedAt,
  });

  Future<void> clearOwner(String ownerKey);
}

class InMemoryOwnerDataStore implements OwnerDataStore {
  final _records = <String, OwnerDataRecord>{};

  String _key(String owner, String bucket, String record) =>
      '$owner\u0000$bucket\u0000$record';

  @override
  Future<OwnerDataRecord?> read(
    String ownerKey,
    String bucket,
    String recordKey,
  ) async => _records[_key(ownerKey, bucket, recordKey)];

  @override
  Future<List<OwnerDataRecord>> list(String ownerKey, [String? bucket]) async =>
      _records.values
          .where(
            (record) =>
                record.ownerKey == ownerKey &&
                (bucket == null || record.bucket == bucket),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> write(
    String ownerKey,
    String bucket,
    String recordKey,
    String payload, {
    DateTime? updatedAt,
  }) async {
    _records[_key(ownerKey, bucket, recordKey)] = OwnerDataRecord(
      ownerKey: ownerKey,
      bucket: bucket,
      recordKey: recordKey,
      payload: payload,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> delete(String ownerKey, String bucket, String recordKey) async {
    _records.remove(_key(ownerKey, bucket, recordKey));
  }

  @override
  Future<void> deleteIfMatches(
    String ownerKey,
    String bucket,
    String recordKey, {
    required String payload,
    required DateTime updatedAt,
  }) async {
    final key = _key(ownerKey, bucket, recordKey);
    final record = _records[key];
    if (record?.payload == payload && record?.updatedAt == updatedAt) {
      _records.remove(key);
    }
  }

  @override
  Future<void> clearOwner(String ownerKey) async {
    _records.removeWhere((_, record) => record.ownerKey == ownerKey);
  }
}

class DriftOwnerDataStore implements OwnerDataStore {
  DriftOwnerDataStore(this._db);

  final AppDatabase _db;

  @override
  Future<OwnerDataRecord?> read(
    String ownerKey,
    String bucket,
    String recordKey,
  ) async {
    final row =
        await (_db.select(_db.ownerDataRows)..where(
              (table) =>
                  table.ownerKey.equals(ownerKey) &
                  table.bucket.equals(bucket) &
                  table.recordKey.equals(recordKey),
            ))
            .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<OwnerDataRecord>> list(String ownerKey, [String? bucket]) async {
    final query = _db.select(_db.ownerDataRows)
      ..where(
        (table) =>
            table.ownerKey.equals(ownerKey) &
            (bucket == null
                ? const Constant(true)
                : table.bucket.equals(bucket)),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return (await query.get()).map(_fromRow).toList();
  }

  @override
  Future<void> write(
    String ownerKey,
    String bucket,
    String recordKey,
    String payload, {
    DateTime? updatedAt,
  }) => _db
      .into(_db.ownerDataRows)
      .insertOnConflictUpdate(
        OwnerDataRowsCompanion.insert(
          ownerKey: ownerKey,
          bucket: bucket,
          recordKey: recordKey,
          payload: payload,
          updatedAt: updatedAt ?? DateTime.now().toUtc(),
        ),
      );

  @override
  Future<void> delete(String ownerKey, String bucket, String recordKey) async {
    await (_db.delete(_db.ownerDataRows)..where(
          (table) =>
              table.ownerKey.equals(ownerKey) &
              table.bucket.equals(bucket) &
              table.recordKey.equals(recordKey),
        ))
        .go();
  }

  @override
  Future<void> deleteIfMatches(
    String ownerKey,
    String bucket,
    String recordKey, {
    required String payload,
    required DateTime updatedAt,
  }) async {
    await (_db.delete(_db.ownerDataRows)..where(
          (table) =>
              table.ownerKey.equals(ownerKey) &
              table.bucket.equals(bucket) &
              table.recordKey.equals(recordKey) &
              table.payload.equals(payload) &
              table.updatedAt.equals(updatedAt),
        ))
        .go();
  }

  @override
  Future<void> clearOwner(String ownerKey) async {
    await (_db.delete(
      _db.ownerDataRows,
    )..where((table) => table.ownerKey.equals(ownerKey))).go();
  }

  OwnerDataRecord _fromRow(OwnerDataRow row) => OwnerDataRecord(
    ownerKey: row.ownerKey,
    bucket: row.bucket,
    recordKey: row.recordKey,
    payload: row.payload,
    updatedAt: row.updatedAt,
  );
}

/// Prevents a cache/draft/queue write that started in an older account epoch
/// from resurrecting data after logout or account replacement.
class EpochGuardedOwnerDataStore implements OwnerDataStore {
  EpochGuardedOwnerDataStore(this._inner, this._epochs);

  final OwnerDataStore _inner;
  final AccountEpochStore _epochs;

  @override
  Future<OwnerDataRecord?> read(
    String ownerKey,
    String bucket,
    String recordKey,
  ) => _inner.read(ownerKey, bucket, recordKey);

  @override
  Future<List<OwnerDataRecord>> list(String ownerKey, [String? bucket]) =>
      _inner.list(ownerKey, bucket);

  @override
  Future<void> write(
    String ownerKey,
    String bucket,
    String recordKey,
    String payload, {
    DateTime? updatedAt,
  }) async {
    final epoch = await _epochs.current();
    final committedAt = updatedAt ?? DateTime.now().toUtc();
    await _inner.write(
      ownerKey,
      bucket,
      recordKey,
      payload,
      updatedAt: committedAt,
    );
    if (await _epochs.current() != epoch) {
      await _inner.deleteIfMatches(
        ownerKey,
        bucket,
        recordKey,
        payload: payload,
        updatedAt: committedAt,
      );
    }
  }

  @override
  Future<void> delete(String ownerKey, String bucket, String recordKey) =>
      _inner.delete(ownerKey, bucket, recordKey);

  @override
  Future<void> deleteIfMatches(
    String ownerKey,
    String bucket,
    String recordKey, {
    required String payload,
    required DateTime updatedAt,
  }) => _inner.deleteIfMatches(
    ownerKey,
    bucket,
    recordKey,
    payload: payload,
    updatedAt: updatedAt,
  );

  @override
  Future<void> clearOwner(String ownerKey) => _inner.clearOwner(ownerKey);
}

final ownerDataStoreProvider = Provider<OwnerDataStore>(
  (ref) => EpochGuardedOwnerDataStore(
    DriftOwnerDataStore(ref.watch(appDatabaseProvider)),
    ref.watch(accountEpochStoreProvider),
  ),
);
