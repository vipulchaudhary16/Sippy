import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'audio/audio_manager.dart';
import 'data/water_repository.dart';
import 'overlay/window_controller.dart';
import 'scheduler/reminder_scheduler.dart';
import 'settings/app_settings.dart';
import 'settings/settings_store.dart';

class AppController extends ChangeNotifier {
  final WaterRepository repo;
  final AudioManager audio;
  final SettingsStore settingsStore;
  final WindowController window;
  late final ReminderScheduler scheduler;

  AppSettings settings = const AppSettings.defaults();
  bool reminderVisible = false;
  bool showDashboard = false;
  bool showSettings = false;

  AppController({
    required this.repo,
    required this.audio,
    required this.settingsStore,
    this.window = const RealWindowController(),
  }) {
    scheduler = ReminderScheduler(onFire: showReminder);
  }

  Duration get _interval => Duration(minutes: settings.intervalMinutes);

  Future<void> init() async {
    settings = await settingsStore.load();
    scheduler.start(_interval);
  }

  Future<void> showReminder() async {
    // A reminder always shows the character — never a stale dashboard/settings.
    showDashboard = false;
    showSettings = false;
    reminderVisible = true;
    notifyListeners();
    try {
      await window.show();
    } catch (_) {
      // Overlay could not be shown: fall back to an OS notification and keep
      // the loop alive by rescheduling (the one-shot timer already fired).
      reminderVisible = false;
      notifyListeners();
      scheduler.reset(_interval);
      final n = LocalNotification(title: 'Sippy', body: 'Time to drink water!');
      await n.show();
      return;
    }
    // Audio failure (e.g. a deleted music file) must never crash the reminder.
    try {
      await audio.play(settings.musicPaths,
          volume: settings.volume, muted: settings.muted);
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    reminderVisible = false;
    notifyListeners();
    await audio.stop();
    await window.hide();
  }

  Future<void> handleDrank() async {
    await repo.logGlass(DateTime.now());
    scheduler.reset(_interval);
    await _dismiss();
  }

  Future<void> handleSnooze() async {
    scheduler.snooze(Duration(minutes: settings.snoozeMinutes));
    await _dismiss();
  }

  Future<void> openDashboard() async {
    final wasReminderActive = reminderVisible;
    reminderVisible = false;
    showDashboard = true;
    showSettings = false;
    notifyListeners();
    await audio.stop();
    // Navigating away from an active reminder consumes it — keep the loop alive.
    if (wasReminderActive) scheduler.reset(_interval);
    await window.show();
  }

  Future<void> openSettings() async {
    final wasReminderActive = reminderVisible;
    reminderVisible = false;
    showDashboard = false;
    showSettings = true;
    notifyListeners();
    await audio.stop();
    if (wasReminderActive) scheduler.reset(_interval);
    await window.show();
  }

  Future<void> closeDashboard() async {
    showDashboard = false;
    notifyListeners();
    await window.hide();
  }

  Future<void> closeSettings() async {
    showSettings = false;
    notifyListeners();
    await window.hide();
  }

  Future<void> applySettings(AppSettings s) async {
    settings = s;
    await settingsStore.save(s);
    scheduler.reset(_interval);
    notifyListeners();
  }

  @override
  void dispose() {
    scheduler.stop();
    audio.stop();
    super.dispose();
  }
}
