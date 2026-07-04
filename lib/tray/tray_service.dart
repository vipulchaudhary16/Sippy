import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayService with TrayListener {
  final VoidCallback onDashboard;
  final VoidCallback onSettings;
  final VoidCallback onRemindNow;
  final VoidCallback onQuit;

  TrayService({
    required this.onDashboard,
    required this.onSettings,
    required this.onRemindNow,
    required this.onQuit,
  });

  Future<void> init() async {
    trayManager.addListener(this);
    await trayManager.setToolTip('Sippy');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'dashboard', label: 'Open Dashboard'),
      MenuItem(key: 'settings', label: 'Settings'),
      MenuItem(key: 'remind', label: 'Remind me now'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'dashboard':
        onDashboard();
      case 'settings':
        onSettings();
      case 'remind':
        onRemindNow();
      case 'quit':
        onQuit();
    }
  }
}
