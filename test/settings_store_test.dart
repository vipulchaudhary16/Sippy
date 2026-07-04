import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sippy/settings/app_settings.dart';
import 'package:sippy/settings/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load returns defaults when nothing saved', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs);

    final settings = await store.load();

    expect(settings, equals(const AppSettings.defaults()));
  });

  test('save then load round-trips all fields', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs);

    const custom = AppSettings(
      intervalMinutes: 45,
      snoozeMinutes: 15,
      dailyGoal: 10,
      volume: 0.3,
      muted: true,
      musicPaths: ['/music/a.mp3', '/music/b.mp3'],
    );
    await store.save(custom);

    expect(await store.load(), equals(custom));
  });
}
