import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';

class SettingsStore {
  final SharedPreferences _prefs;
  SettingsStore(this._prefs);

  static const _kInterval = 'intervalMinutes';
  static const _kSnooze = 'snoozeMinutes';
  static const _kGoal = 'dailyGoal';
  static const _kVolume = 'volume';
  static const _kMuted = 'muted';
  static const _kMusic = 'musicPaths';

  Future<AppSettings> load() async {
    const d = AppSettings.defaults();
    return AppSettings(
      intervalMinutes: _prefs.getInt(_kInterval) ?? d.intervalMinutes,
      snoozeMinutes: _prefs.getInt(_kSnooze) ?? d.snoozeMinutes,
      dailyGoal: _prefs.getInt(_kGoal) ?? d.dailyGoal,
      volume: _prefs.getDouble(_kVolume) ?? d.volume,
      muted: _prefs.getBool(_kMuted) ?? d.muted,
      musicPaths: _prefs.getStringList(_kMusic) ?? d.musicPaths,
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setInt(_kInterval, s.intervalMinutes);
    await _prefs.setInt(_kSnooze, s.snoozeMinutes);
    await _prefs.setInt(_kGoal, s.dailyGoal);
    await _prefs.setDouble(_kVolume, s.volume);
    await _prefs.setBool(_kMuted, s.muted);
    await _prefs.setStringList(_kMusic, s.musicPaths);
  }
}
