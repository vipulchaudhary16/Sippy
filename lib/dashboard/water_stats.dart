class WaterStats {
  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  static Map<DateTime, int> countsByDay(List<DateTime> stamps) {
    final map = <DateTime, int>{};
    for (final s in stamps) {
      final key = _midnight(s);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  static int currentStreak(
      List<DateTime> stamps, int dailyGoal, DateTime today) {
    final counts = countsByDay(stamps);
    var streak = 0;
    var day = _midnight(today);
    while ((counts[day] ?? 0) >= dailyGoal) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static List<int> lastSevenDays(List<DateTime> stamps, DateTime today) {
    final counts = countsByDay(stamps);
    final result = <int>[];
    for (var i = 6; i >= 0; i--) {
      final day = _midnight(today).subtract(Duration(days: i));
      result.add(counts[day] ?? 0);
    }
    return result;
  }
}
