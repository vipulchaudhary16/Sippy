import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/data/database.dart';
import 'package:sippy/data/water_repository.dart';

void main() {
  late AppDatabase db;
  late WaterRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WaterRepository(db);
  });

  tearDown(() async => db.close());

  test('logGlass inserts and countForDay counts same-day rows', () async {
    final day = DateTime(2026, 7, 4, 9);
    await repo.logGlass(DateTime(2026, 7, 4, 9, 0));
    await repo.logGlass(DateTime(2026, 7, 4, 14, 0));
    await repo.logGlass(DateTime(2026, 7, 5, 10, 0)); // next day

    expect(await repo.countForDay(day), equals(2));
  });

  test('allTimestamps returns everything ascending', () async {
    await repo.logGlass(DateTime(2026, 7, 4, 14));
    await repo.logGlass(DateTime(2026, 7, 4, 9));

    final all = await repo.allTimestamps();
    expect(all.first.isBefore(all.last), isTrue);
    expect(all.length, equals(2));
  });
}
