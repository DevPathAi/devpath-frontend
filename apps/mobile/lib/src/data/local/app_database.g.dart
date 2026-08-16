// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DashboardCacheRowsTable extends DashboardCacheRows
    with TableInfo<$DashboardCacheRowsTable, DashboardCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DashboardCacheRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _streakDaysMeta = const VerificationMeta(
    'streakDays',
  );
  @override
  late final GeneratedColumn<int> streakDays = GeneratedColumn<int>(
    'streak_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressPercentMeta = const VerificationMeta(
    'progressPercent',
  );
  @override
  late final GeneratedColumn<int> progressPercent = GeneratedColumn<int>(
    'progress_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextTaskTitleMeta = const VerificationMeta(
    'nextTaskTitle',
  );
  @override
  late final GeneratedColumn<String> nextTaskTitle = GeneratedColumn<String>(
    'next_task_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _badgesMeta = const VerificationMeta('badges');
  @override
  late final GeneratedColumn<String> badges = GeneratedColumn<String>(
    'badges',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    streakDays,
    progressPercent,
    nextTaskTitle,
    badges,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dashboard_cache_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<DashboardCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('streak_days')) {
      context.handle(
        _streakDaysMeta,
        streakDays.isAcceptableOrUnknown(data['streak_days']!, _streakDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_streakDaysMeta);
    }
    if (data.containsKey('progress_percent')) {
      context.handle(
        _progressPercentMeta,
        progressPercent.isAcceptableOrUnknown(
          data['progress_percent']!,
          _progressPercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_progressPercentMeta);
    }
    if (data.containsKey('next_task_title')) {
      context.handle(
        _nextTaskTitleMeta,
        nextTaskTitle.isAcceptableOrUnknown(
          data['next_task_title']!,
          _nextTaskTitleMeta,
        ),
      );
    }
    if (data.containsKey('badges')) {
      context.handle(
        _badgesMeta,
        badges.isAcceptableOrUnknown(data['badges']!, _badgesMeta),
      );
    } else if (isInserting) {
      context.missing(_badgesMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DashboardCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DashboardCacheRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      streakDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak_days'],
      )!,
      progressPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress_percent'],
      )!,
      nextTaskTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_task_title'],
      ),
      badges: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}badges'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $DashboardCacheRowsTable createAlias(String alias) {
    return $DashboardCacheRowsTable(attachedDatabase, alias);
  }
}

