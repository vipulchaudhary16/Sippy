import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/dashboard/water_stats.dart';

void main() {
  test('countsByDay groups by calendar day', () {
    final counts = WaterStats.countsByDay([
      DateTime(2026, 7, 4, 9),
      DateTime(2026, 7, 4, 18),
      DateTime(2026, 7, 5, 8),
    ]);
    expect(counts[DateTime(2026, 7, 4)], equals(2));
    expect(counts[DateTime(2026, 7, 5)], equals(1));
  });

  test('currentStreak counts consecutive goal-met days ending today', () {
    final today = DateTime(2026, 7, 4);
    final stamps = <DateTime>[
      ...List.generate(2, (_) => DateTime(2026, 7, 2, 9)), // goal=2 met
      ...List.generate(2, (_) => DateTime(2026, 7, 3, 9)),
      ...List.generate(2, (_) => DateTime(2026, 7, 4, 9)),
    ];
    expect(WaterStats.currentStreak(stamps, 2, today), equals(3));
  });

  test('currentStreak breaks when a day misses goal', () {
    final today = DateTime(2026, 7, 4);
    final stamps = <DateTime>[
      DateTime(2026, 7, 3, 9), // only 1, goal 2 -> miss
      DateTime(2026, 7, 4, 9),
      DateTime(2026, 7, 4, 10),
    ];
    expect(WaterStats.currentStreak(stamps, 2, today), equals(1));
  });

  test('lastSevenDays returns 7 counts oldest first', () {
    final today = DateTime(2026, 7, 4);
    final counts = WaterStats.lastSevenDays(
        [DateTime(2026, 7, 4, 9), DateTime(2026, 6, 28, 9)], today);
    expect(counts.length, equals(7));
    expect(counts.first, equals(1)); // 2026-06-28 is 7th-from-today
    expect(counts.last, equals(1)); // today
  });

  test('currentStreak returns 0 when today misses the goal', () {
    final today = DateTime(2026, 7, 4);
    final stamps = <DateTime>[
      DateTime(2026, 7, 4, 9), // only 1 glass, goal 2 -> miss
    ];
    expect(WaterStats.currentStreak(stamps, 2, today), equals(0));
  });

  test('currentStreak returns 0 when dailyGoal is zero or negative', () {
    final today = DateTime(2026, 7, 4);
    final stamps = <DateTime>[
      DateTime(2026, 7, 4, 9),
      DateTime(2026, 7, 3, 9),
    ];
    expect(WaterStats.currentStreak(stamps, 0, today), equals(0));
    expect(WaterStats.currentStreak(stamps, -1, today), equals(0));
  });
}
