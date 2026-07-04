import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'app_controller.dart';
import 'audio/audio_manager.dart';
import 'dashboard/dashboard_page.dart';
import 'data/database.dart';
import 'data/water_repository.dart';
import 'overlay/character_stage.dart';
import 'overlay/overlay_window.dart';
import 'settings/settings_page.dart';
import 'settings/settings_store.dart';
import 'tray/tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureOverlayWindow();
  await windowManager.hide();

  final dir = await getApplicationSupportDirectory();
  final db = AppDatabase(NativeDatabase(File(p.join(dir.path, 'sippy.sqlite'))));
  final prefs = await SharedPreferences.getInstance();

  final controller = AppController(
    repo: WaterRepository(db),
    audio: AudioManager(),
    settingsStore: SettingsStore(prefs),
  );
  await controller.init();

  await localNotifier.setup(appName: 'Sippy');
  final tray = TrayService(
    onDashboard: () => controller.openDashboard(),
    onSettings: () => controller.openSettings(),
    onRemindNow: () => controller.showReminder(),
    onQuit: () => windowManager.destroy(),
  );
  await tray.init();

  runApp(SippyApp(controller: controller));
}

class SippyApp extends StatelessWidget {
  final AppController controller;
  const SippyApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.showDashboard) {
              return DashboardPage(
                  repo: controller.repo,
                  dailyGoal: controller.settings.dailyGoal,
                  onClose: controller.closeDashboard);
            }
            if (controller.showSettings) {
              return SettingsPage(
                initial: controller.settings,
                onSave: (s) async {
                  await controller.applySettings(s);
                  await controller.closeSettings();
                },
              );
            }
            if (!controller.reminderVisible) return const SizedBox.shrink();
            return CharacterStage(
              message: 'Have you drank water?',
              onDrank: controller.handleDrank,
              onSnooze: controller.handleSnooze,
            );
          },
        ),
      ),
    );
  }
}
