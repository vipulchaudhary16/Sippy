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
      home: DashboardPage(repo: repo, dailyGoal: 8),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-progress')), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);

    await db.close();
  });
}
