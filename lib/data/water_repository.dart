import 'package:drift/drift.dart';
import 'database.dart';

class WaterRepository {
  final AppDatabase _db;
  WaterRepository(this._db);

  Future<int> logGlass(DateTime at) {
    return _db.into(_db.intakeLog).insert(
          IntakeLogCompanion.insert(timestamp: at),
        );
  }

  Future<int> countForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final query = _db.select(_db.intakeLog)
      ..where((t) =>
          t.timestamp.isBiggerOrEqualValue(start) &
          t.timestamp.isSmallerThanValue(end));
    final rows = await query.get();
    return rows.length;
  }

  Future<List<DateTime>> allTimestamps() async {
    final query = _db.select(_db.intakeLog)
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    final rows = await query.get();
    return rows.map((r) => r.timestamp).toList();
  }
}