class DashboardCacheRow extends DataClass
    implements Insertable<DashboardCacheRow> {
  final int id;
  final int streakDays;
  final int progressPercent;
  final String? nextTaskTitle;
  final String badges;
  final DateTime cachedAt;
  const DashboardCacheRow({
    required this.id,
    required this.streakDays,
    required this.progressPercent,
    this.nextTaskTitle,
    required this.badges,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['streak_days'] = Variable<int>(streakDays);
    map['progress_percent'] = Variable<int>(progressPercent);
    if (!nullToAbsent || nextTaskTitle != null) {
      map['next_task_title'] = Variable<String>(nextTaskTitle);
    }
    map['badges'] = Variable<String>(badges);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  DashboardCacheRowsCompanion toCompanion(bool nullToAbsent) {
    return DashboardCacheRowsCompanion(
      id: Value(id),
      streakDays: Value(streakDays),
      progressPercent: Value(progressPercent),
      nextTaskTitle: nextTaskTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(nextTaskTitle),
      badges: Value(badges),
      cachedAt: Value(cachedAt),
    );
  }

  factory DashboardCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DashboardCacheRow(
      id: serializer.fromJson<int>(json['id']),
      streakDays: serializer.fromJson<int>(json['streakDays']),
      progressPercent: serializer.fromJson<int>(json['progressPercent']),
      nextTaskTitle: serializer.fromJson<String?>(json['nextTaskTitle']),
      badges: serializer.fromJson<String>(json['badges']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'streakDays': serializer.toJson<int>(streakDays),
      'progressPercent': serializer.toJson<int>(progressPercent),
      'nextTaskTitle': serializer.toJson<String?>(nextTaskTitle),
      'badges': serializer.toJson<String>(badges),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  DashboardCacheRow copyWith({
    int? id,
    int? streakDays,
    int? progressPercent,
    Value<String?> nextTaskTitle = const Value.absent(),
    String? badges,
    DateTime? cachedAt,
  }) => DashboardCacheRow(
    id: id ?? this.id,
    streakDays: streakDays ?? this.streakDays,
    progressPercent: progressPercent ?? this.progressPercent,
    nextTaskTitle: nextTaskTitle.present
        ? nextTaskTitle.value
        : this.nextTaskTitle,
    badges: badges ?? this.badges,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  DashboardCacheRow copyWithCompanion(DashboardCacheRowsCompanion data) {
    return DashboardCacheRow(
      id: data.id.present ? data.id.value : this.id,
      streakDays: data.streakDays.present
          ? data.streakDays.value
          : this.streakDays,
      progressPercent: data.progressPercent.present
          ? data.progressPercent.value
          : this.progressPercent,
      nextTaskTitle: data.nextTaskTitle.present
          ? data.nextTaskTitle.value
          : this.nextTaskTitle,
      badges: data.badges.present ? data.badges.value : this.badges,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DashboardCacheRow(')
          ..write('id: $id, ')
          ..write('streakDays: $streakDays, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('nextTaskTitle: $nextTaskTitle, ')
          ..write('badges: $badges, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    streakDays,
    progressPercent,
    nextTaskTitle,
    badges,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DashboardCacheRow &&
          other.id == this.id &&
          other.streakDays == this.streakDays &&
          other.progressPercent == this.progressPercent &&
          other.nextTaskTitle == this.nextTaskTitle &&
          other.badges == this.badges &&
          other.cachedAt == this.cachedAt);
}

class DashboardCacheRowsCompanion extends UpdateCompanion<DashboardCacheRow> {
  final Value<int> id;
  final Value<int> streakDays;
  final Value<int> progressPercent;
  final Value<String?> nextTaskTitle;
  final Value<String> badges;
  final Value<DateTime> cachedAt;
  const DashboardCacheRowsCompanion({
    this.id = const Value.absent(),
    this.streakDays = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.nextTaskTitle = const Value.absent(),
    this.badges = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  DashboardCacheRowsCompanion.insert({
    this.id = const Value.absent(),
    required int streakDays,
    required int progressPercent,
    this.nextTaskTitle = const Value.absent(),
    required String badges,
    required DateTime cachedAt,
  }) : streakDays = Value(streakDays),
       progressPercent = Value(progressPercent),
       badges = Value(badges),
       cachedAt = Value(cachedAt);
  static Insertable<DashboardCacheRow> custom({
    Expression<int>? id,
    Expression<int>? streakDays,
    Expression<int>? progressPercent,
    Expression<String>? nextTaskTitle,
    Expression<String>? badges,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (streakDays != null) 'streak_days': streakDays,
      if (progressPercent != null) 'progress_percent': progressPercent,
      if (nextTaskTitle != null) 'next_task_title': nextTaskTitle,
      if (badges != null) 'badges': badges,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  DashboardCacheRowsCompanion copyWith({
    Value<int>? id,
    Value<int>? streakDays,
    Value<int>? progressPercent,
    Value<String?>? nextTaskTitle,
    Value<String>? badges,
    Value<DateTime>? cachedAt,
  }) {
    return DashboardCacheRowsCompanion(
      id: id ?? this.id,
      streakDays: streakDays ?? this.streakDays,
      progressPercent: progressPercent ?? this.progressPercent,
      nextTaskTitle: nextTaskTitle ?? this.nextTaskTitle,
      badges: badges ?? this.badges,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (streakDays.present) {
      map['streak_days'] = Variable<int>(streakDays.value);
    }
    if (progressPercent.present) {
      map['progress_percent'] = Variable<int>(progressPercent.value);
    }
    if (nextTaskTitle.present) {
      map['next_task_title'] = Variable<String>(nextTaskTitle.value);
    }
    if (badges.present) {
      map['badges'] = Variable<String>(badges.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DashboardCacheRowsCompanion(')
          ..write('id: $id, ')
          ..write('streakDays: $streakDays, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('nextTaskTitle: $nextTaskTitle, ')
          ..write('badges: $badges, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $CurrentMissionCacheRowsTable extends CurrentMissionCacheRows
    with TableInfo<$CurrentMissionCacheRowsTable, CurrentMissionCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurrentMissionCacheRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerKeyMeta = const VerificationMeta(
    'ownerKey',
  );
  @override
  late final GeneratedColumn<String> ownerKey = GeneratedColumn<String>(
    'owner_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [ownerKey, payload, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'current_mission_cache_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CurrentMissionCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_key')) {
      context.handle(
        _ownerKeyMeta,
        ownerKey.isAcceptableOrUnknown(data['owner_key']!, _ownerKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerKey};
  @override
  CurrentMissionCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurrentMissionCacheRow(
      ownerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CurrentMissionCacheRowsTable createAlias(String alias) {
    return $CurrentMissionCacheRowsTable(attachedDatabase, alias);
  }
}

class CurrentMissionCacheRow extends DataClass
    implements Insertable<CurrentMissionCacheRow> {
  final String ownerKey;
  final String payload;
  final DateTime cachedAt;
  const CurrentMissionCacheRow({
    required this.ownerKey,
    required this.payload,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_key'] = Variable<String>(ownerKey);
    map['payload'] = Variable<String>(payload);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CurrentMissionCacheRowsCompanion toCompanion(bool nullToAbsent) {
    return CurrentMissionCacheRowsCompanion(
      ownerKey: Value(ownerKey),
      payload: Value(payload),
      cachedAt: Value(cachedAt),
    );
  }

  factory CurrentMissionCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurrentMissionCacheRow(
      ownerKey: serializer.fromJson<String>(json['ownerKey']),
      payload: serializer.fromJson<String>(json['payload']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerKey': serializer.toJson<String>(ownerKey),
      'payload': serializer.toJson<String>(payload),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CurrentMissionCacheRow copyWith({
    String? ownerKey,
    String? payload,
    DateTime? cachedAt,
  }) => CurrentMissionCacheRow(
    ownerKey: ownerKey ?? this.ownerKey,
    payload: payload ?? this.payload,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CurrentMissionCacheRow copyWithCompanion(
    CurrentMissionCacheRowsCompanion data,
  ) {
    return CurrentMissionCacheRow(
      ownerKey: data.ownerKey.present ? data.ownerKey.value : this.ownerKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurrentMissionCacheRow(')
          ..write('ownerKey: $ownerKey, ')
          ..write('payload: $payload, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerKey, payload, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurrentMissionCacheRow &&
          other.ownerKey == this.ownerKey &&
          other.payload == this.payload &&
          other.cachedAt == this.cachedAt);
}

class CurrentMissionCacheRowsCompanion
    extends UpdateCompanion<CurrentMissionCacheRow> {
  final Value<String> ownerKey;
  final Value<String> payload;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CurrentMissionCacheRowsCompanion({
    this.ownerKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurrentMissionCacheRowsCompanion.insert({
    required String ownerKey,
    required String payload,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : ownerKey = Value(ownerKey),
       payload = Value(payload),
       cachedAt = Value(cachedAt);
  static Insertable<CurrentMissionCacheRow> custom({
    Expression<String>? ownerKey,
    Expression<String>? payload,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerKey != null) 'owner_key': ownerKey,
      if (payload != null) 'payload': payload,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurrentMissionCacheRowsCompanion copyWith({
    Value<String>? ownerKey,
    Value<String>? payload,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CurrentMissionCacheRowsCompanion(
      ownerKey: ownerKey ?? this.ownerKey,
      payload: payload ?? this.payload,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerKey.present) {
      map['owner_key'] = Variable<String>(ownerKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurrentMissionCacheRowsCompanion(')
          ..write('ownerKey: $ownerKey, ')
          ..write('payload: $payload, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OwnerDataRowsTable extends OwnerDataRows
    with TableInfo<$OwnerDataRowsTable, OwnerDataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OwnerDataRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerKeyMeta = const VerificationMeta(
    'ownerKey',
  );
  @override
  late final GeneratedColumn<String> ownerKey = GeneratedColumn<String>(
    'owner_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketMeta = const VerificationMeta('bucket');
  @override
  late final GeneratedColumn<String> bucket = GeneratedColumn<String>(
    'bucket',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordKeyMeta = const VerificationMeta(
    'recordKey',
  );
  @override
  late final GeneratedColumn<String> recordKey = GeneratedColumn<String>(
    'record_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerKey,
    bucket,
    recordKey,
    payload,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'owner_data_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<OwnerDataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_key')) {
      context.handle(
        _ownerKeyMeta,
        ownerKey.isAcceptableOrUnknown(data['owner_key']!, _ownerKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerKeyMeta);
    }
    if (data.containsKey('bucket')) {
      context.handle(
        _bucketMeta,
        bucket.isAcceptableOrUnknown(data['bucket']!, _bucketMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketMeta);
    }
    if (data.containsKey('record_key')) {
      context.handle(
        _recordKeyMeta,
        recordKey.isAcceptableOrUnknown(data['record_key']!, _recordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_recordKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerKey, bucket, recordKey};
  @override
  OwnerDataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OwnerDataRow(
      ownerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_key'],
      )!,
      bucket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket'],
      )!,
      recordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OwnerDataRowsTable createAlias(String alias) {
    return $OwnerDataRowsTable(attachedDatabase, alias);
  }
}

class OwnerDataRow extends DataClass implements Insertable<OwnerDataRow> {
  final String ownerKey;
  final String bucket;
  final String recordKey;
  final String payload;
  final DateTime updatedAt;
  const OwnerDataRow({
    required this.ownerKey,
    required this.bucket,
    required this.recordKey,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_key'] = Variable<String>(ownerKey);
    map['bucket'] = Variable<String>(bucket);
    map['record_key'] = Variable<String>(recordKey);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OwnerDataRowsCompanion toCompanion(bool nullToAbsent) {
    return OwnerDataRowsCompanion(
      ownerKey: Value(ownerKey),
      bucket: Value(bucket),
      recordKey: Value(recordKey),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory OwnerDataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OwnerDataRow(
      ownerKey: serializer.fromJson<String>(json['ownerKey']),
      bucket: serializer.fromJson<String>(json['bucket']),
      recordKey: serializer.fromJson<String>(json['recordKey']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerKey': serializer.toJson<String>(ownerKey),
      'bucket': serializer.toJson<String>(bucket),
      'recordKey': serializer.toJson<String>(recordKey),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OwnerDataRow copyWith({
    String? ownerKey,
    String? bucket,
    String? recordKey,
    String? payload,
    DateTime? updatedAt,
  }) => OwnerDataRow(
    ownerKey: ownerKey ?? this.ownerKey,
    bucket: bucket ?? this.bucket,
    recordKey: recordKey ?? this.recordKey,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OwnerDataRow copyWithCompanion(OwnerDataRowsCompanion data) {
    return OwnerDataRow(
      ownerKey: data.ownerKey.present ? data.ownerKey.value : this.ownerKey,
      bucket: data.bucket.present ? data.bucket.value : this.bucket,
      recordKey: data.recordKey.present ? data.recordKey.value : this.recordKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OwnerDataRow(')
          ..write('ownerKey: $ownerKey, ')
          ..write('bucket: $bucket, ')
          ..write('recordKey: $recordKey, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(ownerKey, bucket, recordKey, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OwnerDataRow &&
          other.ownerKey == this.ownerKey &&
          other.bucket == this.bucket &&
          other.recordKey == this.recordKey &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class OwnerDataRowsCompanion extends UpdateCompanion<OwnerDataRow> {
  final Value<String> ownerKey;
  final Value<String> bucket;
  final Value<String> recordKey;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OwnerDataRowsCompanion({
    this.ownerKey = const Value.absent(),
    this.bucket = const Value.absent(),
    this.recordKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OwnerDataRowsCompanion.insert({
    required String ownerKey,
    required String bucket,
    required String recordKey,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : ownerKey = Value(ownerKey),
       bucket = Value(bucket),
       recordKey = Value(recordKey),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<OwnerDataRow> custom({
    Expression<String>? ownerKey,
    Expression<String>? bucket,
    Expression<String>? recordKey,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerKey != null) 'owner_key': ownerKey,
      if (bucket != null) 'bucket': bucket,
      if (recordKey != null) 'record_key': recordKey,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OwnerDataRowsCompanion copyWith({
    Value<String>? ownerKey,
    Value<String>? bucket,
    Value<String>? recordKey,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return OwnerDataRowsCompanion(
      ownerKey: ownerKey ?? this.ownerKey,
      bucket: bucket ?? this.bucket,
      recordKey: recordKey ?? this.recordKey,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerKey.present) {
      map['owner_key'] = Variable<String>(ownerKey.value);
    }
    if (bucket.present) {
      map['bucket'] = Variable<String>(bucket.value);
    }
    if (recordKey.present) {
      map['record_key'] = Variable<String>(recordKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OwnerDataRowsCompanion(')
          ..write('ownerKey: $ownerKey, ')
          ..write('bucket: $bucket, ')
          ..write('recordKey: $recordKey, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DashboardCacheRowsTable dashboardCacheRows =
      $DashboardCacheRowsTable(this);
  late final $CurrentMissionCacheRowsTable currentMissionCacheRows =
      $CurrentMissionCacheRowsTable(this);
  late final $OwnerDataRowsTable ownerDataRows = $OwnerDataRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dashboardCacheRows,
    currentMissionCacheRows,
    ownerDataRows,
  ];
}

typedef $$DashboardCacheRowsTableCreateCompanionBuilder =
    DashboardCacheRowsCompanion Function({
      Value<int> id,
      required int streakDays,
      required int progressPercent,
      Value<String?> nextTaskTitle,
      required String badges,
      required DateTime cachedAt,
    });
typedef $$DashboardCacheRowsTableUpdateCompanionBuilder =
    DashboardCacheRowsCompanion Function({
      Value<int> id,
      Value<int> streakDays,
      Value<int> progressPercent,
      Value<String?> nextTaskTitle,
      Value<String> badges,
      Value<DateTime> cachedAt,
    });

class $$DashboardCacheRowsTableFilterComposer
    extends Composer<_$AppDatabase, $DashboardCacheRowsTable> {
  $$DashboardCacheRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streakDays => $composableBuilder(
    column: $table.streakDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextTaskTitle => $composableBuilder(
    column: $table.nextTaskTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get badges => $composableBuilder(
    column: $table.badges,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DashboardCacheRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $DashboardCacheRowsTable> {
  $$DashboardCacheRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streakDays => $composableBuilder(
    column: $table.streakDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextTaskTitle => $composableBuilder(
    column: $table.nextTaskTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get badges => $composableBuilder(
    column: $table.badges,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DashboardCacheRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DashboardCacheRowsTable> {
  $$DashboardCacheRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get streakDays => $composableBuilder(
    column: $table.streakDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextTaskTitle => $composableBuilder(
    column: $table.nextTaskTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get badges =>
      $composableBuilder(column: $table.badges, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$DashboardCacheRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DashboardCacheRowsTable,
          DashboardCacheRow,
          $$DashboardCacheRowsTableFilterComposer,
          $$DashboardCacheRowsTableOrderingComposer,
          $$DashboardCacheRowsTableAnnotationComposer,
          $$DashboardCacheRowsTableCreateCompanionBuilder,
          $$DashboardCacheRowsTableUpdateCompanionBuilder,
          (
            DashboardCacheRow,
            BaseReferences<
              _$AppDatabase,
              $DashboardCacheRowsTable,
              DashboardCacheRow
            >,
          ),
          DashboardCacheRow,
          PrefetchHooks Function()
        > {
  $$DashboardCacheRowsTableTableManager(
    _$AppDatabase db,
    $DashboardCacheRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DashboardCacheRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DashboardCacheRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DashboardCacheRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> streakDays = const Value.absent(),
                Value<int> progressPercent = const Value.absent(),
                Value<String?> nextTaskTitle = const Value.absent(),
                Value<String> badges = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => DashboardCacheRowsCompanion(
                id: id,
                streakDays: streakDays,
                progressPercent: progressPercent,
                nextTaskTitle: nextTaskTitle,
                badges: badges,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int streakDays,
                required int progressPercent,
                Value<String?> nextTaskTitle = const Value.absent(),
                required String badges,
                required DateTime cachedAt,
              }) => DashboardCacheRowsCompanion.insert(
                id: id,
                streakDays: streakDays,
                progressPercent: progressPercent,
                nextTaskTitle: nextTaskTitle,
                badges: badges,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DashboardCacheRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DashboardCacheRowsTable,
      DashboardCacheRow,
      $$DashboardCacheRowsTableFilterComposer,
      $$DashboardCacheRowsTableOrderingComposer,
      $$DashboardCacheRowsTableAnnotationComposer,
      $$DashboardCacheRowsTableCreateCompanionBuilder,
      $$DashboardCacheRowsTableUpdateCompanionBuilder,
      (
        DashboardCacheRow,
        BaseReferences<
          _$AppDatabase,
          $DashboardCacheRowsTable,
          DashboardCacheRow
        >,
      ),
      DashboardCacheRow,
      PrefetchHooks Function()
    >;
typedef $$CurrentMissionCacheRowsTableCreateCompanionBuilder =
    CurrentMissionCacheRowsCompanion Function({
      required String ownerKey,
      required String payload,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CurrentMissionCacheRowsTableUpdateCompanionBuilder =
    CurrentMissionCacheRowsCompanion Function({
      Value<String> ownerKey,
      Value<String> payload,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CurrentMissionCacheRowsTableFilterComposer
    extends Composer<_$AppDatabase, $CurrentMissionCacheRowsTable> {
  $$CurrentMissionCacheRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerKey => $composableBuilder(
    column: $table.ownerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CurrentMissionCacheRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $CurrentMissionCacheRowsTable> {
  $$CurrentMissionCacheRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerKey => $composableBuilder(
    column: $table.ownerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CurrentMissionCacheRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CurrentMissionCacheRowsTable> {
  $$CurrentMissionCacheRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerKey =>
      $composableBuilder(column: $table.ownerKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CurrentMissionCacheRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CurrentMissionCacheRowsTable,
          CurrentMissionCacheRow,
          $$CurrentMissionCacheRowsTableFilterComposer,
          $$CurrentMissionCacheRowsTableOrderingComposer,
          $$CurrentMissionCacheRowsTableAnnotationComposer,
          $$CurrentMissionCacheRowsTableCreateCompanionBuilder,
          $$CurrentMissionCacheRowsTableUpdateCompanionBuilder,
          (
            CurrentMissionCacheRow,
            BaseReferences<
              _$AppDatabase,
              $CurrentMissionCacheRowsTable,
              CurrentMissionCacheRow
            >,
          ),
          CurrentMissionCacheRow,
          PrefetchHooks Function()
        > {
  $$CurrentMissionCacheRowsTableTableManager(
    _$AppDatabase db,
    $CurrentMissionCacheRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurrentMissionCacheRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CurrentMissionCacheRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CurrentMissionCacheRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurrentMissionCacheRowsCompanion(
                ownerKey: ownerKey,
                payload: payload,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerKey,
                required String payload,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CurrentMissionCacheRowsCompanion.insert(
                ownerKey: ownerKey,
                payload: payload,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CurrentMissionCacheRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CurrentMissionCacheRowsTable,
      CurrentMissionCacheRow,
      $$CurrentMissionCacheRowsTableFilterComposer,
      $$CurrentMissionCacheRowsTableOrderingComposer,
      $$CurrentMissionCacheRowsTableAnnotationComposer,
      $$CurrentMissionCacheRowsTableCreateCompanionBuilder,
      $$CurrentMissionCacheRowsTableUpdateCompanionBuilder,
      (
        CurrentMissionCacheRow,
        BaseReferences<
          _$AppDatabase,
          $CurrentMissionCacheRowsTable,
          CurrentMissionCacheRow
        >,
      ),
      CurrentMissionCacheRow,
      PrefetchHooks Function()
    >;
typedef $$OwnerDataRowsTableCreateCompanionBuilder =
    OwnerDataRowsCompanion Function({
      required String ownerKey,
      required String bucket,
      required String recordKey,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$OwnerDataRowsTableUpdateCompanionBuilder =
    OwnerDataRowsCompanion Function({
      Value<String> ownerKey,
      Value<String> bucket,
      Value<String> recordKey,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$OwnerDataRowsTableFilterComposer
    extends Composer<_$AppDatabase, $OwnerDataRowsTable> {
  $$OwnerDataRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerKey => $composableBuilder(
    column: $table.ownerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OwnerDataRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $OwnerDataRowsTable> {
  $$OwnerDataRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerKey => $composableBuilder(
    column: $table.ownerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OwnerDataRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OwnerDataRowsTable> {
  $$OwnerDataRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerKey =>
      $composableBuilder(column: $table.ownerKey, builder: (column) => column);

  GeneratedColumn<String> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => column);

  GeneratedColumn<String> get recordKey =>
      $composableBuilder(column: $table.recordKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OwnerDataRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OwnerDataRowsTable,
          OwnerDataRow,
          $$OwnerDataRowsTableFilterComposer,
          $$OwnerDataRowsTableOrderingComposer,
          $$OwnerDataRowsTableAnnotationComposer,
          $$OwnerDataRowsTableCreateCompanionBuilder,
          $$OwnerDataRowsTableUpdateCompanionBuilder,
          (
            OwnerDataRow,
            BaseReferences<_$AppDatabase, $OwnerDataRowsTable, OwnerDataRow>,
          ),
          OwnerDataRow,
          PrefetchHooks Function()
        > {
  $$OwnerDataRowsTableTableManager(_$AppDatabase db, $OwnerDataRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OwnerDataRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OwnerDataRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OwnerDataRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerKey = const Value.absent(),
                Value<String> bucket = const Value.absent(),
                Value<String> recordKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OwnerDataRowsCompanion(
                ownerKey: ownerKey,
                bucket: bucket,
                recordKey: recordKey,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerKey,
                required String bucket,
                required String recordKey,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OwnerDataRowsCompanion.insert(
                ownerKey: ownerKey,
                bucket: bucket,
                recordKey: recordKey,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OwnerDataRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OwnerDataRowsTable,
      OwnerDataRow,
      $$OwnerDataRowsTableFilterComposer,
      $$OwnerDataRowsTableOrderingComposer,
      $$OwnerDataRowsTableAnnotationComposer,
      $$OwnerDataRowsTableCreateCompanionBuilder,
      $$OwnerDataRowsTableUpdateCompanionBuilder,
      (
        OwnerDataRow,
        BaseReferences<_$AppDatabase, $OwnerDataRowsTable, OwnerDataRow>,
      ),
      OwnerDataRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DashboardCacheRowsTableTableManager get dashboardCacheRows =>
      $$DashboardCacheRowsTableTableManager(_db, _db.dashboardCacheRows);
  $$CurrentMissionCacheRowsTableTableManager get currentMissionCacheRows =>
      $$CurrentMissionCacheRowsTableTableManager(
        _db,
        _db.currentMissionCacheRows,
      );
  $$OwnerDataRowsTableTableManager get ownerDataRows =>
      $$OwnerDataRowsTableTableManager(_db, _db.ownerDataRows);
}
