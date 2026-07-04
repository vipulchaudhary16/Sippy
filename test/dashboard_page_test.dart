import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/data/database.dart';
import 'package:sippy/data/water_repository.dart';
import 'package:sippy/dashboard/dashboard_page.dart';

void main() {
  testWidgets('shows today count and streak', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = WaterRepository(db);
    await repo.logGlass(DateTime.now());
    await repo.logGlass(DateTime.now());

    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(repo: repo, dailyGoal: 8, onClose: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-progress')), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);

    expect(find.byKey(const Key('streak-text')), findsOneWidget);
    expect(find.text('Current streak: 0 days'), findsOneWidget);

    await db.close();
  });

  testWidgets('shows a non-zero streak when goal met today', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = WaterRepository(db);
    final now = DateTime.now();
    // Log 2 glasses today with a goal of 2 -> today meets goal -> streak >= 1.
    await repo.logGlass(now);
    await repo.logGlass(now);

    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(repo: repo, dailyGoal: 2, onClose: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Current streak: 1 days'), findsOneWidget);

    await db.close();
  });
}
