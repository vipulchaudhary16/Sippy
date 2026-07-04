import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Makes the app's main window a transparent, borderless, always-on-top
/// overlay that covers the primary display so the character can be drawn
/// anywhere on screen with a see-through background.
Future<void> configureOverlayWindow() async {
  await windowManager.ensureInitialized();

  final display = await screenRetriever.getPrimaryDisplay();
  final size = display.size;

  const options = WindowOptions(
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: true,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setHasShadow(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setIgnoreMouseEvents(false);
    await windowManager.setSize(size);
    await windowManager.setPosition(const Offset(0, 0));
    await windowManager.show();
  });
}
