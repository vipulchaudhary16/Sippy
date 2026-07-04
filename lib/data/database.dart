import 'package:drift/drift.dart';

part 'database.g.dart';

class IntakeLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
}

@DriftDatabase(tables: [IntakeLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.forTesting(QueryExecutor e) : this(e);

  @override
  int get schemaVersion => 1;
}
