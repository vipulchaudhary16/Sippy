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

  testWidgets('saves edited interval, snooze, and goal to correct fields', (tester) async {
    AppSettings? saved;
    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        initial: const AppSettings.defaults(),
        onSave: (s) async => saved = s,
      ),
    ));

    await tester.enterText(find.byKey(const Key('interval-field')), '25');
    await tester.enterText(find.byKey(const Key('snooze-field')), '7');
    await tester.enterText(find.byKey(const Key('goal-field')), '12');
    await tester.tap(find.byKey(const Key('save-settings')));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.intervalMinutes, equals(25));
    expect(saved!.snoozeMinutes, equals(7));
    expect(saved!.dailyGoal, equals(12));
  });

  testWidgets('clamps interval, snooze, and goal to a minimum of 1', (tester) async {
    AppSettings? saved;
    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        initial: const AppSettings.defaults(),
        onSave: (s) async => saved = s,
      ),
    ));

    await tester.enterText(find.byKey(const Key('interval-field')), '0');
    await tester.enterText(find.byKey(const Key('snooze-field')), '0');
    await tester.enterText(find.byKey(const Key('goal-field')), '0');
    await tester.tap(find.byKey(const Key('save-settings')));
    await tester.pump();

    expect(saved!.intervalMinutes, equals(1));
    expect(saved!.snoozeMinutes, equals(1));
    expect(saved!.dailyGoal, equals(1));
  });
}
