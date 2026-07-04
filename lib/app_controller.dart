import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'audio/audio_manager.dart';
import 'data/water_repository.dart';
import 'scheduler/reminder_scheduler.dart';
import 'settings/app_settings.dart';
import 'settings/settings_store.dart';

class AppController extends ChangeNotifier {
  final WaterRepository repo;
  final AudioManager audio;
  final SettingsStore settingsStore;
  late final ReminderScheduler scheduler;

  AppSettings settings = const AppSettings.defaults();
  bool reminderVisible = false;

  AppController({
    required this.repo,
    required this.audio,
    required this.settingsStore,
  }) {
    scheduler = ReminderScheduler(onFire: showReminder);
  }

  Future<void> init() async {
    settings = await settingsStore.load();
    scheduler.start(Duration(minutes: settings.intervalMinutes));
  }

  Future<void> showReminder() async {
    reminderVisible = true;
    notifyListeners();
    await windowManager.show();
    await audio.play(settings.musicPaths,
        volume: settings.volume, muted: settings.muted);
  }

  Future<void> _dismiss() async {
    reminderVisible = false;
    notifyListeners();
    await audio.stop();
    await windowManager.hide();
  }

  Future<void> handleDrank() async {
    await repo.logGlass(DateTime.now());
    scheduler.reset(Duration(minutes: settings.intervalMinutes));
    await _dismiss();
  }

  Future<void> handleSnooze() async {
    scheduler.snooze(Duration(minutes: settings.snoozeMinutes));
    await _dismiss();
  }

  Future<void> applySettings(AppSettings s) async {
    settings = s;
    await settingsStore.save(s);
    scheduler.reset(Duration(minutes: s.intervalMinutes));
    notifyListeners();
  }
}
