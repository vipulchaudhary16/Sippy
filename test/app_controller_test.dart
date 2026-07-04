import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sippy/app_controller.dart';
import 'package:sippy/audio/audio_manager.dart';
import 'package:sippy/data/database.dart';
import 'package:sippy/data/water_repository.dart';
import 'package:sippy/overlay/window_controller.dart';
import 'package:sippy/settings/app_settings.dart';
import 'package:sippy/settings/settings_store.dart';

class FakeWindowController implements WindowController {
  bool visible = false;
  bool destroyed = false;
  int showCount = 0;
  int hideCount = 0;
  @override
  Future<void> show() async {
    visible = true;
    showCount++;
  }
  @override
  Future<void> hide() async {
    visible = false;
    hideCount++;
  }
  @override
  Future<void> destroy() async => destroyed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeAudioSink sink;
  late FakeWindowController window;
  late AppController controller;

  Future<AppController> build() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    sink = FakeAudioSink();
    window = FakeWindowController();
    return AppController(
      repo: WaterRepository(db),
      audio: AudioManager.withSink(sink),
      settingsStore: SettingsStore(prefs),
      window: window,
    );
  }

  const withMusic = AppSettings(
    intervalMinutes: 60,
    snoozeMinutes: 10,
    dailyGoal: 8,
    volume: 0.5,
    muted: false,
    musicPaths: ['/song.mp3'],
  );

  setUp(() async {
    controller = await build();
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('showReminder shows the window and clears nav flags', () async {
    controller.showDashboard = true;
    controller.showSettings = true;
    await controller.showReminder();
    expect(controller.reminderVisible, isTrue);
    expect(controller.showDashboard, isFalse);
    expect(controller.showSettings, isFalse);
    expect(window.visible, isTrue);
  });

  test('openDashboard hides the reminder, stops audio, and shows the window',
      () async {
    await controller.applySettings(withMusic);
    await controller.showReminder();
    expect(sink.playing, isTrue);
    await controller.openDashboard();
    expect(controller.showDashboard, isTrue);
    expect(controller.reminderVisible, isFalse);
    expect(sink.playing, isFalse);
    expect(window.visible, isTrue);
  });

  test('closeDashboard clears the flag and hides the window', () async {
    await controller.openDashboard();
    await controller.closeDashboard();
    expect(controller.showDashboard, isFalse);
    expect(window.visible, isFalse);
  });

  test('handleDrank logs a glass and dismisses the overlay', () async {
    await controller.showReminder();
    await controller.handleDrank();
    expect(controller.reminderVisible, isFalse);
    expect(window.visible, isFalse);
    expect(await controller.repo.countForDay(DateTime.now()), equals(1));
  });

  test('handleSnooze dismisses the overlay without logging', () async {
    await controller.showReminder();
    await controller.handleSnooze();
    expect(controller.reminderVisible, isFalse);
    expect(window.visible, isFalse);
    expect(await controller.repo.countForDay(DateTime.now()), equals(0));
  });
}
