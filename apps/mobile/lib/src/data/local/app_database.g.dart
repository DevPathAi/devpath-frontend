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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DashboardCacheRowsTable dashboardCacheRows =
      $DashboardCacheRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [dashboardCacheRows];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DashboardCacheRowsTableTableManager get dashboardCacheRows =>
      $$DashboardCacheRowsTableTableManager(_db, _db.dashboardCacheRows);
}
