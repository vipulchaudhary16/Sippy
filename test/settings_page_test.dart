import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/settings/app_settings.dart';
import 'package:sippy/settings/settings_page.dart';

void main() {
  testWidgets('edits interval and saves', (tester) async {
    AppSettings? saved;
    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        initial: const AppSettings.defaults(),
        onSave: (s) async => saved = s,
      ),
    ));

    await tester.enterText(find.byKey(const Key('interval-field')), '30');
    await tester.tap(find.byKey(const Key('save-settings')));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.intervalMinutes, equals(30));
  });
}
