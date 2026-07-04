import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  final int intervalMinutes;
  final int snoozeMinutes;
  final int dailyGoal;
  final double volume;
  final bool muted;
  final List<String> musicPaths;

  const AppSettings({
    required this.intervalMinutes,
    required this.snoozeMinutes,
    required this.dailyGoal,
    required this.volume,
    required this.muted,
    required this.musicPaths,
  });

  const AppSettings.defaults()
      : intervalMinutes = 60,
        snoozeMinutes = 10,
        dailyGoal = 8,
        volume = 0.5,
        muted = false,
        musicPaths = const [];

  AppSettings copyWith({
    int? intervalMinutes,
    int? snoozeMinutes,
    int? dailyGoal,
    double? volume,
    bool? muted,
    List<String>? musicPaths,
  }) {
    return AppSettings(
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      musicPaths: musicPaths ?? this.musicPaths,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.intervalMinutes == intervalMinutes &&
      other.snoozeMinutes == snoozeMinutes &&
      other.dailyGoal == dailyGoal &&
      other.volume == volume &&
      other.muted == muted &&
      listEquals(other.musicPaths, musicPaths);

  @override
  int get hashCode => Object.hash(intervalMinutes, snoozeMinutes, dailyGoal,
      volume, muted, Object.hashAll(musicPaths));
}
