import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/water_repository.dart';
import 'water_stats.dart';

class DashboardPage extends StatefulWidget {
  final WaterRepository repo;
  final int dailyGoal;
  const DashboardPage({super.key, required this.repo, required this.dailyGoal});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<DateTime> _stamps = [];

  @override
  void initState() {
    super.initState();
    widget.repo.allTimestamps().then((s) {
      if (mounted) setState(() => _stamps = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayCount =
        WaterStats.countsByDay(_stamps)[DateTime(today.year, today.month, today.day)] ?? 0;
    final streak = WaterStats.currentStreak(_stamps, widget.dailyGoal, today);
    final week = WaterStats.lastSevenDays(_stamps, today);

    return Scaffold(
      appBar: AppBar(title: const Text('Sippy — Progress')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today: $todayCount / ${widget.dailyGoal} glasses',
              key: const Key('today-progress'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Current streak: $streak days',
              key: const Key('streak-text')),
          const SizedBox(height: 24),
          const Text('Last 7 days'),
          const SizedBox(height: 12),
          Expanded(child: _WeekChart(week)),
        ]),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  final List<int> counts;
  const _WeekChart(this.counts);

  @override
  Widget build(BuildContext context) {
    return BarChart(BarChartData(
      barGroups: [
        for (var i = 0; i < counts.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: counts[i].toDouble(), width: 16),
          ]),
      ],
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
    ));
  }
}
