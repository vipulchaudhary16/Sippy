import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_controller.dart';
import 'audio/audio_manager.dart';
import 'data/database.dart';
import 'data/water_repository.dart';
import 'overlay/character_stage.dart';
import 'overlay/overlay_window.dart';
import 'settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureOverlayWindow();

  final dir = await getApplicationSupportDirectory();
  final db = AppDatabase(NativeDatabase(File(p.join(dir.path, 'sippy.sqlite'))));
  final prefs = await SharedPreferences.getInstance();

  final controller = AppController(
    repo: WaterRepository(db),
    audio: AudioManager(),
    settingsStore: SettingsStore(prefs),
  );
  await controller.init();

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
