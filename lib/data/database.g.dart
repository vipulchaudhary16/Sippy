// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $IntakeLogTable extends IntakeLog
    with TableInfo<$IntakeLogTable, IntakeLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntakeLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'intake_log';
  @override
  VerificationContext validateIntegrity(Insertable<IntakeLogData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IntakeLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IntakeLogData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $IntakeLogTable createAlias(String alias) {
    return $IntakeLogTable(attachedDatabase, alias);
  }
}

class IntakeLogData extends DataClass implements Insertable<IntakeLogData> {
  final int id;
  final DateTime timestamp;
  const IntakeLogData({required this.id, required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  IntakeLogCompanion toCompanion(bool nullToAbsent) {
    return IntakeLogCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
    );
  }

  factory IntakeLogData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IntakeLogData(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  IntakeLogData copyWith({int? id, DateTime? timestamp}) => IntakeLogData(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
      );
  IntakeLogData copyWithCompanion(IntakeLogCompanion data) {
    return IntakeLogData(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IntakeLogData(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntakeLogData &&
          other.id == this.id &&
          other.timestamp == this.timestamp);
}

class IntakeLogCompanion extends UpdateCompanion<IntakeLogData> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  const IntakeLogCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  IntakeLogCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
  }) : timestamp = Value(timestamp);
  static Insertable<IntakeLogData> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  IntakeLogCompanion copyWith({Value<int>? id, Value<DateTime>? timestamp}) {
    return IntakeLogCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntakeLogCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $IntakeLogTable intakeLog = $IntakeLogTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [intakeLog];
}

typedef $$IntakeLogTableCreateCompanionBuilder = IntakeLogCompanion Function({
  Value<int> id,
  required DateTime timestamp,
});
typedef $$IntakeLogTableUpdateCompanionBuilder = IntakeLogCompanion Function({
  Value<int> id,
  Value<DateTime> timestamp,
});

class $$IntakeLogTableFilterComposer
    extends Composer<_$AppDatabase, $IntakeLogTable> {
  $$IntakeLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$IntakeLogTableOrderingComposer
    extends Composer<_$AppDatabase, $IntakeLogTable> {
  $$IntakeLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$IntakeLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $IntakeLogTable> {
  $$IntakeLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$IntakeLogTableTableManager extends RootTableManager<
    _$AppDatabase,
    $IntakeLogTable,
    IntakeLogData,
    $$IntakeLogTableFilterComposer,
    $$IntakeLogTableOrderingComposer,
    $$IntakeLogTableAnnotationComposer,
    $$IntakeLogTableCreateCompanionBuilder,
    $$IntakeLogTableUpdateCompanionBuilder,
    (
      IntakeLogData,
      BaseReferences<_$AppDatabase, $IntakeLogTable, IntakeLogData>
    ),
    IntakeLogData,
    PrefetchHooks Function()> {
  $$IntakeLogTableTableManager(_$AppDatabase db, $IntakeLogTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntakeLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntakeLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IntakeLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              IntakeLogCompanion(
            id: id,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime timestamp,
          }) =>
              IntakeLogCompanion.insert(
            id: id,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$IntakeLogTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $IntakeLogTable,
    IntakeLogData,
    $$IntakeLogTableFilterComposer,
    $$IntakeLogTableOrderingComposer,
    $$IntakeLogTableAnnotationComposer,
    $$IntakeLogTableCreateCompanionBuilder,
    $$IntakeLogTableUpdateCompanionBuilder,
    (
      IntakeLogData,
      BaseReferences<_$AppDatabase, $IntakeLogTable, IntakeLogData>
    ),
    IntakeLogData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$IntakeLogTableTableManager get intakeLog =>
      $$IntakeLogTableTableManager(_db, _db.intakeLog);
}
